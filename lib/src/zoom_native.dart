/// Values measured from native SwiftUI `.navigationTransition(.zoom)` (iPhone
/// and iPad simulators; see the README's "Measured spec"). They describe what
/// iOS does rather than a style choice, so they are fixed here instead of
/// being part of `ZoomTransitionSpec`.
abstract final class ZoomNative {
  /// Black overlay on the route below at full progress (α = maxDim · progress).
  static const double maxDim = 0.33;

  /// While dragging, dim = max(minDragDim, maxDim − slope · u), with u the drag
  /// as a fraction of the screen height (vertical) or width (edge).
  static const double minDragDim = 0.15;
  static const double verticalDragDimSlope = 0.49;
  static const double edgeDragDimSlope = 1.0;

  /// Drag down: the page scales uniformly about the point the finger grabbed,
  /// which stays under the finger: scale = (1 − slope · dy / height) · b, with
  /// the bottom edge on the screen bottom (landscape) or at b · height in
  /// portrait, b = 1 − lift · u³ (u = page top / height).
  static const double verticalDragScaleSlope = 0.662;
  static const double portraitDragLift = 0.453;

  /// The page follows the finger with a rubber band: effective travel =
  /// band · tanh(travel / band), fractions of the screen height, so a drag to
  /// the bottom leaves a card (top ≈ 0.65) rather than a sliver.
  static const double verticalDragRubberBand = 0.7;

  /// Left-edge swipe: uniform scale 1 − slope · u about the grab point.
  static const double edgeDragScaleSlope = 0.65;

  /// Caps on u so a long drag cannot collapse the page.
  static const double maxVerticalDrag = 0.75;
  static const double maxEdgeDrag = 0.9;

  /// Opening, the source copy fades out over progress 0 → crossfadeEnd.
  static const double crossfadeEnd = 0.45;

  /// Closing, the source copy fades back in early: opacity =
  /// (1 − progress) / closeCrossfadeLength (opaque from 40% of the way).
  static const double closeCrossfadeLength = 0.6;

  /// Closing with a content source, the page fades part-way under the
  /// returning source copy: alpha = end + (1 − end) · progress ^ power.
  static const double contentCloseEndOpacity = 0.6;
  static const double contentCloseFadePower = 0.5;

  /// Toolbar sources: the button's glass grows into the page's shape and the
  /// page fades in on top (alpha = progress / fadeInEnd), and out while
  /// closing (alpha = progress ^ fadeOutPower, glass = min(opacity, progress)).
  static const double toolbarFadeInEnd = 0.8;
  static const double toolbarFadeOutPower = 1.3;
  static const double toolbarGlassOpacity = 0.72;

  /// Closing into a toolbar source there is no source copy over the page, so
  /// the button itself comes back once the page is this close to gone
  /// (natively ≈120 ms after the page disappears, not when the spring settles).
  static const double toolbarRevealProgress = 0.03;

  /// No source: grows out of a centred rect this fraction of the screen width
  /// wide, height / width = aspect, and fades (from startOpacity to 1 by
  /// fadeInEnd opening; alpha = progress ^ fadeOutPower closing).
  static const double sourcelessWidth = 0.35;
  static const double sourcelessAspect = 1.31;
  static const double sourcelessStartOpacity = 0.35;
  static const double sourcelessFadeInEnd = 1.0;
  static const double sourcelessFadeOutPower = 0.7;

  /// With recedeRouteBelow, the route below shrinks about the screen centre to
  /// this scale as the page opens.
  static const double backgroundScale = 0.915;

  /// Soft, centred shadow around the page while it is not full screen.
  static const double shadowOpacity = 0.18;
  static const double shadowBlur = 40;
}
