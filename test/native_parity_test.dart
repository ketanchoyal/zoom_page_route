import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoom_page_route/zoom_page_route.dart';

/// Regression tests against values measured from native SwiftUI
/// (`native_reference/`, iPhone simulator, 402×874 pt). Each test runs the real
/// route frame by frame and compares what Flutter draws with the native
/// numbers at the same page size, so a change that breaks parity fails here.
///
/// Native samples were taken with a magenta page over a pure green background
/// (alpha = red / 255; glass share solved per pixel), see the README.

const _screen = Size(402, 874);

class _Sample {
  _Sample(this.width, this.page, this.glass, this.origin, this.closing);

  /// Page width as a fraction of the screen.
  final double width;
  final double page;
  final double glass;
  final double origin;
  final bool closing;

  /// What shows of the glass: glass alpha under the page's alpha.
  double get glassShare => glass * (1 - page);
}

Future<void> _setScreen(WidgetTester tester) async {
  tester.view.physicalSize = _screen * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

/// Pumps [route] open then closed, recording every frame.
Future<List<_Sample>> _record(
  WidgetTester tester, {
  required Widget Function(VoidCallback open) home,
}) async {
  late BuildContext pageContext;
  final samples = <_Sample>[];
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => home(() {
          Navigator.of(context).push(
            ZoomPageRoute<void>(
              tag: 'src',
              screenCornerRadius: 62,
              builder: (context) {
                pageContext = context;
                return const ColoredBox(
                  color: Color(0xFFFF00FF),
                  child: Center(child: Text('PAGE')),
                );
              },
            ),
          );
        }),
      ),
    ),
  );

  void sample(bool closing) {
    final page = find.text('PAGE', skipOffstage: false);
    if (page.evaluate().isEmpty) return;
    final transform = tester
        .widgetList<Transform>(find.ancestor(of: page, matching: find.byType(Transform)))
        .map((t) => t.transform.storage[0])
        .reduce((a, b) => a < b ? a : b);
    final pageOpacity = tester
        .widgetList<Opacity>(find.ancestor(of: page, matching: find.byType(Opacity)))
        .first
        .opacity;
    final glass = tester
        .widgetList<DecoratedBox>(find.byType(DecoratedBox))
        .map((b) => b.decoration)
        .whereType<BoxDecoration>()
        .map((d) => d.color)
        .where((c) => c != null && c.r == 1 && c.g == 1 && c.b == 1)
        .fold<double>(0, (a, c) => a > c!.a ? a : c.a);
    final copies = find.descendant(of: find.byType(ExcludeSemantics), matching: find.text('SRC'));
    final origin = copies.evaluate().isEmpty
        ? 0.0
        : tester.widgetList<Opacity>(find.ancestor(of: copies.first, matching: find.byType(Opacity))).first.opacity;
    samples.add(_Sample(transform, pageOpacity, glass, origin, closing));
  }

  await tester.tap(find.text('SRC').first);
  await tester.pump();
  for (var i = 0; i < 60; i++) {
    await tester.pump(const Duration(milliseconds: 8));
    sample(false);
  }
  await tester.pumpAndSettle();
  Navigator.of(pageContext).pop();
  await tester.pump();
  for (var i = 0; i < 60; i++) {
    await tester.pump(const Duration(milliseconds: 8));
    sample(true);
  }
  await tester.pumpAndSettle();
  return samples;
}

/// The sample of [samples] (open or close) whose page width is closest to [w].
_Sample _at(List<_Sample> samples, double w, {required bool closing}) =>
    samples.where((s) => s.closing == closing).reduce((a, b) => (a.width - w).abs() <= (b.width - w).abs() ? a : b);

