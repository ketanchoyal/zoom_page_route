// dart format off
import 'dart:ui' show Brightness, ColorFilter, ImageFilter, TileMode;

/// A blur material over the route below a zoom page, in place of the dim:
/// Flutter's counterpart of UIKit's `UIBlurEffect`, passed natively as
/// `UIViewController.Transition.ZoomOptions.dimmingVisualEffect` (SwiftUI's
/// `.zoom` has no such option). Use one as
/// `ZoomTransitionSpec.dimmingVisualEffect`.
///
/// Each preset is measured from the native effect (iPhone simulator, iOS 27):
/// [sigma] from the spread of a black/white edge (matched, not copied, see
/// [sigma]), [colorMatrix] fitted to 16
/// flat colours under it (mean error ≤ 3/255, Chrome ≈ 6/255). Natively the
/// effect's strength follows the transition: none at rest, full while the
/// page is open or dragged, the blur radius and the colour change both
/// scaling with it.
class ZoomBlurEffect {
  const ZoomBlurEffect({required this.sigma, required this.colorMatrix, this.darkVariant});

  /// Blur sigma at full strength, in logical pixels. The presets' values are
  /// calibrated so the blurred edge spreads as far as the native one does (on
  /// Impeller a large Flutter blur reads softer than its nominal sigma).
  final double sigma;

  /// Colour change at full strength, applied after the blur: 3 rows (red,
  /// green, blue out) of `r, g, b, offset`, in 0–1 sRGB.
  final List<double> colorMatrix;

  /// Used with a dark theme (the system materials adapt); null keeps this one.
  final ZoomBlurEffect? darkVariant;

  /// The effect for [brightness].
  ZoomBlurEffect resolve(Brightness brightness) => brightness == Brightness.dark ? (darkVariant ?? this) : this;

  /// The backdrop filter at [strength] (0 = none, 1 = full): the blur sigma
  /// and the colour matrix both blend linearly from nothing, as natively.
  ImageFilter filterAt(double strength) {
    final t = strength.clamp(0.0, 1.0);
    final m = colorMatrix;
    double c(int row, int col) => (row == col ? 1 - t : 0) + t * m[row * 4 + col];
    return ImageFilter.compose(
      outer: ColorFilter.matrix(<double>[
        c(0, 0), c(0, 1), c(0, 2), 0, t * m[3] * 255,
        c(1, 0), c(1, 1), c(1, 2), 0, t * m[7] * 255,
        c(2, 0), c(2, 1), c(2, 2), 0, t * m[11] * 255,
        0, 0, 0, 1, 0,
      ]),
      inner: ImageFilter.blur(sigmaX: sigma * t, sigmaY: sigma * t, tileMode: TileMode.clamp),
    );
  }

  /// `UIBlurEffect.Style.systemUltraThinMaterial`: the lightest frost. Adapts to a dark theme.
  static const systemUltraThinMaterial = ZoomBlurEffect(
    sigma: 27.7,
    colorMatrix: [
      0.5668, 0.0499, 0.0029, 0.3515,
      0.0159, 0.6033, 0.0006, 0.3516,
      0.0163, 0.0512, 0.5528, 0.3509,
    ],
    darkVariant: ZoomBlurEffect(
      sigma: 28.1,
      colorMatrix: [
        0.5522, 0.0153, 0.0059, 0.1098,
        0.0032, 0.5644, 0.0059, 0.1098,
        0.0034, 0.0141, 0.5562, 0.1098,
      ],
    ),
  );

  /// `UIBlurEffect.Style.systemThinMaterial`. Adapts to a dark theme.
  static const systemThinMaterial = ZoomBlurEffect(
    sigma: 37.5,
    colorMatrix: [
      0.4672, -0.0708, 0.0154, 0.5649,
      -0.021, 0.431, -0.0133, 0.5773,
      -0.0117, -0.051, 0.4644, 0.5644,
    ],
    darkVariant: ZoomBlurEffect(
      sigma: 38.2,
      colorMatrix: [
        0.4957, -0.1279, -0.0122, 0.1223,
        -0.0384, 0.4023, -0.007, 0.1209,
        -0.044, -0.1288, 0.5274, 0.1233,
      ],
    ),
  );

