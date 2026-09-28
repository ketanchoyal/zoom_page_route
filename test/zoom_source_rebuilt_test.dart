import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoom_page_route/zoom_page_route.dart';

/// The source's widget is replaced (its list item rebuilt under a new key)
/// while the page is closing: the old element goes inactive mid-frame. The
/// route must not touch it (no "Cannot get renderObject of inactive element")
/// and should close into the new source instead.
void main() {
  testWidgets('a source rebuilt as a new widget while the page closes', (tester) async {
    var generation = 0;
    late StateSetter rebuildHome;
    late BuildContext pageContext;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            rebuildHome = setState;
            return Scaffold(
              body: ListView(
                children: [
                  ZoomSource(
                    key: ValueKey(generation), // a new key = a new ZoomSource element
                    tag: 'card',
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).push(
                        ZoomPageRoute<void>(
                          tag: 'card',
                          builder: (context) {
                            pageContext = context;
                            return const Scaffold(body: Text('page'));
                          },
                        ),
                      ),
                      child: SizedBox(height: 100, child: Text('card $generation')),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('card 0'));
    await tester.pumpAndSettle();

    Navigator.of(pageContext).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    rebuildHome(() => generation++); // replace the source mid-close
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('page'), findsNothing);
    // The new source is visible again once the page has closed into it.
    final opacity = tester.widget<Opacity>(
      find.ancestor(of: find.text('card 1'), matching: find.byType(Opacity)).first,
    );
    expect(opacity.opacity, 1);
  });
}
