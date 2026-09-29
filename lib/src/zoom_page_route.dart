import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart' show MaterialRouteTransitionMixin, Theme;
import 'package:flutter/physics.dart';

import 'zoom_geometry.dart';
import 'zoom_source.dart';
import 'zoom_native.dart';
import 'zoom_transition_spec.dart';

/// iOS "zoom" navigation: the page grows out of the [ZoomSource] with the same
/// [tag] and shrinks back into it, with drag-down and left-edge-swipe dismiss.
///
/// The page is built exactly once, in this route: only a copy of the (small)
/// source widget is drawn during the flight. (A heroine-based route rebuilt the
/// whole destination page in its flight shuttle, so every push, pop and drag
/// ran the page's initState — and its API calls — twice.)
///
/// ```dart
/// ZoomSource(tag: order.id, child: OrderCard(order));
/// Navigator.of(context).push(ZoomPageRoute(tag: order.id, builder: (_) => OrderScreen(order)));
/// ```
class ZoomPageRoute<T> extends PageRoute<T> {
  ZoomPageRoute({
    required this.builder,
    required this.tag,
    BuildContext? sourceContext,
    super.settings,
    ZoomTransitionSpec? spec,
    double? screenCornerRadius,
    bool maintainState = true,
  }) : spec = spec ?? ZoomTransitionSpec.standard,
       _screenCornerRadius = screenCornerRadius,
       _maintainState = maintainState,
       // Never a fullscreen dialog as far as the framework is concerned: that
       // disables popGestureEnabled and with it the dismiss gestures.
       super(fullscreenDialog: false) {
    // Looked up now, while the route we're pushed from is still current.
    // [sourceContext] (at or below a ZoomSource) picks that exact source when
    // several share [tag]; otherwise the one just tapped wins.
    _sourceHandle = ZoomSource.find(tag, context: sourceContext);
  }

  final WidgetBuilder builder;
  final Object tag;
  final ZoomTransitionSpec spec;

  /// Device display corner radius, used when a route doesn't pass
  /// `screenCornerRadius`. Set it once at startup (e.g. from a native plugin);
  /// 0 gives square corners.
  static double Function() defaultScreenCornerRadius = () => 0;

  final double? _screenCornerRadius;
  double get screenCornerRadius => _screenCornerRadius ?? defaultScreenCornerRadius();

  final bool _maintainState;
  ZoomSourceHandle? _sourceHandle;

  /// The source, switched to its replacement if the original has left the
  /// tree while this page is open (e.g. its list item was rebuilt).
  ZoomSourceHandle? get _source {
    final current = _sourceHandle;
    if (current == null || current.isAvailable) return current;
    final replacement = zoomSourceReplacement(tag, current);
    if (replacement == null) return current;
    current.show();
    replacement.hide();
    return _sourceHandle = replacement;
  }

  final ValueNotifier<double> _dismissProgress = ValueNotifier(0);

  /// 0 when idle, up to 1 while the page is dragged toward dismissal.
  ValueListenable<double> get dismissProgress => _dismissProgress;

  static ZoomPageRoute<dynamic>? maybeOf(BuildContext context) {
    final route = ModalRoute.of(context);
    return route is ZoomPageRoute ? route : null;
  }

  double _releaseVelocity = 0;

  @override
  bool get maintainState => _maintainState;

