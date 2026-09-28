import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoom_page_route/zoom_page_route.dart';

Future<void> _backGesture(WidgetTester tester, String method, [Map<String, Object?>? args]) async {
  final message = const StandardMethodCodec().encodeMethodCall(MethodCall(method, args));
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage('flutter/backgesture', message, (_) {});
}

Map<String, Object?> _event(double progress, {int swipeEdge = 0, double y = 400}) => {
  'touchOffset': <double>[10, y],
  'progress': progress,
  'swipeEdge': swipeEdge, // 0 = left, 1 = right
};

void main() {
  const screen = Size(402, 874);
  final geometry = ZoomGeometry(
    spec: ZoomTransitionSpec.standard,
    screen: screen,
    source: const Rect.fromLTWH(16, 361, 150, 100),
    sourceRadius: 12,
    screenRadius: 61.5,
  );

  test('the system back gesture moves the page like the iOS edge swipe (mirrored from the right)', () {
    final left = geometry.systemBack(const Offset(10, 400), const Offset(110, 400), fromLeft: true);
    final edge = geometry.edgeDrag(const Offset(100, 0), anchor: const Offset(10, 400));
    expect(left.rect, edge.rect);
    final right = geometry.systemBack(const Offset(392, 400), const Offset(292, 400), fromLeft: false);
    expect(right.rect.width, closeTo(edge.rect.width, 1e-9));
    expect(right.rect.right, closeTo(screen.width - edge.rect.left, 1e-9));
  });

  Future<void> openPage(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                ZoomPageRoute<void>(tag: 'x', builder: (_) => const Scaffold(body: Text('page'))),
              ),
              child: const Text('go'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.text('page'), findsOneWidget);
  }

  testWidgets('a committed back gesture shrinks the page and zooms it closed', (tester) async {
    await openPage(tester);
    await _backGesture(tester, 'startBackGesture', _event(0));
    await _backGesture(tester, 'updateBackGestureProgress', {..._event(0.6), 'touchOffset': <double>[250, 400]});
    await tester.pump();
    final scaled = tester.widgetList<Transform>(find.ancestor(of: find.text('page'), matching: find.byType(Transform)));
    final scale = scaled.map((t) => t.transform.storage[0]).reduce((a, b) => a < b ? a : b);
    // Touch moved 0 → 10 px in the event (physical); the page follows it like
    // the iOS edge swipe, so it is scaled below 1.
    expect(scale, lessThan(1));
    await _backGesture(tester, 'commitBackGesture');
    await tester.pumpAndSettle();
    expect(find.text('page'), findsNothing);
  });

  testWidgets('a cancelled back gesture springs the page back and keeps it', (tester) async {
    await openPage(tester);
    await _backGesture(tester, 'startBackGesture', _event(0));
    await _backGesture(tester, 'updateBackGestureProgress', _event(0.5));
    await tester.pump();
    await _backGesture(tester, 'cancelBackGesture');
    await tester.pumpAndSettle();
    expect(find.text('page'), findsOneWidget);
    final scaled = tester.widgetList<Transform>(find.ancestor(of: find.text('page'), matching: find.byType(Transform)));
    expect(scaled.map((t) => t.transform.storage[0]).reduce((a, b) => a < b ? a : b), closeTo(1, 1e-6));
  });
}
