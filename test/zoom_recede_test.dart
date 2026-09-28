import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoom_page_route/zoom_page_route.dart';

class _Home extends StatefulWidget {
  const _Home({this.recede = true});
  final bool recede;
  static int inits = 0;
  @override
  State<_Home> createState() => _HomeState();
}

class _HomeState extends State<_Home> {
  @override
  void initState() {
    super.initState();
    _Home.inits++;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('home')),
    body: Builder(
      builder: (context) => TextButton(
        onPressed: () => Navigator.of(context).push(
          ZoomPageRoute<void>(
            tag: 'x',
            spec: ZoomTransitionSpec(recedeRouteBelow: widget.recede),
            screenCornerRadius: 40,
            builder: (_) => const Scaffold(body: Text('page')),
          ),
        ),
        child: const Text('go'),
      ),
    ),
  );
}

void main() {
  ClipRRect recedeClip(WidgetTester tester) => tester.widget<ClipRRect>(
    find.ancestor(of: find.byType(_Home, skipOffstage: false), matching: find.byType(ClipRRect)).first,
  );

  testWidgets('the route below is rounded to the display radius only while it is covered, and never remounted', (
    tester,
  ) async {
    _Home.inits = 0;
    await tester.pumpWidget(const MaterialApp(home: _Home()));
    expect(_Home.inits, 1);

    await tester.tap(find.text('go'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    expect(recedeClip(tester).clipBehavior, Clip.antiAlias);
    expect(recedeClip(tester).borderRadius, BorderRadius.circular(40));
    await tester.pumpAndSettle();

    Navigator.of(tester.element(find.text('page'))).pop();
    await tester.pumpAndSettle();
    expect(_Home.inits, 1, reason: 'the home page must not be rebuilt from scratch');
    // With nothing on top the framework drops the delegated transition, so
    // the clip is gone altogether.
    expect(find.ancestor(of: find.byType(_Home), matching: find.byType(ClipRRect)), findsNothing);
  });

  testWidgets('by default the route below stays still (no recede, no clip)', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: _Home(recede: false)));
    await tester.tap(find.text('go'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    final ancestors = find.ancestor(of: find.byType(_Home, skipOffstage: false), matching: find.byType(ClipRRect));
    expect(ancestors, findsNothing);
    expect(ZoomTransitionSpec.standard.recedeRouteBelow, isFalse);
    await tester.pumpAndSettle();
  });
}