  @override
  bool get opaque => false;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 500);

  @override
  Simulation? createSimulation({required bool forward}) {
    final velocity = _releaseVelocity;
    _releaseVelocity = 0;
    final toolbar = _source?.isToolbarItem ?? false;
    return SpringSimulation(
      forward
          ? (toolbar ? spec.toolbarOpenSpring : spec.openSpring)
          : (toolbar ? spec.toolbarCloseSpring : spec.closeSpring),
      controller!.value,
      forward ? 1 : 0,
      velocity,
      snapToEnd: true,
    );
  }

  /// Applied by the route below (Material and Cupertino routes accept it): it
  /// recedes to [ZoomTransitionSpec.backgroundScale] while this route is open.
  /// Instance-bound so a zoom route under another zoom route still receives it.
  /// Null unless [ZoomTransitionSpec.recedeRouteBelow], so the route below
  /// stays still.
  @override
  DelegatedTransitionBuilder? get delegatedTransition => spec.recedeRouteBelow ? _recedeRouteBelow : null;

  Widget? _recedeRouteBelow(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    bool allowSnapshotting,
    Widget? child,
  ) {
    // Natively the area uncovered by the shrinking page shows the page's own
    // background colour, not black.
    final fill = spec.backgroundFillColor ?? Theme.of(context).scaffoldBackgroundColor;
    return ColoredBox(
      color: fill,
      child: AnimatedBuilder(
        animation: secondaryAnimation,
        builder: (context, child) {
          final t = secondaryAnimation.value.clamp(0.0, 1.0);
          // Rounded like the display while it is shrunk, so a coloured app
          // bar's square corners don't poke out past the screen's shape. The
          // tree stays the same at rest (only the clip is switched off) so the
          // route below is never remounted.
          return Transform.scale(
            scale: 1 - (1 - ZoomNative.backgroundScale) * t,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(screenCornerRadius),
              clipBehavior: t == 0 ? Clip.none : Clip.antiAlias,
              child: child,
            ),
          );
        },
        child: child,
      ),
    );
  }

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) {
    return _ZoomPresenter(route: this, child: builder(context));
  }

  /// Whether this page animates out when [nextRoute] is pushed on top. As with
  /// Flutter's Material and Cupertino routes: only for a regular (non
  /// fullscreen-dialog) page route using one of their transitions, which gets
  /// the usual iOS parallax, or when [nextRoute] brings a delegated transition
  /// (another zoom page with `recedeRouteBelow`). Another zoom page otherwise
  /// leaves this one where it is, as natively, instead of sliding it left.
  @override
  bool canTransitionTo(TransitionRoute<dynamic> nextRoute) {
    if (nextRoute is ModalRoute && nextRoute.delegatedTransition != null) return true;
    if (nextRoute is! PageRoute || nextRoute.fullscreenDialog) return false;
    return nextRoute is CupertinoRouteTransitionMixin || nextRoute is MaterialRouteTransitionMixin;
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // Only reacts to a page pushed on top (the usual iOS parallax); this
    // route's own entrance is drawn by _ZoomPresenter.
    return CupertinoPageTransition(
      primaryRouteAnimation: kAlwaysCompleteAnimation,
      secondaryRouteAnimation: secondaryAnimation,
      linearTransition: false,
      child: child,
    );
  }

  @override
  void dispose() {
    _dismissProgress.dispose();
    super.dispose();
  }
}

/// Rebuilds [builder] with the enclosing [ZoomPageRoute]'s drag-to-dismiss
/// progress (0 outside such a route), e.g. to fade a back button while dragging.
class ZoomDismissBuilder extends StatelessWidget {
  const ZoomDismissBuilder({super.key, required this.builder, this.child});

  final Widget Function(BuildContext context, double progress, Widget? child) builder;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final progress = ZoomPageRoute.maybeOf(context)?.dismissProgress;
    if (progress == null) return builder(context, 0, child);
    return ValueListenableBuilder<double>(
      valueListenable: progress,
      builder: (context, value, child) => builder(context, value, child),
      child: child,
    );
  }
}

enum _DragAxis { vertical, edge, predictiveBack }

class _ZoomPresenter extends StatefulWidget {
  const _ZoomPresenter({required this.route, required this.child});

  final ZoomPageRoute<dynamic> route;
  final Widget child;

  @override
  State<_ZoomPresenter> createState() => _ZoomPresenterState();
}

