import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoom_page_route/zoom_page_route.dart';

/// What happens to an open zoom page when another route is pushed on top.
void main() {
  // The zoom page's own horizontal offset (its outgoing parallax, if any).
  double pageShift(WidgetTester tester) {
    final slides = tester.widgetList<SlideTransition>(
      find.ancestor(of: find.text('A', skipOffstage: false), matching: find.byType(SlideTransition)),
    );
    return slides.map((s) => s.position.value.dx).fold(0.0, (a, b) => a + b);
  }

  Future<NavigatorState> openA(WidgetTester tester) async {
    late NavigatorState nav;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            nav = Navigator.of(context);
            return const Scaffold(body: Text('home'));
          },
        ),
      ),
    );
    nav.push(
      ZoomPageRoute<void>(
        tag: 'a',
        builder: (_) => const Scaffold(body: Text('A')),
      ),
    );
    await tester.pumpAndSettle();
    return nav;
  }

  Future<double> shiftWhilePushing(WidgetTester tester, NavigatorState nav, Route<void> next) async {
    nav.push(next);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    return pageShift(tester);
  }

  testWidgets('another zoom page on top: the zoom page below stays put', (tester) async {
    final nav = await openA(tester);
    final shift = await shiftWhilePushing(
      tester,
      nav,
      ZoomPageRoute<void>(
        tag: 'b',
        builder: (_) => const Scaffold(body: Text('B')),
      ),
    );
    expect(shift, 0);
  });

  testWidgets('a bottom sheet on top: the zoom page below stays put', (tester) async {
    final nav = await openA(tester);
    final shift = await shiftWhilePushing(
      tester,
      nav,
      ModalBottomSheetRoute<void>(builder: (_) => const SizedBox(height: 200), isScrollControlled: false),
    );
    expect(shift, 0);
  });

  testWidgets('a regular iOS page push on top: the usual parallax, as natively', (tester) async {
    final nav = await openA(tester);
    final shift = await shiftWhilePushing(
      tester,
      nav,
      MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('B'))),
    );
    expect(shift, lessThan(0));
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  // What the route below reports about being covered: its secondaryAnimation,
  // which e.g. liquid_glass_widgets' GlassNavigationShell reads to tell a
  // covering page from one that has not arrived yet.
  testWidgets('the route below is covered in step with the zoom page, without moving', (tester) async {
    late BuildContext homeContext;
    late NavigatorState nav;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            homeContext = context;
            nav = Navigator.of(context);
            return const Scaffold(body: Text('home'));
          },
        ),
      ),
    );
    Animation<double> covered() => ModalRoute.of(homeContext)!.secondaryAnimation!;
    double homeShift() => tester
        .widgetList<SlideTransition>(
          find.ancestor(of: find.text('home', skipOffstage: false), matching: find.byType(SlideTransition)),
        )
        .map((s) => s.position.value.dx)
        .fold(0.0, (a, b) => a + b);

    nav.push(ZoomPageRoute<void>(tag: 'a', builder: (_) => const Scaffold(body: Text('A'))));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(covered().value, inExclusiveRange(0, 1), reason: 'covered as the page zooms in');
    expect(homeShift(), 0, reason: 'no iOS parallax under a zoom page');

    await tester.pumpAndSettle();
    expect(covered().value, 1);
    expect(covered().status, AnimationStatus.completed);
    expect(homeShift(), 0);

    nav.pop();
    await tester.pumpAndSettle();
    expect(covered().value, 0);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('another zoom page on top: the zoom page below reports being covered', (tester) async {
    late BuildContext aContext;
    late NavigatorState nav;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            nav = Navigator.of(context);
            return const Scaffold(body: Text('home'));
          },
        ),
      ),
    );
    nav.push(
      ZoomPageRoute<void>(
        tag: 'a',
        builder: (context) {
          aContext = context;
          return const Scaffold(body: Text('A'));
        },
      ),
    );
    await tester.pumpAndSettle();
    nav.push(ZoomPageRoute<void>(tag: 'b', builder: (_) => const Scaffold(body: Text('B'))));
    await tester.pumpAndSettle();
    expect(ModalRoute.of(aContext)!.secondaryAnimation!.value, 1);
    expect(pageShift(tester), 0);
  });

  testWidgets('another zoom page with recedeRouteBelow: the page below shrinks but does not slide', (tester) async {
    final nav = await openA(tester);
    final shift = await shiftWhilePushing(
      tester,
      nav,
      ZoomPageRoute<void>(
        tag: 'b',
        spec: const ZoomTransitionSpec(recedeRouteBelow: true),
        builder: (_) => const Scaffold(body: Text('B')),
      ),
    );
    expect(shift, 0);
    final scales = tester
        .widgetList<Transform>(find.ancestor(of: find.text('A', skipOffstage: false), matching: find.byType(Transform)))
        .map((t) => t.transform.storage[0]);
    expect(scales.any((s) => s < 1), isTrue, reason: 'the page below recedes');
  });
}