void main() {
  testWidgets('toolbar source: page fades in over the button glass as natively', (tester) async {
    await _setScreen(tester);
    final samples = await _record(
      tester,
      home: (open) => Scaffold(
        appBar: AppBar(
          actions: [
            ZoomSource(
              tag: 'src',
              toolbar: true,
              child: IconButton(onPressed: open, icon: const Text('SRC')),
            ),
          ],
        ),
      ),
    );
    // Native (page alpha, glass showing) while opening, from the green-screen
    // recording: the glass share follows ≈0.72 · (1 − page alpha).
    for (final (page, glassShare) in [(0.46, 0.38), (0.60, 0.31), (0.72, 0.23), (0.79, 0.18)]) {
      final s = samples
          .where((s) => !s.closing && s.glass > 0)
          .reduce((a, b) => (a.page - page).abs() <= (b.page - page).abs() ? a : b);
      expect(s.glassShare, closeTo(glassShare, 0.06), reason: 'glass at page alpha $page');
    }
    // Opening, the page is opaque by ~80% of the way (native: 0.79 at 0.8).
    expect(_at(samples, 0.9, closing: false).page, greaterThan(0.85));
    // The glyph is never drawn over the page (no blown-up icon).
    expect(samples.every((s) => s.origin == 0), isTrue);
    // Closing, page and glass are gone before the page reaches the button:
    // no miniature of the page is left on it.
    final smallest = samples.where((s) => s.closing).reduce((a, b) => a.width < b.width ? a : b);
    expect(smallest.page, lessThan(0.05));
    expect(smallest.glassShare, lessThan(0.05));
  });

  testWidgets('no source: grows from a centred rect and fades as natively', (tester) async {
    await _setScreen(tester);
    final samples = await _record(
      tester,
      home: (open) => Scaffold(
        body: Center(
          child: TextButton(onPressed: open, child: const Text('SRC')),
        ),
      ),
    );
    // Opening: native page alpha at page widths 0.664 … 0.903.
    for (final (w, alpha) in [(0.664, 0.65), (0.726, 0.73), (0.781, 0.77), (0.858, 0.85), (0.903, 0.91)]) {
      expect(_at(samples, w, closing: false).page, closeTo(alpha, 0.07), reason: 'open at width $w');
    }
    // Closing: 0.96 / 0.87 / 0.76 at 0.948 / 0.878 / 0.776, fading out fully.
    for (final (w, alpha) in [(0.948, 0.96), (0.878, 0.87), (0.776, 0.76)]) {
      expect(_at(samples, w, closing: true).page, closeTo(alpha, 0.07), reason: 'close at width $w');
    }
    final smallest = samples.where((s) => s.closing).reduce((a, b) => a.width < b.width ? a : b);
    expect(smallest.width, greaterThan(0.3)); // shrinks into ≈0.35 of the width, not a point
    expect(smallest.page, lessThan(0.25));
  });

  testWidgets('content source: source copy fades back early and the page fades out fully', (tester) async {
    await _setScreen(tester);
    final samples = await _record(
      tester,
      home: (open) => Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 361, 0, 0),
            child: ZoomSource(
              tag: 'src',
              borderRadius: BorderRadius.circular(12),
              child: GestureDetector(
                onTap: open,
                child: const SizedBox(
                  width: 150,
                  height: 100,
                  child: ColoredBox(color: Colors.cyan, child: Text('SRC')),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    // Opening, the copy is gone by ~45% of the way (native).
    expect(_at(samples, 0.75, closing: false).origin, 0);
    // Closing, the copy is back early: ≈0.6 at 64% of the way, opaque from 40%.
    const sw = 150 / 402;
    double widthAt(double p) => sw + (1 - sw) * p;
    expect(_at(samples, widthAt(0.64), closing: true).origin, closeTo(0.6, 0.12));
    expect(_at(samples, widthAt(0.35), closing: true).origin, closeTo(1, 0.05));
    // Page: 0.89 at 53% of the way (native), then fades out completely.
    expect(_at(samples, widthAt(0.53), closing: true).page, closeTo(0.89, 0.07));
    final smallest = samples.where((s) => s.closing).reduce((a, b) => a.width < b.width ? a : b);
    expect(smallest.page, lessThan(0.1));
  });
}