class _ZoomPresenterState extends State<_ZoomPresenter> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  ZoomPageRoute<dynamic> get _route => widget.route;
  ZoomTransitionSpec get _spec => _route.spec;

  _DragAxis? _dragAxis;
  Offset _drag = Offset.zero;

  /// Where the finger was when the drag started; the page scales about it.
  Offset? _dragAnchor;

  /// The frame on screen when a drag ended in a dismiss; the pop settles from
  /// it into the source so there is no jump at release.
  ZoomFrame? _releaseFrame;

  /// Springs a cancelled drag back to full screen (1 → 0 scales [_drag]).
  late final AnimationController _cancelController = AnimationController.unbounded(vsync: this, value: 0);

  bool _contentAtTop = true;
  Size _screen = Size.zero;

  @override
  void initState() {
    super.initState();
    _route._source?.hide();
    _route.animation?.addStatusListener(_onAnimationStatus);
    _route.animation?.addListener(_onAnimationTick);
    WidgetsBinding.instance.addObserver(this);
  }

  /// 1 → 0 over the last stretch before [ZoomNative.toolbarRevealProgress], so
  /// the page and glass are gone (no miniature of the page) by the time the
  /// button comes back.
  static double _toolbarGone(double progress) =>
      ((progress - ZoomNative.toolbarRevealProgress) / ZoomNative.toolbarVanishLength).clamp(0.0, 1.0);

  /// A toolbar source has no copy drawn over the closing page, so waiting for
  /// the spring to settle leaves a gap with neither page nor button (≈0.4 s).
  /// Natively the button is back ≈120 ms after the page fades out.
  void _onAnimationTick() {
    final animation = _route.animation;
    final source = _route._source;
    if (animation == null || source == null || !source.isToolbarItem) return;
    if (animation.status == AnimationStatus.reverse && animation.value <= ZoomNative.toolbarRevealProgress) {
      source.reveal();
    }
  }

  /// Shows the source again on the frame the page reaches it, the same frame
  /// the route is removed. Waiting for [dispose] instead has to defer the
  /// source's setState to the next frame, and that one frame with neither the
  /// page's copy nor the source on screen is a visible blink.
  void _onAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.dismissed) _route._source?.show();
  }

  @override
  void dispose() {
    _route.animation?.removeStatusListener(_onAnimationStatus);
    _route.animation?.removeListener(_onAnimationTick);
    WidgetsBinding.instance.removeObserver(this);
    _route._source?.show();
    _cancelController.dispose();
    super.dispose();
  }

  bool get _canStartDismiss =>
      _route.isCurrent &&
      _route.popGestureEnabled &&
      !_route.popGestureInProgress &&
      _dragAxis == null &&
      !_cancelController.isAnimating;

  Offset get _effectiveDrag => _drag * (_cancelController.isAnimating ? _cancelController.value : 1);

  // Android predictive back (the system back gesture): the events it started
  // with and is at, for the swipe edge and the finger's position.
  PredictiveBackEvent? _backStart;
  PredictiveBackEvent? _backNow;

  /// Where the back gesture's finger went down and is now, in logical pixels;
  /// while a cancelled gesture springs back, the travel shrinks to zero.
  (Offset, Offset) get _backTouch {
    final ratio = View.of(context).devicePixelRatio;
    final edgeX = _backStart?.swipeEdge == SwipeEdge.right ? _screen.width : 0.0;
    final start = (_backStart?.touchOffset ?? Offset(edgeX * ratio, _screen.height / 2 * ratio)) / ratio;
    final raw = (_backNow?.touchOffset ?? _backStart?.touchOffset ?? start * ratio) / ratio;
    final factor = _cancelController.isAnimating ? _cancelController.value : 1.0;
    return (start, start + (raw - start) * factor);
  }

  @override
  bool handleStartBackGesture(PredictiveBackEvent backEvent) {
    if (backEvent.isButtonEvent || !_canStartDismiss) return false;
    setState(() {
      _dragAxis = _DragAxis.predictiveBack;
      _backStart = _backNow = backEvent;
    });
    _route.navigator?.didStartUserGesture();
    return true;
  }

  @override
  void handleUpdateBackGestureProgress(PredictiveBackEvent backEvent) {
    if (_dragAxis != _DragAxis.predictiveBack) return;
    setState(() {
      _backNow = backEvent;
    });
    _route._dismissProgress.value = _dragFraction;
  }

  @override
  void handleCommitBackGesture() {
    if (_dragAxis != _DragAxis.predictiveBack) return;
    _route.navigator?.didStopUserGesture();
    if (!_route.isCurrent) return;
    // Zoom back into the source from where the gesture left the page.
    final release = _frame(_geometryFor(_screen), 1);
    setState(() {
      _releaseFrame = release;
      _dragAxis = null;
    });
    _route._dismissProgress.value = 0;
    _route.navigator?.pop();
  }

  @override
  void handleCancelBackGesture() {
    if (_dragAxis != _DragAxis.predictiveBack) return;
    _route.navigator?.didStopUserGesture();
    _springBack();
  }

  double get _dragFraction {
    if (_screen.isEmpty) return 0;
    final drag = _effectiveDrag;
    return switch (_dragAxis) {
      _DragAxis.vertical => (drag.dy / _screen.height).clamp(0.0, 1.0),
      _DragAxis.edge => (drag.dx / _screen.width).clamp(0.0, 1.0),
      _DragAxis.predictiveBack => ((_backTouch.$2.dx - _backTouch.$1.dx).abs() / _screen.width).clamp(0.0, 1.0),
      null => 0.0,
    };
  }

  ZoomGeometry _geometryFor(Size screen) => ZoomGeometry(
    spec: _spec,
    screen: screen,
    source: _sourceRect(screen),
    sourceRadius: _route._source?.borderRadius.topLeft.x ?? _route.screenCornerRadius * ZoomNative.sourcelessWidth,
    screenRadius: _route.screenCornerRadius,
  );

  Rect _sourceRect(Size screen) {
    final source = _route._source;
    if (source == null) {
      // No source (deep link, a push from code): natively the page grows out
      // of a small centred rect (and fades, see pageOpacity).
      final width = screen.width * ZoomNative.sourcelessWidth;
      return Rect.fromCenter(
        center: screen.center(Offset.zero),
        width: width,
        height: width * ZoomNative.sourcelessAspect,
      );
    }
    final navigatorBox = _route.navigator?.context.findRenderObject();
    final navigatorOffset = navigatorBox is RenderBox && navigatorBox.hasSize
        ? navigatorBox.localToGlobal(Offset.zero)
        : Offset.zero;
    return source.globalRect.shift(-navigatorOffset);
  }

  ZoomFrame _frame(ZoomGeometry geometry, double progress) {
    switch (_dragAxis) {
      case _DragAxis.vertical:
        return geometry.verticalDrag(_effectiveDrag, anchor: _dragAnchor);
      case _DragAxis.edge:
        return geometry.edgeDrag(_effectiveDrag, anchor: _dragAnchor);
      case _DragAxis.predictiveBack:
        // Same motion as the iOS edge swipe, driven by the system gesture's
        // finger position (Android reports it in physical pixels).
        final (start, now) = _backTouch;
        return geometry.systemBack(start, now, fromLeft: _backStart?.swipeEdge != SwipeEdge.right);
      case null:
        final release = _releaseFrame;
        return release != null ? geometry.settleFrom(release, progress) : geometry.transition(progress);
    }
  }

  // ---------------------------------------------------------------------------
  // Dismiss gestures

  void _onDragStart(_DragAxis axis, DragStartDetails details) {
    _dragAxis = axis;
    _drag = Offset.zero;
    _dragAnchor = details.localPosition;
    _route.navigator?.didStartUserGesture();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    setState(() => _drag += details.delta);
    _route._dismissProgress.value = _dragFraction;
  }

  void _onDragEnd(DragEndDetails details) {
    final axis = _dragAxis;
    // A system back gesture ends through handleCommit/CancelBackGesture; the
    // pointer the system took over only cancels here.
    if (axis == null || axis == _DragAxis.predictiveBack) return;
    final velocity = details.velocity.pixelsPerSecond;
    final fraction = _dragFraction;
    final along = axis == _DragAxis.vertical ? velocity.dy : velocity.dx;
    final threshold = axis == _DragAxis.vertical ? _spec.verticalDismissFraction : _spec.edgeDismissFraction;
    final shouldDismiss = along > _spec.dismissVelocity || (fraction > threshold && along >= 0);
    _route.navigator?.didStopUserGesture();

    if (shouldDismiss && _route.isCurrent) {
      final release = _frame(_geometryFor(_screen), 1);
      setState(() {
        _releaseFrame = release;
        _dragAxis = null;
        _drag = Offset.zero;
      });
      _route._dismissProgress.value = 0;
      // Hand the fling to the close spring (progress units/s; negative = closing).
      final extent = axis == _DragAxis.vertical ? _screen.height : _screen.width;
      _route._releaseVelocity = extent == 0 ? 0 : -(along / extent).clamp(0.0, 4.0);
      _route.navigator?.pop();
      return;
    }

    _springBack();
  }

  /// Springs a cancelled drag or back gesture back to full screen.
  void _springBack() {
    _cancelController.value = 1;
    _cancelController.addListener(_onCancelTick);
    _cancelController.animateWith(SpringSimulation(_spec.closeSpring, 1, 0, 0, snapToEnd: true)).whenCompleteOrCancel(() {
      _cancelController.removeListener(_onCancelTick);
      _route._dismissProgress.value = 0;
      if (!mounted) return;
      setState(() {
        _dragAxis = null;
        _drag = Offset.zero;
        _backStart = _backNow = null;
      });
    });
  }

  void _onCancelTick() => _route._dismissProgress.value = _dragFraction;

  void _onDragCancel() {
    if (_dragAxis == null || _dragAxis == _DragAxis.predictiveBack) return;
    _onDragEnd(DragEndDetails());
  }

  bool _onScroll(Notification notification) {
    final ScrollMetrics? metrics = switch (notification) {
      ScrollNotification(:final metrics) when notification.depth == 0 => metrics,
      ScrollMetricsNotification(:final metrics) when notification.depth == 0 => metrics,
      _ => null,
    };
    if (metrics != null && metrics.axis == Axis.vertical) {
      _contentAtTop = metrics.pixels <= metrics.minScrollExtent + 0.5;
    }
    return false;
  }

  // ---------------------------------------------------------------------------
  // Build

  @override
  Widget build(BuildContext context) {
    final animation = _route.animation!;
    final origin = _route._source?.buildOrigin(_route.navigator!.context);

    return LayoutBuilder(
      builder: (context, constraints) {
        _screen = constraints.biggest;
        return AnimatedBuilder(
          animation: Listenable.merge([animation, _cancelController]),
          builder: (context, page) {
            final screen = _screen;
            final frame = _frame(_geometryFor(screen), animation.value);
            final rect = frame.rect;
            final scale = screen.width == 0 ? 1.0 : rect.width / screen.width;
            final pageClip = Rect.fromLTWH(0, 0, screen.width, scale == 0 ? screen.height : rect.height / scale);
            final originSize = _route._source?.globalRect.size ?? Size.zero;
            final settled = animation.isCompleted && _dragAxis == null && _releaseFrame == null;
            // Natively a toolbar item is not blown up into the page (a 24 pt
            // icon scaled to cover the page is a huge blurry glyph): its copy
            // is not drawn and the page itself fades in as it grows instead.
            final toolbar = _route._source?.isToolbarItem ?? false;
            final progress = animation.value.clamp(0.0, 1.0);
            final closing = animation.status == AnimationStatus.reverse || _releaseFrame != null;
            // With no source (a push from code) the page grows out of a small
            // centred rect and fades, as natively.
            final sourceless = _route._source == null;
            final double pageOpacity;
            if (settled || _dragAxis != null) {
              pageOpacity = 1.0;
            } else if (!toolbar && !sourceless) {
              // Content source: opaque while opening; closing, natively the page
              // fades part-way under the returning source copy.
              pageOpacity = closing
                  ? (ZoomNative.contentCloseEndOpacity +
                            (1 - ZoomNative.contentCloseEndOpacity) * math.pow(progress, ZoomNative.contentCloseFadePower)) *
                        (progress / ZoomNative.contentCloseFadeOutEnd).clamp(0.0, 1.0)
                  : 1.0;
            } else if (sourceless) {
              pageOpacity = closing
                  ? math.pow(progress, ZoomNative.sourcelessFadeOutPower).toDouble()
                  : (ZoomNative.sourcelessStartOpacity +
                            (1 - ZoomNative.sourcelessStartOpacity) * progress / ZoomNative.sourcelessFadeInEnd)
                        .clamp(0.0, 1.0);
            } else {
              pageOpacity = closing
                  ? math.pow(progress, ZoomNative.toolbarFadeOutPower).toDouble() * _toolbarGone(progress)
                  : (progress / ZoomNative.toolbarFadeInEnd).clamp(0.0, 1.0);
            }

            // Same widget shape every frame: adding or removing Opacity/clip
            // layers mid-transition makes the page blink.
            return Stack(
              fit: StackFit.expand,
              children: [
                // Dim over the route below.
                IgnorePointer(child: ColoredBox(color: Color.fromRGBO(0, 0, 0, settled ? 0 : frame.dim))),
                // Soft shadow around the moving page (none once it is settled full screen).
                Positioned.fromRect(
                  rect: rect,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(frame.radius),
                        boxShadow: [
                          BoxShadow(
                            // Faded with a toolbar page: the blurred shadow also lies
                            // under the page and would show through it as a dark blob.
                            color: Color.fromRGBO(0, 0, 0, settled ? 0 : ZoomNative.shadowOpacity * pageOpacity),
                            blurRadius: ZoomNative.shadowBlur,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Toolbar sources: the button's glass, grown into the page's shape,
                // under the fading page.
                Positioned.fromRect(
                  rect: rect,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(frame.radius),
                        // Under the page, so what shows of it is glass · (1 − page
                        // alpha). Natively it holds while opening and fades with
                        // the page's size while closing (≈ progress).
                        color: _spec.toolbarGlassColor.withValues(
                          alpha: !toolbar || settled || _dragAxis != null
                              ? 0
                              : closing
                              ? math.min(ZoomNative.toolbarGlassOpacity, progress) * _toolbarGone(progress)
                              : ZoomNative.toolbarGlassOpacity,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  top: 0,
                  width: screen.width,
                  height: screen.height,
                  child: Transform(
                    transform: Matrix4.translationValues(rect.left, rect.top, 0)..scaleByDouble(scale, scale, 1, 1),
                    child: Opacity(
                      opacity: pageOpacity,
                      child: ClipRRect(
                        clipper: _RRectClipper(pageClip, settled || scale == 0 ? 0 : frame.radius / scale),
                        clipBehavior: Clip.antiAlias,
                        child: page,
                      ),
                    ),
                  ),
                ),
                // The source's copy fades over the (always opaque) page: the same
                // blend as the native page fading in over the source.
                Positioned.fromRect(
                  rect: rect,
                  child: IgnorePointer(
                    child: Opacity(
                      opacity: origin == null || settled || toolbar
                          ? 0
                          // Natively the source reappears early while closing:
                          // ≈60% at 64% of the way, opaque from 40% down.
                          : closing && _dragAxis == null
                          ? ((1 - progress) / ZoomNative.closeCrossfadeLength).clamp(0.0, 1.0)
                          : frame.originOpacity,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(frame.radius),
                        // Laid out at the source's own size (a bare FittedBox would give
                        // it unbounded constraints), then scaled to the flying rect.
                        child: origin == null
                            ? const SizedBox.shrink()
                            : FittedBox(
                                // Width-fitted and pinned to the top, as natively: the
                                // source keeps its proportions at the top of the page
                                // (cover would blow a card's text up and crop it).
                                fit: BoxFit.fitWidth,
                                alignment: Alignment.topCenter,
                                child: SizedBox.fromSize(size: originSize, child: origin),
                              ),
                      ),
                    ),
                  ),
                ),
                RawGestureDetector(
                  behavior: HitTestBehavior.translucent,
                  gestures: {
                    _DismissDragRecognizer: GestureRecognizerFactoryWithHandlers<_DismissDragRecognizer>(
                      () => _DismissDragRecognizer(axis: Axis.vertical, debugOwner: this),
                      (recognizer) => recognizer
                        ..gestureSettings = MediaQuery.maybeGestureSettingsOf(context)
                        ..canStart = ((position) => _canStartDismiss && _contentAtTop)
                        ..onStart = ((details) => _onDragStart(_DragAxis.vertical, details))
                        ..onUpdate = _onDragUpdate
                        ..onEnd = _onDragEnd
                        ..onCancel = _onDragCancel,
                    ),
                    _EdgeDismissDragRecognizer: GestureRecognizerFactoryWithHandlers<_EdgeDismissDragRecognizer>(
                      () => _EdgeDismissDragRecognizer(debugOwner: this),
                      (recognizer) => recognizer
                        ..gestureSettings = MediaQuery.maybeGestureSettingsOf(context)
                        ..canStart = ((position) {
                          final box = context.findRenderObject();
                          final local = box is RenderBox ? box.globalToLocal(position) : position;
                          // On Android that edge belongs to the system back
                          // gesture (handled as predictive back instead).
                          return _canStartDismiss &&
                              local.dx <= _spec.edgeWidth &&
                              defaultTargetPlatform != TargetPlatform.android;
                        })
                        ..onStart = ((details) => _onDragStart(_DragAxis.edge, details))
                        ..onUpdate = _onDragUpdate
                        ..onEnd = _onDragEnd
                        ..onCancel = _onDragCancel,
                    ),
                  },
                  child: const SizedBox.expand(),
                ),
              ],
            );
          },
          child: NotificationListener<Notification>(onNotification: _onScroll, child: widget.child),
        );
      },
    );
  }
}

class _RRectClipper extends CustomClipper<RRect> {
  _RRectClipper(this.rect, this.radius);

  final Rect rect;
  final double radius;

  @override
  RRect getClip(Size size) => RRect.fromRectAndRadius(rect, Radius.circular(radius));

  @override
  bool shouldReclip(_RRectClipper oldClipper) => oldClipper.rect != rect || oldClipper.radius != radius;
}

/// Accepts only a drag in the dismiss direction (down for [Axis.vertical],
/// right for [Axis.horizontal]) and only when [canStart] allows it; otherwise it
/// simply loses the arena to the page's own scrollables instead of rejecting early.
/// (Extends PanGestureRecognizer because DragGestureRecognizer's delta hooks are
/// library-private.)
class _DismissDragRecognizer extends PanGestureRecognizer {
  _DismissDragRecognizer({required this.axis, super.debugOwner});

  final Axis axis;
  bool Function(Offset globalPosition) canStart = (_) => false;

  Offset? _downPosition;
  Offset? _lastPosition;

  @override
  bool isPointerAllowed(PointerEvent event) => canStart(event.position) && super.isPointerAllowed(event);

  @override
  void addAllowedPointer(PointerDownEvent event) {
    _downPosition = event.position;
    _lastPosition = event.position;
    super.addAllowedPointer(event);
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerMoveEvent) _lastPosition = event.position;
    super.handleEvent(event);
  }

  @override
  bool hasSufficientGlobalDistanceToAccept(PointerDeviceKind pointerDeviceKind, double? deviceTouchSlop) {
    final delta = (_lastPosition ?? Offset.zero) - (_downPosition ?? Offset.zero);
    final along = axis == Axis.vertical ? delta.dy : delta.dx;
    final across = axis == Axis.vertical ? delta.dx : delta.dy;
    // Half the scrollables' slop (same device gesture settings as theirs), so a
    // drag in the dismiss direction wins over a list at its edge even when it
    // is slow, as natively; a fast drag crosses both thresholds in one event.
    return along > across.abs() && along > computeHitSlop(pointerDeviceKind, gestureSettings) / 2;
  }

  @override
  String get debugDescription => 'zoom dismiss drag';
}

/// The left-edge swipe: a separate type so both recognizers can live in one
/// RawGestureDetector.
class _EdgeDismissDragRecognizer extends _DismissDragRecognizer {
  _EdgeDismissDragRecognizer({super.debugOwner}) : super(axis: Axis.horizontal);
}

