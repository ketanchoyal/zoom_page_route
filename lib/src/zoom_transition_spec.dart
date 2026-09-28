import 'dart:ui' show Color;

import 'package:flutter/physics.dart';

import 'ios_spring.dart';

/// Every tunable of the zoom transition, defaulting to values measured from a
/// native SwiftUI `.navigationTransition(.zoom)` recording (iOS 27, iPhone
/// simulator, 402×874 pt): the page's on-screen rect and the dimmed background
/// were tracked frame by frame and the springs fitted to that curve.
class ZoomTransitionSpec {
  ZoomTransitionSpec({
    this.openSpring = const SpringDescription(mass: 1, stiffness: 281, damping: 32.8),
    this.closeSpring = const SpringDescription(mass: 1, stiffness: 365, damping: 37.5),
    SpringDescription? toolbarOpenSpring,
    SpringDescription? toolbarCloseSpring,
    this.maxDim = 0.33,
    this.minDragDim = 0.15,
    this.verticalDragDimSlope = 0.49,
    this.edgeDragDimSlope = 1.0,
    this.verticalDragScaleSlope = 0.662,
    this.portraitDragLift = 0.453,
    this.edgeDragScaleSlope = 0.65,
    this.maxVerticalDrag = 0.75,
    this.maxEdgeDrag = 0.9,
    this.crossfadeEnd = 0.45,
    this.edgeWidth = 24,
    this.backgroundScale = 0.915,
    this.backgroundFillColor,
    this.shadowOpacity = 0.18,
    this.shadowBlur = 40,
    this.dismissVelocity = 700,
    this.verticalDismissFraction = 0.2,
    this.edgeDismissFraction = 0.3,
  }) : toolbarOpenSpring = toolbarOpenSpring ?? IOSSpring.withResponse(response: 0.28, dampingRatio: 0.87),
       toolbarCloseSpring = toolbarCloseSpring ?? IOSSpring.withResponse(response: 0.24, dampingRatio: 0.9);

  /// The spec with every default (measured) value.
  static final ZoomTransitionSpec standard = ZoomTransitionSpec();

  /// Push. Fitted: ζ ≈ 0.98, response ≈ 0.375 s (two recordings, RMS < 0.004).
  final SpringDescription openSpring;

  /// Pop, including the settle after a drag dismiss. Fitted: ζ ≈ 0.98,
  /// response ≈ 0.33 s (slightly quicker than [openSpring]).
  final SpringDescription closeSpring;

  /// Push/pop when the source is a toolbar item (`ZoomSource(toolbar: true)`),
  /// e.g. a cart button in the app bar. Natively this zoom is clearly quicker
  /// and a touch bouncier than from content: measured response ≈ 0.25–0.33 s,
  /// ζ ≈ 0.83–0.92 (the iOS 26 glass-button morph blends into the start, so the
  /// curve varies more between runs than the content zoom).
  final SpringDescription toolbarOpenSpring;
  final SpringDescription toolbarCloseSpring;

  /// Black overlay on the route below at full progress (α = [maxDim] · progress).
  final double maxDim;

  /// Dim never drops below this while the page is being dragged.
  final double minDragDim;

  /// While dragging, dim = max([minDragDim], [maxDim] − slope · u), with u the
  /// drag distance as a fraction of the screen height (vertical) or width (edge).
  final double verticalDragDimSlope;
  final double edgeDragDimSlope;

  /// Drag-down dismiss. As natively, the page scales uniformly about the point
  /// the finger grabbed, which stays under the finger:
  /// scale = (1 − [verticalDragScaleSlope] · dy / screen height) · b.
  /// Its bottom edge stays on the screen's bottom (landscape) or rises to
  /// b · height in portrait, with b = 1 − [portraitDragLift] · u³ and u the
  /// page top as a fraction of the screen height. Fitted to native drags on
  /// iPhone, iPad portrait and iPad landscape from three start points (width
  /// within 1%, height within 0.6% of the screen).
  final double verticalDragScaleSlope;
  final double portraitDragLift;

  /// Left-edge swipe: uniform scale 1 − [edgeDragScaleSlope] · u about the
  /// point the finger grabbed (u = dx / screen width).
  final double edgeDragScaleSlope;

  /// Caps on u so a long drag cannot collapse the page.
  final double maxVerticalDrag;
  final double maxEdgeDrag;

  /// The source copy fades from 1 to 0 over progress 0 → [crossfadeEnd] (and
  /// back on close), which is what the native page-over-source fade looks like.
  final double crossfadeEnd;

  /// Width of the left-edge strip that starts an edge swipe.
  final double edgeWidth;

  /// The route below shrinks about the screen centre to this scale as the
  /// page opens (1 − (1 − [backgroundScale]) · progress), holds it while the
  /// page is dragged, and grows back on close. Native: ≈0.915.
  final double backgroundScale;

  /// Fills the area the receding route no longer covers. Defaults to the
  /// theme's scaffold background (natively it is the page's own background).
  final Color? backgroundFillColor;

  /// Soft, centred shadow around the page while it is not full screen.
  /// Native: ~15% darker 6 pt from the edge, ~8% at 20 pt, gone by ~40 pt.
  final double shadowOpacity;
  final double shadowBlur;

  /// Release speed (pt/s, in the dismiss direction) that dismisses regardless
  /// of distance.
  final double dismissVelocity;

  /// Drag fraction (u) past which a slow release still dismisses.
  final double verticalDismissFraction;
  final double edgeDismissFraction;
}
