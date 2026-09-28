import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' show Theme;
import 'package:flutter/physics.dart';

import 'zoom_geometry.dart';
import 'zoom_source.dart';
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
    _source = ZoomSource.find(tag);
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
  ZoomSourceHandle? _source;

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
  @override
  DelegatedTransitionBuilder? get delegatedTransition => _recedeRouteBelow;

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
        builder: (context, child) => Transform.scale(
          scale: 1 - (1 - spec.backgroundScale) * secondaryAnimation.value.clamp(0.0, 1.0),
          child: child,
        ),
        child: child,
      ),
    );
  }

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) {
    return _ZoomPresenter(route: this, child: builder(context));
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

enum _DragAxis { vertical, edge }

class _ZoomPresenter extends StatefulWidget {
  const _ZoomPresenter({required this.route, required this.child});

  final ZoomPageRoute<dynamic> route;
  final Widget child;

  @override
  State<_ZoomPresenter> createState() => _ZoomPresenterState();
}

class _ZoomPresenterState extends State<_ZoomPresenter> with SingleTickerProviderStateMixin {
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

  double get _dragFraction {
    if (_screen.isEmpty) return 0;
    final drag = _effectiveDrag;
    return switch (_dragAxis) {
      _DragAxis.vertical => (drag.dy / _screen.height).clamp(0.0, 1.0),
      _DragAxis.edge => (drag.dx / _screen.width).clamp(0.0, 1.0),
      null => 0.0,
    };
  }

  ZoomGeometry _geometryFor(Size screen) => ZoomGeometry(
    spec: _spec,
    screen: screen,
    source: _sourceRect(screen),
    sourceRadius: _route._source?.borderRadius.topLeft.x ?? _route.screenCornerRadius,
    screenRadius: _route.screenCornerRadius,
  );

  Rect _sourceRect(Size screen) {
    final source = _route._source;
    if (source == null) {
      // No source (deep link, a push from code): grow from slightly smaller.
      return Rect.fromCenter(
        center: screen.center(Offset.zero),
        width: screen.width * 0.94,
        height: screen.height * 0.94,
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
    if (axis == null) return;
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

    _cancelController.value = 1;
    _cancelController.addListener(_onCancelTick);
    _cancelController.animateWith(SpringSimulation(_spec.closeSpring, 1, 0, 0, snapToEnd: true)).whenCompleteOrCancel(() {
      _cancelController.removeListener(_onCancelTick);
      _route._dismissProgress.value = 0;
      if (!mounted) return;
      setState(() {
        _dragAxis = null;
        _drag = Offset.zero;
      });
    });
  }

  void _onCancelTick() => _route._dismissProgress.value = _dragFraction;

  void _onDragCancel() {
    if (_dragAxis == null) return;
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
                            color: Color.fromRGBO(0, 0, 0, settled ? 0 : _spec.shadowOpacity),
                            blurRadius: _spec.shadowBlur,
                          ),
                        ],
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
                    child: ClipRRect(
                      clipper: _RRectClipper(pageClip, settled || scale == 0 ? 0 : frame.radius / scale),
                      clipBehavior: Clip.antiAlias,
                      child: page,
                    ),
                  ),
                ),
                // The source's copy fades over the (always opaque) page: the same
                // blend as the native page fading in over the source.
                Positioned.fromRect(
                  rect: rect,
                  child: IgnorePointer(
                    child: Opacity(
                      opacity: origin == null || settled ? 0 : frame.originOpacity,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(frame.radius),
                        // Laid out at the source's own size (a bare FittedBox would give
                        // it unbounded constraints), then scaled to the flying rect.
                        child: origin == null
                            ? const SizedBox.shrink()
                            : FittedBox(
                                fit: BoxFit.cover,
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
                        ..canStart = ((position) => _canStartDismiss && _contentAtTop)
                        ..onStart = ((details) => _onDragStart(_DragAxis.vertical, details))
                        ..onUpdate = _onDragUpdate
                        ..onEnd = _onDragEnd
                        ..onCancel = _onDragCancel,
                    ),
                    _EdgeDismissDragRecognizer: GestureRecognizerFactoryWithHandlers<_EdgeDismissDragRecognizer>(
                      () => _EdgeDismissDragRecognizer(debugOwner: this),
                      (recognizer) => recognizer
                        ..canStart = ((position) {
                          final box = context.findRenderObject();
                          final local = box is RenderBox ? box.globalToLocal(position) : position;
                          return _canStartDismiss && local.dx <= _spec.edgeWidth;
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
    return along > across.abs() && along > computeHitSlop(pointerDeviceKind, gestureSettings);
  }

  @override
  String get debugDescription => 'zoom dismiss drag';
}

/// The left-edge swipe: a separate type so both recognizers can live in one
/// RawGestureDetector.
class _EdgeDismissDragRecognizer extends _DismissDragRecognizer {
  _EdgeDismissDragRecognizer({super.debugOwner}) : super(axis: Axis.horizontal);
}
