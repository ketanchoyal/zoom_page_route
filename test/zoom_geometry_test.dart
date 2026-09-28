import 'dart:ui';

import 'package:flutter/physics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoom_page_route/zoom_page_route.dart';

/// The defaults are checked against frames measured from a native SwiftUI
/// `.navigationTransition(.zoom)` recording on a 402×874 pt iPhone simulator.
void main() {
  const screen = Size(402, 874);
  const source = Rect.fromLTWH(16, 361, 150, 100);
  final geometry = ZoomGeometry(
    spec: ZoomTransitionSpec.standard,
    screen: screen,
    source: source,
    sourceRadius: 12,
    screenRadius: 61.5,
  );

  group('drag-down dismiss', () {
    // Native, finger down at 30% height: top 410, width 288, height 424.
    const anchor = Offset(201, 262);
    final atTop410 = _dragToTop(geometry, anchor, 410);
    test('matches the native frame with the page top at 410', () {
      expect(atTop410.rect.top, closeTo(410, 0.5));
      expect(atTop410.rect.width, closeTo(288, 4));
      expect(atTop410.rect.height, closeTo(424, 4));
      expect(atTop410.rect.center.dx, closeTo(201, 1));
    });

    // Native, finger from 12% to the very bottom: the page top stops near 0.65
    // and it stays a card (≈0.53 wide, ≈0.25 tall), not a sliver.
    test('a full-length drag rubber-bands instead of collapsing the page', () {
      final frame = geometry.verticalDrag(const Offset(0, 874 * 0.87), anchor: const Offset(201, 874 * 0.12));
      expect(frame.rect.top / 874, closeTo(0.65, 0.04));
      expect(frame.rect.width / 402, closeTo(0.53, 0.04));
      expect(frame.rect.height / 874, greaterThan(0.2));
    });

    test('corner radius shrinks with the width, as natively (≈44 at 288 wide)', () {
      expect(atTop410.radius, closeTo(44, 1.5));
    });

    // Native samples (fractions of the screen) at page top u = 0.45, for three
    // finger start points; the same numbers on iPhone and iPad portrait.
    for (final (name, size, start, width, height, bottom, centerX) in [
      ('iPad portrait, finger at 15%', const Size(834, 1210), const Offset(0.5, 0.15), 0.703, 0.511, 0.960, 0.5),
      ('iPad portrait, finger at 45%', const Size(834, 1210), const Offset(0.5, 0.45), 0.751, 0.511, 0.960, 0.5),
      ('iPhone, finger at 20% x / 30% y', const Size(402, 874), const Offset(0.2, 0.30), 0.726, 0.508, 0.959, 0.418),
      ('iPad landscape, finger at 15%: bottom stays on the screen edge', const Size(1210, 834), const Offset(0.5, 0.15), 0.726, 0.547, 1.0, 0.5),
      ('iPad landscape, finger at 20% x / 30% y', const Size(1210, 834), const Offset(0.2, 0.30), 0.752, 0.549, 1.0, 0.425),
    ]) {
      test('matches native: $name', () {
        final g = ZoomGeometry(spec: ZoomTransitionSpec.standard, screen: size, source: source, sourceRadius: 12, screenRadius: 30);
        final frame = _dragToTop(g, Offset(start.dx * size.width, start.dy * size.height), 0.45 * size.height);
        expect(frame.rect.width / size.width, closeTo(width, 0.01));
        expect(frame.rect.height / size.height, closeTo(height, 0.008));
        expect(frame.rect.bottom / size.height, closeTo(bottom, 0.006));
        expect(frame.rect.center.dx / size.width, closeTo(centerX, 0.006));
      });
    }

    test('dim falls from 0.33 and floors at 0.15', () {
      expect(geometry.verticalDrag(Offset.zero).dim, closeTo(0.33, 0.01));
      expect(geometry.verticalDrag(const Offset(0, 190)).dim, closeTo(0.22, 0.02)); // native 0.228 at u≈0.22
      expect(geometry.verticalDrag(const Offset(0, 410)).dim, 0.15);
    });
  });

  group('left-edge swipe', () {
    // Native: a swipe started at 80% height stays anchored there (y ≈ 967).
    test('scales about the point the finger grabbed', () {
      final g = ZoomGeometry(
        spec: ZoomTransitionSpec.standard,
        screen: const Size(834, 1210),
        source: source,
        sourceRadius: 12,
        screenRadius: 30,
      );
      final frame = g.edgeDrag(const Offset(324, 0), anchor: const Offset(0, 968));
      expect(frame.rect.left, closeTo(324, 1));
      expect(frame.rect.height / 1210, closeTo(0.745, 0.01));
      expect(frame.rect.top / (1 - frame.rect.height / 1210), closeTo(967, 3));
    });

    // Native: scale 0.840 at u 0.249, 0.675 at u 0.4975, vertically centred.
    test('scales uniformly around the vertical centre', () {
      final a = geometry.edgeDrag(const Offset(100, 0));
      expect(a.rect.height / screen.height, closeTo(0.840, 0.01));
      expect(a.rect.center.dy, closeTo(437, 1));
      final b = geometry.edgeDrag(const Offset(200, 0));
      expect(b.rect.height / screen.height, closeTo(0.675, 0.01));
      expect(b.rect.left, closeTo(200, 1));
    });
  });

  group('push / pop', () {
    test('open: dim is 0.33·progress and the source fades out by 45%', () {
      expect(geometry.transition(0.586).dim, closeTo(0.184, 0.01)); // native 0.184
      expect(geometry.transition(0.2).originOpacity, closeTo(1 - 0.2 / 0.45, 1e-9));
      expect(geometry.transition(0.5).originOpacity, 0);
    });

    test('the open spring settles like native (ζ≈0.98, response≈0.375 s) without visible overshoot', () {
      final sim = SpringSimulation(ZoomTransitionSpec.standard.openSpring, 0, 1, 0);
      // Native first-open progress, relative to the fitted start time.
      const native = [(0.113, 0.586), (0.147, 0.720), (0.180, 0.818), (0.213, 0.885), (0.263, 0.945), (0.313, 0.973), (0.382, 0.990)];
      for (final (t, p) in native) {
        expect(sim.x(t), closeTo(p, 0.02), reason: 'at ${t}s');
      }
      var peak = 0.0;
      for (var t = 0.0; t < 1.5; t += 0.005) {
        if (sim.x(t) > peak) peak = sim.x(t);
      }
      expect(peak, lessThan(1.001));
    });

    // Native lerps width, centre and aspect ratio, so the height lags the width
    // (iPhone: height 45% of the way at 57% width; iPad Pro 11": 38% at 50%).
    test('the page keeps the source shape longer, as natively', () {
      final frame = geometry.transition(0.57);
      expect((frame.rect.width - 150) / (402 - 150), closeTo(0.57, 1e-9));
      expect((frame.rect.height - 100) / (874 - 100), closeTo(0.45, 0.02));
      final center = Offset.lerp(source.center, const Offset(201, 437), 0.57)!;
      expect((frame.rect.center - center).distance, lessThan(1e-9));
      final ipad = ZoomGeometry(
        spec: ZoomTransitionSpec.standard,
        screen: const Size(834, 1210),
        source: const Rect.fromLTWH(16, 198, 150, 100),
        sourceRadius: 12,
        screenRadius: 30,
      ).transition(0.5);
      expect((ipad.rect.height - 100) / (1210 - 100), closeTo(0.38, 0.02));
    });

    test('the close spring is a little quicker than the open one', () {
      final open = SpringSimulation(ZoomTransitionSpec.standard.openSpring, 0, 1, 0);
      final close = SpringSimulation(ZoomTransitionSpec.standard.closeSpring, 0, 1, 0);
      expect(close.x(0.1), greaterThan(open.x(0.1)));
    });
  });
}

/// The drag frame whose page top is at [top], found by bisection (natively the
/// finger's travel is not recorded, only the page's rect).
ZoomFrame _dragToTop(ZoomGeometry geometry, Offset anchor, double top) {
  var lo = 0.0, hi = geometry.screen.height;
  for (var i = 0; i < 60; i++) {
    final mid = (lo + hi) / 2;
    if (geometry.verticalDrag(Offset(0, mid), anchor: anchor).rect.top < top) {
      lo = mid;
    } else {
      hi = mid;
    }
  }
  return geometry.verticalDrag(Offset(0, lo), anchor: anchor);
}
