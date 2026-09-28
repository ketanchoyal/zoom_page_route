import 'dart:math' as math;
import 'dart:ui';

import 'zoom_native.dart';
import 'zoom_transition_spec.dart';

/// Where the page is drawn for one frame, and how the rest of the screen looks.
class ZoomFrame {
  const ZoomFrame({required this.rect, required this.radius, required this.dim, required this.originOpacity});

  /// The page's on-screen rect. The page is laid out full-size, scaled by
  /// `rect.width / screen.width` and clipped to `rect.height`.
  final Rect rect;

  /// Corner radius in screen points.
  final double radius;

  /// Black overlay opacity over the route below.
  final double dim;

  /// Opacity of the source copy drawn over the page.
  final double originOpacity;
}

/// Pure geometry of the zoom transition, kept separate so it can be tested and
/// compared with native measurements without widgets.
class ZoomGeometry {
  const ZoomGeometry({
    required this.spec,
    required this.screen,
    required this.source,
    required this.sourceRadius,
    required this.screenRadius,
  });

  final ZoomTransitionSpec spec;
  final Size screen;

  /// The source's rect in the same coordinate space as [screen].
  final Rect source;
  final double sourceRadius;

  /// The device's display corner radius; the page's corners grow to this.
  final double screenRadius;

  Rect get _full => Offset.zero & screen;

  double _crossfade(double progress) => 1 - (progress / ZoomNative.crossfadeEnd).clamp(0.0, 1.0);

  /// The rect [t] of the way from [a] to [b], interpolated the way iOS does it:
  /// width, centre and aspect ratio (height / width) are lerped, so the height
  /// follows from them. The page therefore keeps the source's shape for longer
  /// than a plain [Rect.lerp] (measured natively on iPhone and iPad: at half
  /// width progress the height is only ~38% of the way).
  static Rect _morph(Rect a, Rect b, double t) {
    if (a.width <= 0 || b.width <= 0) return Rect.lerp(a, b, t)!;
    final width = lerpDouble(a.width, b.width, t)!;
    final aspect = lerpDouble(a.height / a.width, b.height / b.width, t)!;
    return Rect.fromCenter(center: Offset.lerp(a.center, b.center, t)!, width: width, height: width * aspect);
  }

  /// Push/pop driven by the route animation ([progress] 0 = source, 1 = open).
  ZoomFrame transition(double progress) {
    return ZoomFrame(
      rect: _morph(source, _full, progress),
      radius: lerpDouble(sourceRadius, screenRadius, progress.clamp(0.0, 1.0))!,
      dim: ZoomNative.maxDim * progress.clamp(0.0, 1.0),
      originOpacity: _crossfade(progress),
    );
  }

  /// Pop after a drag was released at [release]: settles from the released
  /// frame ([progress] 1) into the source ([progress] 0).
  ZoomFrame settleFrom(ZoomFrame release, double progress) {
    final t = progress.clamp(0.0, 1.0);
    return ZoomFrame(
      rect: _morph(source, release.rect, progress),
      radius: lerpDouble(sourceRadius, release.radius, t)!,
      dim: release.dim * t,
      originOpacity: _crossfade(progress),
    );
  }

  /// Drag-down dismiss for a finger that went down at [anchor] and moved by
  /// [drag] (points). [anchor] defaults to the top centre, where the page top
  /// simply follows the finger.
  ZoomFrame verticalDrag(Offset drag, {Offset? anchor}) {
    final grab = anchor ?? Offset(screen.width / 2, 0);
    // Natively the page follows the finger less and less (rubber band), so a
    // drag to the bottom of the screen leaves a card, not a sliver.
    final raw = math.max(0.0, drag.dy) / screen.height;
    final damped = ZoomNative.verticalDragRubberBand * _tanh(raw / ZoomNative.verticalDragRubberBand);
    final dy = damped.clamp(0.0, ZoomNative.maxVerticalDrag) * screen.height;
    final baseScale = 1 - ZoomNative.verticalDragScaleSlope * dy / screen.height;
    final portrait = screen.height > screen.width;
    // The portrait lift depends on where the top ends up, which depends on the
    // scale; a few fixed-point steps converge (the lift is a small cubic).
    var lift = 1.0;
    var scale = baseScale;
    var top = 0.0;
    for (var i = 0; i < 4; i++) {
      scale = baseScale * lift;
      top = grab.dy + dy - grab.dy * scale;
      final u = (top / screen.height).clamp(0.0, 1.0);
      lift = portrait ? 1 - ZoomNative.portraitDragLift * u * u * u : 1.0;
    }
    final width = screen.width * scale;
    final left = grab.dx + drag.dx - grab.dx * scale;
    final bottom = math.min(screen.height * lift, top + screen.height * scale);
    final u = top / screen.height;
    return ZoomFrame(
      rect: Rect.fromLTRB(left, top, left + width, math.max(top, bottom)),
      radius: screenRadius * scale,
      dim: math.max(ZoomNative.minDragDim, ZoomNative.maxDim - ZoomNative.verticalDragDimSlope * u),
      originOpacity: 0,
    );
  }

  /// Left-edge swipe for a finger that went down at [anchor] and moved by
  /// [drag] (points). [anchor] defaults to the left edge's centre.
  ZoomFrame edgeDrag(Offset drag, {Offset? anchor}) {
    final grab = anchor ?? Offset(0, screen.height / 2);
    final u = (math.max(0.0, drag.dx) / screen.width).clamp(0.0, ZoomNative.maxEdgeDrag);
    final scale = 1 - ZoomNative.edgeDragScaleSlope * u;
    final left = grab.dx + u * screen.width - grab.dx * scale;
    final top = grab.dy + drag.dy - grab.dy * scale;
    return ZoomFrame(
      rect: Rect.fromLTWH(left, top, screen.width * scale, screen.height * scale),
      radius: screenRadius * scale,
      dim: math.max(ZoomNative.minDragDim, ZoomNative.maxDim - ZoomNative.edgeDragDimSlope * u),
      originOpacity: 0,
    );
  }

  /// A system back gesture (Android predictive back) moves the page exactly
  /// like the left-edge swipe: [start] is where the finger went down, [now]
  /// where it is. A swipe from the right edge is the mirror image.
  ZoomFrame systemBack(Offset start, Offset now, {required bool fromLeft}) {
    if (fromLeft) return edgeDrag(now - start, anchor: start);
    final mirrored = edgeDrag(
      Offset(start.dx - now.dx, now.dy - start.dy),
      anchor: Offset(screen.width - start.dx, start.dy),
    );
    final r = mirrored.rect;
    return ZoomFrame(
      rect: Rect.fromLTRB(screen.width - r.right, r.top, screen.width - r.left, r.bottom),
      radius: mirrored.radius,
      dim: mirrored.dim,
      originOpacity: 0,
    );
  }

  static double _tanh(double x) {
    final e = math.exp(2 * x);
    return (e - 1) / (e + 1);
  }
}
