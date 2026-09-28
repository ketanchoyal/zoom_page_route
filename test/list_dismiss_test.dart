import 'dart:ui' show GestureSettings;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoom_page_route/zoom_page_route.dart';

/// A drag down with the page's list at the top dismisses, fast or slow, over
/// several open/close cycles (the list must not win the gesture arena).
void main() {
  for (final (name, step) in [('fast', 12.0), ('slow', 1.2)]) {
    testWidgets('$name drag down on a list at the top dismisses', (tester) async {
      tester.view.physicalSize = const Size(402 * 3, 874 * 3);
      tester.view.devicePixelRatio = 3;
      // Like a real iOS device: the platform reports its own touch slop, which
      // the list's drag recognizer uses (8 pt here, below the 18 pt default).
      tester.view.gestureSettings = const GestureSettings(physicalTouchSlop: 24);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  ZoomPageRoute<void>(
                    tag: 'x',
                    builder: (_) => Material(
                      child: ListView(
                        children: [for (var i = 0; i < 40; i++) SizedBox(height: 56, child: Text('Row $i'))],
                      ),
                    ),
                  ),
                ),
                child: const Text('go'),
              ),
            ),
          ),
        ),
      );
      for (final (cycle, y) in [(1, 105.0), (2, 437.0)]) {
        await tester.tap(find.text('go'));
        await tester.pumpAndSettle();
        final g = await tester.startGesture(Offset(201, y));
        for (var i = 0; i < 300 / step; i++) {
          await g.moveBy(Offset(0, step));
          await tester.pump(const Duration(milliseconds: 16));
        }
        await g.up();
        await tester.pumpAndSettle();
        expect(find.text('Row 0'), findsNothing, reason: 'cycle $cycle: page should have been dismissed');
      }
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  }
}
