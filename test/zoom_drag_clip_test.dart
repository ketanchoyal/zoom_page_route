import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoom_page_route/zoom_page_route.dart';

/// While the page is dragged its corners are rounded from the first frame,
/// and the clip is saved to a layer: with the clip alone, Impeller drops the
/// rounded corners for whatever paints after a backdrop filter in the page (a
/// glass button, then the app bar), which showed as square corners.
void main() {
  testWidgets('drag: rounded page clip saved to a layer; settled: plain clip', (tester) async {
    tester.view.physicalSize = const Size(402 * 3, 874 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ZoomSource(
                tag: 'p',
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).push(
                    ZoomPageRoute<void>(
                      tag: 'p',
                      screenCornerRadius: 55,
                      builder: (_) => Scaffold(
                        appBar: AppBar(title: const Text('PAGE')),
                        body: ListView(children: [for (var i = 0; i < 30; i++) SizedBox(height: 60, child: Text('row $i'))]),
                      ),
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    ClipRRect pageClip() => tester
        .widgetList<ClipRRect>(find.ancestor(of: find.text('PAGE'), matching: find.byType(ClipRRect)))
        .firstWhere((c) => c.clipper != null);
    double radius() => pageClip().clipper!.getClip(const Size(402, 874)).tlRadiusX;

    expect(radius(), 0);
    expect(pageClip().clipBehavior, Clip.antiAlias);

    final gesture = await tester.startGesture(const Offset(201, 300));
    // Past the touch slop, where the dismiss drag takes over.
    await gesture.moveBy(const Offset(0, 20));
    await tester.pump(const Duration(milliseconds: 16));
    for (var i = 0; i < 6; i++) {
      await gesture.moveBy(const Offset(0, 15));
      await tester.pump(const Duration(milliseconds: 16));
      // screenRadius · scale in screen points is screenRadius in page points.
      expect(radius(), closeTo(55, 0.01), reason: 'drag step $i');
      expect(pageClip().clipBehavior, Clip.antiAliasWithSaveLayer, reason: 'drag step $i');
    }
    await gesture.moveBy(const Offset(0, -110));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(radius(), 0);
    expect(pageClip().clipBehavior, Clip.antiAlias);
  });
}
