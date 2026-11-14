import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoom_page_route/zoom_page_route.dart';

/// The drag-down dismiss only starts on content scrolled to its top, as
/// measured natively (SwiftUI `.zoom`, native_reference `-scrollLab`):
/// - the list is not always the page's outermost scrollable (a PageView or
///   TabBarView page, a NestedScrollView body): scrolled there, it scrolls
///   back up; at its top, the drag dismisses;
/// - a scrolled list only blocks a drag started on it: from a fixed header
///   above it, the page dismisses.
void main() {
  Future<void> open(WidgetTester tester, Widget page) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(ZoomPageRoute<void>(tag: 'x', builder: (_) => page)),
              child: const Text('go'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
  }

  Future<void> dragDown(WidgetTester tester, Offset from) async {
    final g = await tester.startGesture(from);
    for (var i = 0; i < 50; i++) {
      await g.moveBy(const Offset(0, 4));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await g.up();
    await tester.pumpAndSettle();
  }

  final rows = [for (var i = 0; i < 60; i++) SizedBox(height: 56, child: Text('Row $i'))];

  testWidgets('a scrolled list inside a PageView scrolls back up instead of dismissing', (tester) async {
    final list = ScrollController();
    await open(
      tester,
      Material(
        child: PageView(
          children: [ListView(controller: list, children: rows)],
        ),
      ),
    );
    list.jumpTo(1000);
    await tester.pump();

    await dragDown(tester, const Offset(200, 300));
    expect(find.byType(PageView), findsOneWidget, reason: 'the page stays open');
    expect(list.offset, lessThan(1000), reason: 'the list scrolled back up');

    list.jumpTo(0);
    await tester.pump();
    await dragDown(tester, const Offset(200, 300));
    expect(find.byType(PageView), findsNothing, reason: 'at its top, the drag dismisses');
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('a scrolled list blocks a dismiss only when the drag starts on it', (tester) async {
    final list = ScrollController();
    await open(
      tester,
      Material(
        child: Column(
          children: [
            const SizedBox(height: 200, child: Text('header')),
            Expanded(child: ListView(controller: list, children: rows)),
          ],
        ),
      ),
    );
    list.jumpTo(1000);
    await tester.pump();

    await dragDown(tester, const Offset(200, 350));
    expect(find.text('header'), findsOneWidget, reason: 'on the list, the drag scrolls it');
    expect(list.offset, lessThan(1000));

    await dragDown(tester, const Offset(200, 60));
    expect(find.text('header'), findsNothing, reason: 'on the header, the drag dismisses');
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
}
