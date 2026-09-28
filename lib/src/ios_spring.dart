import 'dart:math' as math;

import 'package:flutter/physics.dart';

/// SwiftUI / UIKit spring presets as Flutter [SpringDescription]s, for
/// [SpringSimulation], `AnimationController.animateWith`, or
/// `ZoomTransitionSpec(openSpring: …)`.
///
/// Uses Apple's `Spring(duration:bounce:)` conversion (mass 1):
/// stiffness = (2π / duration)², damping = 4π · ζ / duration, where the damping
/// ratio ζ = 1 − bounce for bounce ≥ 0 and 1 / (1 + bounce) for bounce < 0
/// (overdamped). Checked against SwiftUI (`native_reference`, Springs screen;
/// every animated value logged per frame): each preset stays within 1.8–3.6 pt
/// of the native curve over a 300 pt move (~1 %, no more than native varies
/// between runs), overshoot matches (bouncy ≈ 4 %, snappy < 1 %, smooth none),
/// and `.spring` behaves exactly like `.smooth`.
///
/// ```dart
/// controller.animateWith(SpringSimulation(IOSSpring.bouncy, 0, 1, 0));
/// ```
abstract final class IOSSpring {
  /// `Spring(duration:bounce:)`: [duration] is the perceptual duration (the
  /// response, in seconds); [bounce] is −1…1 (0 = no bounce).
  static SpringDescription of({double duration = 0.5, double bounce = 0}) {
    assert(duration > 0, 'duration must be > 0');
    assert(bounce >= -1 && bounce <= 1, 'bounce must be within -1…1');
    final dampingRatio = bounce >= 0 ? 1 - bounce : 1 / (1 + bounce);
    return withResponse(response: duration, dampingRatio: dampingRatio);
  }

  /// `Spring(response:dampingRatio:)` / `Animation.spring(response:dampingFraction:)`
  /// and UIKit's `UISpringTimingParameters(dampingRatio:response:)`.
  static SpringDescription withResponse({double response = 0.55, double dampingRatio = 0.825}) {
    assert(response > 0, 'response must be > 0');
    final stiffness = math.pow(2 * math.pi / response, 2).toDouble();
    final damping = 4 * math.pi * dampingRatio / response;
    return SpringDescription(mass: 1, stiffness: stiffness, damping: damping);
  }

  /// `.smooth`: no bounce (duration 0.5 s, bounce 0). SwiftUI's default `.spring` is the same.
  static final SpringDescription smooth = of();

  /// `.snappy`: a small bounce (duration 0.5 s, bounce 0.15).
  static final SpringDescription snappy = of(bounce: 0.15);

  /// `.bouncy`: a visible bounce (duration 0.5 s, bounce 0.3).
  static final SpringDescription bouncy = of(bounce: 0.3);

  /// SwiftUI's default `.spring` (identical to [smooth]).
  static final SpringDescription standard = smooth;

  /// `.interactiveSpring`: quick, for following a finger (response 0.15 s, damping 0.86).
  static final SpringDescription interactive = withResponse(response: 0.15, dampingRatio: 0.86);

  /// The pre-iOS 17 `Animation.spring()` default (response 0.55 s, damping 0.825).
  static final SpringDescription legacyDefault = withResponse();

  /// `.smooth(duration:extraBounce:)`.
  static SpringDescription smoothWith({double duration = 0.5, double extraBounce = 0}) =>
      of(duration: duration, bounce: extraBounce);

  /// `.snappy(duration:extraBounce:)`.
  static SpringDescription snappyWith({double duration = 0.5, double extraBounce = 0}) =>
      of(duration: duration, bounce: 0.15 + extraBounce);

  /// `.bouncy(duration:extraBounce:)`.
  static SpringDescription bouncyWith({double duration = 0.5, double extraBounce = 0}) =>
      of(duration: duration, bounce: 0.3 + extraBounce);

  /// The damping ratio (ζ) of [spring]: < 1 bounces, 1 is critically damped.
  static double dampingRatioOf(SpringDescription spring) =>
      spring.damping / (2 * math.sqrt(spring.stiffness * spring.mass));

  /// The response (perceptual duration, seconds) of [spring].
  static double responseOf(SpringDescription spring) => 2 * math.pi / math.sqrt(spring.stiffness / spring.mass);
}
