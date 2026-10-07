import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoom_page_route/zoom_page_route.dart';

/// An app jumps back to the start (popUntil the first route, popping the zoom
/// page and the screen holding its source) from under a route covering the
/// whole tab, and pushes a fresh copy of that screen. The closing page hides
/// and shows the new screen's source (same tag) within one frame; it must not
/// stay hidden.
void main() {
  testWidgets('a fresh source after popping to the root stays visible', (tester) async {
    final browse = GlobalKey<NavigatorState>();
    late NavigatorState root;
    Route<void> menu() => MaterialPageRoute<void>(
      settings: const RouteSettings(name: 'menu'),
      builder: (context) => Scaffold(
        body: ZoomSource(
          tag: 'category',
          child: GestureDetector(
            onTap: () => Navigator.of(context).push(
              ZoomPageRoute<void>(tag: 'category', maintainState: false, builder: (_) => const Scaffold(body: Text('items'))),
            ),
            child: const SizedBox(height: 100, child: Text('category')),
          ),
        ),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            root = Navigator.of(context);
            // A tab's own navigator, as the app's browse tab.
            return Navigator(
              key: browse,
              onGenerateRoute: (_) => MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('home'))),
            );
          },
        ),
      ),
    );
    browse.currentState!.push(menu());
    await tester.pumpAndSettle();
    await tester.tap(find.text('category'));
    await tester.pumpAndSettle();
    // The cart, over the whole tab.
    root.push(MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('cart'))));
    await tester.pumpAndSettle();

    // "Add more items": back to the tab's start, then a fresh menu.
    root.popUntil((route) => route.isFirst);
    browse.currentState!.popUntil((route) => route.isFirst);
    browse.currentState!.push(menu());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('items'), findsNothing);
    final opacity = tester.widget<Opacity>(
      find.ancestor(of: find.text('category'), matching: find.byType(Opacity)).first,
    );
    expect(opacity.opacity, 1);
  });
}
