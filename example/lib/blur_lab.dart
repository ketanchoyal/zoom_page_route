import 'package:flutter/material.dart';
import 'package:zoom_page_route/zoom_page_route.dart';

/// Flutter twin of the native `BlurLab` (`native_reference`, `-blurLab`):
/// the same measurable background and cyan source opening a magenta page, so
/// both recordings go through the same measurement. Run with
/// `--dart-define=BLUR_LAB=<style>` (a [ZoomBlurEffect] preset name, or
/// `none` for the dim) and optionally `--dart-define=BLUR_LAB_DARK=true`.
class BlurLabApp extends StatelessWidget {
  const BlurLabApp({super.key, required this.style, this.dark = false});

  final String style;
  final bool dark;

  static const effects = <String, ZoomBlurEffect>{
    'systemUltraThinMaterial': ZoomBlurEffect.systemUltraThinMaterial,
    'systemThinMaterial': ZoomBlurEffect.systemThinMaterial,
    'systemMaterial': ZoomBlurEffect.systemMaterial,
    'systemThickMaterial': ZoomBlurEffect.systemThickMaterial,
    'systemChromeMaterial': ZoomBlurEffect.systemChromeMaterial,
    'regular': ZoomBlurEffect.regular,
    'prominent': ZoomBlurEffect.prominent,
    'light': ZoomBlurEffect.light,
    'extraLight': ZoomBlurEffect.extraLight,
    'dark': ZoomBlurEffect.dark,
  };

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(brightness: dark ? Brightness.dark : Brightness.light, platform: TargetPlatform.iOS),
      home: _BlurLabHome(spec: ZoomTransitionSpec(recedeRouteBelow: true, dimmingVisualEffect: effects[style])),
    );
  }
}

class _BlurLabHome extends StatelessWidget {
  const _BlurLabHome({required this.spec});

  final ZoomTransitionSpec spec;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: Stack(
        children: [
          const Positioned.fill(child: CustomPaint(painter: _BlurLabPattern())),
          Positioned(
            left: 126,
            top: 400,
            width: 150,
            height: 100,
            child: ZoomSource(
              tag: 'lab',
              borderRadius: BorderRadius.circular(12),
              child: GestureDetector(
                onTap: () => Navigator.of(context).push(
                  ZoomPageRoute<void>(
                    tag: 'lab',
                    spec: spec,
                    builder: (_) => const ColoredBox(color: Color(0xFFFF00FF), child: SizedBox.expand()),
                  ),
                ),
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    color: Color(0xFF00FFFF),
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// As the native lab: 100–300 pt black left half / white right half, then
/// full-width red, green and blue bands.
class _BlurLabPattern extends CustomPainter {
  const _BlurLabPattern();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 100, size.width / 2, 200), Paint()..color = const Color(0xFF000000));
    const bands = [Color(0xFFFF0000), Color(0xFF00FF00), Color(0xFF0000FF)];
    final bh = (size.height - 300) / bands.length;
    for (var i = 0; i < bands.length; i++) {
      canvas.drawRect(Rect.fromLTWH(0, 300 + i * bh, size.width, bh), Paint()..color = bands[i]);
    }
  }

  @override
  bool shouldRepaint(_BlurLabPattern oldDelegate) => false;
}
