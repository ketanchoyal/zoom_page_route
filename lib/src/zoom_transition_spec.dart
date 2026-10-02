import 'dart:ui' show Color;

import 'package:flutter/physics.dart';

import 'ios_spring.dart';
import 'zoom_blur_effect.dart';

/// The choices an app can make about the zoom transition. Everything that
/// describes how iOS itself animates (drag geometry, fades, dim, shadow) is
/// measured from native SwiftUI and fixed; see the README's "Measured spec".
class ZoomTransitionSpec {
  const ZoomTransitionSpec({
    SpringDescription? openSpring,
    SpringDescription? closeSpring,
    SpringDescription? toolbarOpenSpring,
    SpringDescription? toolbarCloseSpring,
    this.recedeRouteBelow = false,
    this.backgroundFillColor,
    this.dimmingVisualEffect,
    this.toolbarGlassColor = const Color(0xFFFFFFFF),
    this.edgeWidth = 24,
    this.dismissVelocity = 700,
    this.verticalDismissFraction = 0.2,
    this.edgeDismissFraction = 0.3,
  }) : _openSpring = openSpring,
       _closeSpring = closeSpring,
       _toolbarOpenSpring = toolbarOpenSpring,
       _toolbarCloseSpring = toolbarCloseSpring;

  /// The spec with every default (measured) value.
  static const ZoomTransitionSpec standard = ZoomTransitionSpec();

  final SpringDescription? _openSpring;
  final SpringDescription? _closeSpring;
  final SpringDescription? _toolbarOpenSpring;
  final SpringDescription? _toolbarCloseSpring;

  // The springs default to IOSSpring's zoom navigation presets (built at
  // runtime, so they are filled in here and the constructor stays const).

  /// Push. Default [IOSSpring.zoomOpen] (native: 0.375 s, ζ 0.98). Any
  /// [IOSSpring] preset can be passed instead, e.g. `IOSSpring.snappy`.
  SpringDescription get openSpring => _openSpring ?? IOSSpring.zoomOpen;

  /// Pop, including the settle after a drag dismiss. Default
  /// [IOSSpring.zoomClose] (native: 0.33 s, ζ 0.98).
  SpringDescription get closeSpring => _closeSpring ?? IOSSpring.zoomClose;

  /// Push/pop when the source is a toolbar item (`ZoomSource(toolbar: true)`),
  /// natively quicker and a touch bouncier. Defaults [IOSSpring.zoomToolbarOpen]
  /// and [IOSSpring.zoomToolbarClose].
  SpringDescription get toolbarOpenSpring => _toolbarOpenSpring ?? IOSSpring.zoomToolbarOpen;
  SpringDescription get toolbarCloseSpring => _toolbarCloseSpring ?? IOSSpring.zoomToolbarClose;

  /// Whether the route below recedes (shrinks) while this page is open, as it
  /// does natively. Off by default: natively only the content recedes and the
  /// navigation bar stays put, while here the whole route shrinks, which only
  /// looks right when the app's screens are built for it.
  final bool recedeRouteBelow;

  /// With [recedeRouteBelow], fills the area the receding route no longer
  /// covers. Defaults to the theme's scaffold background.
  final Color? backgroundFillColor;

  /// A blur material over the route below in place of the dim, as UIKit's
  /// `ZoomOptions.dimmingVisualEffect` (e.g. [ZoomBlurEffect.systemMaterial]).
  /// Null (the default) dims, as natively. Like the native effect, it is
  /// absent at rest, at full strength while the page is open or dragged, and
  /// follows the transition's progress opening and closing.
  final ZoomBlurEffect? dimmingVisualEffect;

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
