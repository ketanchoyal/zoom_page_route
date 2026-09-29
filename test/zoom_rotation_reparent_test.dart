import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoom_page_route/zoom_page_route.dart';

/// The rotation crash needs what a real app does and a bare MaterialApp
/// doesn't: the zoom page's (nested, GlobalKey'd) Navigator moves under a new
/// parent when the orientation changes (a landscape layout wrapping it in a
/// Transform). That new RenderTransform has no size yet while the zoom page
/// rebuilds from its LayoutBuilder, so localToGlobal through it threw
/// "RenderBox was not laid out: RenderTransform … NEEDS-LAYOUT".
void main() {
  final navigatorKey = GlobalKey<NavigatorState>();

  Widget app() => MaterialApp(
    home: OrientationBuilder(
      builder: (context, orientation) {
        final navigator = Navigator(
          key: navigatorKey,
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            builder: (context) => Scaffold(
              body: Center(
                child: ZoomSource(
                  tag: 'card',
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).push(
                      ZoomPageRoute<void>(
                        tag: 'card',
                        builder: (context) => Scaffold(
                          body: Center(
                            child: ElevatedButton(
                              onPressed: () => showModalBottomSheet<void>(
                                context: context,
                                builder: (_) => const SizedBox(height: 200, child: Text('sheet')),
                              ),
                              child: const Text('open sheet'),
                            ),
                          ),
                        ),
                      ),
                    ),
                    child: const Text('open page'),
                  ),
                ),
              ),
            ),
          ),
        );
        // Landscape wraps the navigator in a scaling Transform (its paint transform
        // needs its size, being centre-aligned): a new render object
        // above it, not laid out yet on the frame of the rotation.
        return orientation == Orientation.landscape ? Transform.scale(scale: 0.98, child: navigator) : navigator;
      },
    ),
  );

  Future<void> rotate(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    await tester.pump();
    await tester.pumpAndSettle();
  }

  testWidgets('rotating with the page settled and a bottom sheet open', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app());
    await tester.tap(find.text('open page'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('open sheet'));
    await tester.pumpAndSettle();

    await rotate(tester, const Size(1200, 800));
    expect(tester.takeException(), isNull);
    await rotate(tester, const Size(800, 1200));
    expect(tester.takeException(), isNull);
    expect(find.text('sheet'), findsOneWidget);
  });

  testWidgets('rotating while the page is still opening', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app());
    await tester.tap(find.text('open page'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60)); // mid-open: geometry is computed

    await rotate(tester, const Size(1200, 800));
    expect(tester.takeException(), isNull);
    expect(find.text('open sheet'), findsOneWidget);
  });
}
