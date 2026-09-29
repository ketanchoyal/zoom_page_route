import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoom_page_route/zoom_page_route.dart';

void main() {
  testWidgets('screen size change / rotation while page is open with bottom sheet', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: ZoomSource(
              tag: 'card',
              child: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      ZoomPageRoute<void>(
                        tag: 'card',
                        builder: (context) => Scaffold(
                          body: Center(
                            child: ElevatedButton(
                              onPressed: () {
                                showModalBottomSheet<void>(
                                  context: context,
                                  builder: (_) => const SizedBox(height: 200, child: Text('sheet')),
                                );
                              },
                              child: const Text('open sheet'),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                  child: const Text('open page'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open page'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('open sheet'));
    await tester.pumpAndSettle();

    // Rotate screen from portrait to landscape (e.g. iPad rotation)
    tester.view.physicalSize = const Size(1200, 800);
    await tester.pump();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('sheet'), findsOneWidget);
  });
}