  /// `UIBlurEffect.Style.systemMaterial`. Adapts to a dark theme.
  static const systemMaterial = ZoomBlurEffect(
    sigma: 37.5,
    colorMatrix: [
      0.2822, -0.0766, 0.0198, 0.7548,
      -0.0266, 0.247, -0.0092, 0.7688,
      -0.0183, -0.0462, 0.2804, 0.7525,
    ],
    darkVariant: ZoomBlurEffect(
      sigma: 37.2,
      colorMatrix: [
        0.3391, -0.1415, -0.0166, 0.1505,
        -0.0342, 0.2327, -0.0176, 0.1505,
        -0.0356, -0.1406, 0.3567, 0.1507,
      ],
    ),
  );

  /// `UIBlurEffect.Style.systemThickMaterial`: nearly opaque. Adapts to a dark theme.
  static const systemThickMaterial = ZoomBlurEffect(
    sigma: 53.8,
    colorMatrix: [
      0.1197, -0.0572, 0.0074, 0.9056,
      -0.0222, 0.0906, -0.0095, 0.9143,
      -0.0146, -0.0382, 0.116, 0.9047,
    ],
    darkVariant: ZoomBlurEffect(
      sigma: 61.2,
      colorMatrix: [
        0.1499, -0.1125, -0.0179, 0.1442,
        -0.0306, 0.0695, -0.0199, 0.1448,
        -0.0313, -0.1119, 0.1625, 0.1446,
      ],
    ),
  );

  /// `UIBlurEffect.Style.systemChromeMaterial` (fit within 6/255 on average, up to 21; the native tone curve is not a matrix). Adapts to a dark theme.
  static const systemChromeMaterial = ZoomBlurEffect(
    sigma: 28.1,
    colorMatrix: [
      0.249, 0.0578, -0.0062, 0.745,
      0.033, 0.2913, -0.0181, 0.7456,
      0.0092, 0.0547, 0.2349, 0.7522,
    ],
    darkVariant: ZoomBlurEffect(
      sigma: 28.4,
      colorMatrix: [
        0.4407, -0.1718, -0.047, 0.1548,
        -0.0421, 0.3055, -0.0353, 0.1501,
        -0.0602, -0.1694, 0.4509, 0.1557,
      ],
    ),
  );

  /// `UIBlurEffect.Style.light`.
  static const light = ZoomBlurEffect(
    sigma: 37.5,
    colorMatrix: [
      0.698, 0, 0, 0.302,
      0, 0.698, 0, 0.302,
      0, 0, 0.698, 0.302,
    ],
  );

  /// `UIBlurEffect.Style.extraLight`.
  static const extraLight = ZoomBlurEffect(
    sigma: 23.4,
    colorMatrix: [
      0.2, 0, 0, 0.776,
      0, 0.2, 0, 0.776,
      0, 0, 0.2, 0.776,
    ],
  );

  /// `UIBlurEffect.Style.dark`.
  static const dark = ZoomBlurEffect(
    sigma: 21.9,
    colorMatrix: [
      0.271, 0, 0, 0.078,
      0, 0.271, 0, 0.078,
      0, 0, 0.271, 0.078,
    ],
  );

  /// `UIBlurEffect.Style.regular`: [light], or [dark] in a dark theme.
  static const regular = ZoomBlurEffect(
    sigma: 37.5,
    colorMatrix: [
      0.698, 0, 0, 0.302,
      0, 0.698, 0, 0.302,
      0, 0, 0.698, 0.302,
    ],
    darkVariant: ZoomBlurEffect(
      sigma: 21.9,
      colorMatrix: [
        0.271, 0, 0, 0.078,
        0, 0.271, 0, 0.078,
        0, 0, 0.271, 0.078,
      ],
    ),
  );

  /// `UIBlurEffect.Style.prominent`: [extraLight], or [dark] in a dark theme.
  static const prominent = ZoomBlurEffect(
    sigma: 23.4,
    colorMatrix: [
      0.2, 0, 0, 0.776,
      0, 0.2, 0, 0.776,
      0, 0, 0.2, 0.776,
    ],
    darkVariant: ZoomBlurEffect(
      sigma: 21.9,
      colorMatrix: [
        0.271, 0, 0, 0.078,
        0, 0.271, 0, 0.078,
        0, 0, 0.271, 0.078,
      ],
    ),
  );
}
