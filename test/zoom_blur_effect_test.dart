import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoom_page_route/zoom_page_route.dart';

/// dimmingVisualEffect replaces the dim over the route below with a blur
/// material (UIKit's ZoomOptions.dimmingVisualEffect): off at rest, on while
/// the page moves, resolved for the theme's brightness.
void main() {
  Future<void> open(WidgetTester tester, ZoomTransitionSpec spec) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ZoomSource(
                tag: 'p',
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).push(
                    ZoomPageRoute<void>(tag: 'p', spec: spec, builder: (_) => const Scaffold(body: Text('PAGE'))),
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
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
  }

  // The dim: a black box, no other ColoredBox in these trees is black.
  double dimAlpha(WidgetTester tester) => tester
      .widgetList<ColoredBox>(find.byType(ColoredBox))
      .where((b) => b.color.r == 0 && b.color.g == 0 && b.color.b == 0)
      .fold<double>(0, (a, b) => a > b.color.a ? a : b.color.a);

  testWidgets('default: dims, no blur', (tester) async {
    await open(tester, const ZoomTransitionSpec());
    expect(dimAlpha(tester), greaterThan(0.05));
    expect(find.byType(BackdropFilter), findsNothing);
  });

  testWidgets('dimmingVisualEffect: blur material instead of the dim, off at rest', (tester) async {
    await open(tester, const ZoomTransitionSpec(dimmingVisualEffect: ZoomBlurEffect.systemMaterial));
    expect(dimAlpha(tester), 0);
    final mid = tester.widget<BackdropFilter>(find.byType(BackdropFilter));
    expect(mid.enabled, isTrue);
    expect(mid.filter.toString(), contains('blur('));

    await tester.pumpAndSettle();
    expect(tester.widget<BackdropFilter>(find.byType(BackdropFilter)).enabled, isFalse);
  });

  test('presets: light/dark variants, and strength scales the blur and colour from nothing', () {
    const effect = ZoomBlurEffect.systemMaterial;
    expect(effect.resolve(Brightness.light), same(effect));
    expect(effect.resolve(Brightness.dark), same(effect.darkVariant));
    expect(ZoomBlurEffect.dark.resolve(Brightness.light), same(ZoomBlurEffect.dark));
    // regular / prominent are UIKit's adaptive aliases.
    expect(ZoomBlurEffect.regular.colorMatrix, ZoomBlurEffect.light.colorMatrix);
    expect(ZoomBlurEffect.regular.resolve(Brightness.dark).colorMatrix, ZoomBlurEffect.dark.colorMatrix);
    expect(ZoomBlurEffect.prominent.colorMatrix, ZoomBlurEffect.extraLight.colorMatrix);

    expect(effect.filterAt(1).toString(), contains('${effect.sigma}'));
    expect(effect.filterAt(0.5).toString(), contains('${effect.sigma / 2}'));
  });
}
