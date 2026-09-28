import 'dart:ui' show Color;

import 'package:flutter/physics.dart';

/// The choices an app can make about the zoom transition. Everything that
/// describes how iOS itself animates (drag geometry, fades, dim, shadow) is
/// measured from native SwiftUI and fixed; see the README's "Measured spec".
class ZoomTransitionSpec {
  const ZoomTransitionSpec({
    this.openSpring = const SpringDescription(mass: 1, stiffness: 281, damping: 32.8),
    this.closeSpring = const SpringDescription(mass: 1, stiffness: 365, damping: 37.5),
    this.toolbarOpenSpring = const SpringDescription(mass: 1, stiffness: 503.55, damping: 39.05),
    this.toolbarCloseSpring = const SpringDescription(mass: 1, stiffness: 685.39, damping: 47.12),
    this.recedeRouteBelow = false,
    this.backgroundFillColor,
    this.toolbarGlassColor = const Color(0xFFFFFFFF),
    this.edgeWidth = 24,
    this.dismissVelocity = 700,
    this.verticalDismissFraction = 0.2,
    this.edgeDismissFraction = 0.3,
  });

  /// The spec with every default (measured) value.
  static const ZoomTransitionSpec standard = ZoomTransitionSpec();

  /// Push. Native: ζ ≈ 0.98, response ≈ 0.375 s.
  final SpringDescription openSpring;

  /// Pop, including the settle after a drag dismiss. Native: ζ ≈ 0.98,
  /// response ≈ 0.33 s.
  final SpringDescription closeSpring;

  /// Push/pop when the source is a toolbar item (`ZoomSource(toolbar: true)`),
  /// which natively is quicker and a touch bouncier: response 0.28 s / ζ 0.87
  /// opening, 0.24 s / ζ 0.9 closing (`IOSSpring.withResponse`).
  final SpringDescription toolbarOpenSpring;
  final SpringDescription toolbarCloseSpring;

  /// Whether the route below recedes (shrinks) while this page is open, as it
  /// does natively. Off by default: natively only the content recedes and the
  /// navigation bar stays put, while here the whole route shrinks, which only
  /// looks right when the app's screens are built for it.
  final bool recedeRouteBelow;

  /// With [recedeRouteBelow], fills the area the receding route no longer
  /// covers. Defaults to the theme's scaffold background.
  final Color? backgroundFillColor;

  /// Tint of the glass a toolbar source grows into (white natively; darker in
  /// a dark theme).
  final Color toolbarGlassColor;

  /// Width of the left-edge strip that starts an edge swipe.
  final double edgeWidth;

  /// Release speed (pt/s, in the dismiss direction) that dismisses regardless
  /// of distance.
  final double dismissVelocity;

  /// Drag fraction (of the screen height / width) past which a slow release
  /// still dismisses.
  final double verticalDismissFraction;
  final double edgeDismissFraction;
}
