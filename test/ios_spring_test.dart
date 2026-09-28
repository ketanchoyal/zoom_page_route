import 'dart:math' as math;

import 'package:flutter/physics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoom_page_route/zoom_page_route.dart';

double _overshoot(SpringDescription spring) {
  final sim = SpringSimulation(spring, 0, 1, 0);
  var peak = 0.0;
  for (var t = 0.0; t < 3; t += 0.001) {
    peak = math.max(peak, sim.x(t));
  }
  return math.max(0, peak - 1);
}

void main() {
  test('Spring(duration:bounce:) conversion', () {
    final s = IOSSpring.of(duration: 0.5, bounce: 0.3);
    expect(s.mass, 1);
    expect(s.stiffness, closeTo(math.pow(2 * math.pi / 0.5, 2), 1e-9));
    expect(s.damping, closeTo(4 * math.pi * 0.7 / 0.5, 1e-9));
    expect(IOSSpring.dampingRatioOf(s), closeTo(0.7, 1e-9));
    expect(IOSSpring.responseOf(s), closeTo(0.5, 1e-9));
  });

  test('negative bounce is overdamped: ζ = 1 / (1 + bounce)', () {
    expect(IOSSpring.dampingRatioOf(IOSSpring.of(bounce: -0.5)), closeTo(2, 1e-9));
  });

  test('preset damping ratios and responses', () {
    expect(IOSSpring.dampingRatioOf(IOSSpring.smooth), closeTo(1.0, 1e-9));
    expect(IOSSpring.dampingRatioOf(IOSSpring.snappy), closeTo(0.85, 1e-9));
    expect(IOSSpring.dampingRatioOf(IOSSpring.bouncy), closeTo(0.70, 1e-9));
    expect(IOSSpring.responseOf(IOSSpring.interactive), closeTo(0.15, 1e-9));
    expect(IOSSpring.dampingRatioOf(IOSSpring.interactive), closeTo(0.86, 1e-9));
    expect(IOSSpring.responseOf(IOSSpring.legacyDefault), closeTo(0.55, 1e-9));
    expect(IOSSpring.snappyWith(extraBounce: 0.1).damping, closeTo(IOSSpring.of(bounce: 0.25).damping, 1e-9));
  });

  // Overshoot measured from the SwiftUI recording (native_reference Springs screen).
  test('overshoot matches native SwiftUI', () {
    expect(_overshoot(IOSSpring.smooth), lessThan(0.001)); // native 0.0 %
    expect(_overshoot(IOSSpring.snappy), closeTo(0.004, 0.004)); // native 0.4 %
    expect(_overshoot(IOSSpring.bouncy), closeTo(0.042, 0.006)); // native 4.2 %
    // Native read 0.1 %, but the recording (~1 frame / 40 ms) is too sparse to
    // catch the peak of a 0.15 s spring; ζ 0.86 gives ≈0.5 % in theory.
    expect(_overshoot(IOSSpring.interactive), lessThan(0.006));
    expect(_overshoot(IOSSpring.legacyDefault), closeTo(0.008, 0.004)); // native 0.8 %
  });
}
