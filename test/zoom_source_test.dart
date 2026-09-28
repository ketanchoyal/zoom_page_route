import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoom_page_route/zoom_page_route.dart';

/// Which of several sources sharing a tag the route zooms from: the chosen
/// one is hidden (opacity 0) while the page is open.
void main() {
  const a = Key('a'), b = Key('b');

  // The route below is offstage while the page is open, so walk the element
  // tree instead of using (onstage-only) finders.
  double opacityOf(WidgetTester tester, Key key) {
    Opacity? found;
    void visit(Element element) {
      if (found != null) return;
      if (element.widget is Opacity) {
        found = element.widget as Opacity;
        return;
      }
      element.visitChildElements(visit);
    }

    tester.element(find.byKey(key, skipOffstage: false)).visitChildElements(visit);
    return found!.opacity;
  }

  void push(BuildContext context, {BuildContext? sourceContext}) {
    Navigator.of(context).push(
      ZoomPageRoute<void>(
        tag: 'dup',
        sourceContext: sourceContext,
        builder: (_) => const Scaffold(body: Text('page')),
      ),
    );
  }

  Widget card(Key key, {Offset offset = Offset.zero, void Function(BuildContext)? onBuild}) {
    return Transform.translate(
      offset: offset,
      child: ZoomSource(
        key: key,
        tag: 'dup',
        child: Builder(
          builder: (context) {
            onBuild?.call(context);
            return GestureDetector(
              onTap: () => push(context),
              child: Container(width: 100, height: 60, color: const Color(0xFF00FFFF)),
            );
          },
        ),
      ),
    );
  }

  Future<void> pumpHome(WidgetTester tester, Widget body) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: SafeArea(child: body)),
    ),
  );

  testWidgets('zooms from the copy that was tapped, not the newest one', (tester) async {
    await pumpHome(tester, Column(children: [card(a), card(b)]));
    await tester.tap(find.byKey(a));
    await tester.pumpAndSettle();
    expect(opacityOf(tester, a), 0);
    expect(opacityOf(tester, b), 1);

    Navigator.of(tester.element(find.text('page'))).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(b));
    await tester.pumpAndSettle();
    expect(opacityOf(tester, a), 1);
    expect(opacityOf(tester, b), 0);
  });

  testWidgets('skips a copy in a hidden IndexedStack child', (tester) async {
    late BuildContext buttonContext;
    await pumpHome(
      tester,
      Column(
        children: [
          SizedBox(height: 80, child: IndexedStack(index: 0, children: [card(a), card(b)])),
          Builder(
            builder: (context) {
              buttonContext = context;
              return TextButton(onPressed: () => push(buttonContext), child: const Text('go'));
            },
          ),
        ],
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(opacityOf(tester, a), 0, reason: 'the visible tab');
    expect(opacityOf(tester, b), 1, reason: 'the hidden tab (built later) must not be used');
  });

  testWidgets('prefers an on-screen copy over a newer off-screen one', (tester) async {
    await pumpHome(
      tester,
      Stack(
        children: [
          card(a),
          card(b, offset: const Offset(-5000, 0)),
          Positioned(
            bottom: 0,
            child: Builder(
              builder: (context) => TextButton(onPressed: () => push(context), child: const Text('go')),
            ),
          ),
        ],
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(opacityOf(tester, a), 0);
    expect(opacityOf(tester, b), 1);
  });

  testWidgets('sourceContext picks that exact copy', (tester) async {
    late BuildContext contextA;
    await pumpHome(
      tester,
      Column(
        children: [
          card(a, onBuild: (context) => contextA = context),
          card(b),
          Builder(
            builder: (context) => TextButton(
              onPressed: () => push(context, sourceContext: contextA),
              child: const Text('go'),
            ),
          ),
        ],
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(opacityOf(tester, a), 0);
    expect(opacityOf(tester, b), 1);
  });

  testWidgets('an older tap does not stick, and with two copies on screen and no tap the page zooms without a source', (
    tester,
  ) async {
    await pumpHome(
      tester,
      Column(
        children: [
          card(a),
          card(b),
          Builder(
            builder: (context) => TextButton(onPressed: () => push(context), child: const Text('go')),
          ),
        ],
      ),
    );
    await tester.tap(find.byKey(a));
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.text('page'))).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    // Ambiguous: neither copy is used (both stay visible) and the page opens.
    expect(opacityOf(tester, a), 1);
    expect(opacityOf(tester, b), 1);
    expect(find.text('page'), findsOneWidget);
  });

  testWidgets('a toolbar source is not blown up into the page: the page fades in instead', (tester) async {
    await pumpHome(
      tester,
      Builder(
        builder: (context) => ZoomSource(
          key: a,
          tag: 'bar',
          toolbar: true,
          child: GestureDetector(
            onTap: () => Navigator.of(context).push(
              ZoomPageRoute<void>(
                tag: 'bar',
                builder: (_) => const Scaffold(body: Text('page')),
              ),
            ),
            child: const SizedBox(width: 24, height: 24, child: ColoredBox(color: Color(0xFFFF0000))),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(a));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 30));
    // The page's own Opacity (nearest Opacity above the page content) is part-way.
    final pageOpacity = tester
        .widgetList<Opacity>(find.ancestor(of: find.text('page'), matching: find.byType(Opacity)))
        .first
        .opacity;
    expect(pageOpacity, inExclusiveRange(0, 1));
    // No copy of the source is drawn over the page.
    final copies = find.descendant(of: find.byType(IgnorePointer), matching: find.byType(ExcludeSemantics));
    for (final copy in tester.widgetList(find.ancestor(of: copies, matching: find.byType(Opacity)))) {
      expect((copy as Opacity).opacity, 0);
    }
    await tester.pumpAndSettle();
    expect(
      tester.widgetList<Opacity>(find.ancestor(of: find.text('page'), matching: find.byType(Opacity))).first.opacity,
      1,
    );
  });

  testWidgets('two painted copies, both off screen, and no tap: no source', (tester) async {
    await pumpHome(
      tester,
      Stack(
        children: [
          card(a, offset: const Offset(-5000, 0)),
          card(b, offset: const Offset(0, 5000)),
          Positioned(
            bottom: 0,
            child: Builder(
              builder: (context) => TextButton(onPressed: () => push(context), child: const Text('go')),
            ),
          ),
        ],
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(opacityOf(tester, a), 1);
    expect(opacityOf(tester, b), 1);
    expect(find.text('page'), findsOneWidget);
  });
}
