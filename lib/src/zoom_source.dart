import 'dart:ui' show ImageFilter;

import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Marks [child] as the widget a [ZoomPageRoute] with the same [tag] zooms out
/// of (and back into when popped).
///
/// Tags may repeat (the same product in two carousels, a copy in a hidden
/// tab). A route then zooms from, in order: the source passed as its
/// `sourceContext`; the source the finger just went down on; the only copy on
/// screen (or, with none on screen, the only painted one). When that is still
/// ambiguous (several copies and no tap to tell them apart) it zooms in without
/// a source instead of guessing. Sources that are not painted (a hidden
/// [IndexedStack] child, [Offstage], zero opacity) are never used. Tags are compared with `==` across the whole app, so use typed values
/// such as `('order', id)` when ids of different kinds could collide.
///
/// Unlike a heroine, the source never builds the destination page: the route
/// builds its page exactly once, and only a live copy of this (small) source
/// widget is drawn during the transition.
class ZoomSource extends StatefulWidget {
  const ZoomSource({
    super.key,
    required this.tag,
    required this.child,
    this.enabled = true,
    this.borderRadius = BorderRadius.zero,
    this.toolbar = false,
  });

  final Object? tag;
  final Widget child;

  /// When false the widget is not registered, so routes with this tag fall
  /// back to the sourceless transition.
  final bool enabled;

  /// Corner radius the zoom starts from (and ends at when popping).
  final BorderRadius borderRadius;

  /// Whether this is a toolbar / app-bar item. iOS zooms out of toolbar items
  /// with a quicker spring ([ZoomTransitionSpec.toolbarOpenSpring]).
  final bool toolbar;

  static final Map<Object, List<_ZoomSourceState>> _registry = {};

  /// Pointer-downs seen app-wide, so a source can tell whether the latest one
  /// landed on it (see [_ZoomSourceState._downStamp]).
  static int _pointerDowns = 0;
  static bool _trackingPointers = false;

  static void _trackPointers() {
    if (_trackingPointers) return;
    _trackingPointers = true;
    // Global routes run after the hit-tested Listeners for the same event.
    GestureBinding.instance.pointerRouter.addGlobalRoute((event) {
      if (event is PointerDownEvent) _pointerDowns++;
    });
  }

  static final Set<Object> _warnedTags = {};

  /// The source to zoom from for [tag], among the mounted sources whose route
  /// is the current one. Call it while the pushing route is still current (e.g.
  /// from the route's constructor). [context], when given, is a context at or
  /// below the wanted [ZoomSource] and wins over every other match.
  static ZoomSourceHandle? find(Object? tag, {BuildContext? context}) {
    if (context != null) {
      final explicit = context is StatefulElement && context.state is _ZoomSourceState
          ? context.state as _ZoomSourceState
          : context.findAncestorStateOfType<_ZoomSourceState>();
      if (explicit != null && explicit.widget.tag == tag && explicit._canBeOrigin) return explicit;
    }
    final sources = _registry[tag];
    if (sources == null) return null;
    final painted = [
      for (final source in sources.reversed)
        if (source._canBeOrigin && source._isPainted) source,
    ];
    if (painted.isEmpty) return null;
    for (final source in painted) {
      if (source._downStamp == _pointerDowns && source._downStamp > 0) return source;
    }
    // No tap to go by: only an unambiguous copy is used. Several copies of the
    // tag on screen (or several off screen and none on it) could each be the
    // one meant, so the page zooms in without a source rather than from a
    // guessed one.
    final onScreen = [
      for (final source in painted)
        if (source._isOnScreen) source,
    ];
    final candidates = onScreen.isNotEmpty ? onScreen : painted;
    if (candidates.length == 1) return candidates.single;
    assert(() {
      if (_warnedTags.add(tag!)) {
        debugPrint(
          'ZoomSource: ${candidates.length} sources share the tag $tag and none was just tapped; '
          'zooming without a source. Pass `sourceContext` to ZoomPageRoute, or give each source a distinct tag.',
        );
      }
      return true;
    }());
    return null;
  }

  @override
  State<ZoomSource> createState() => _ZoomSourceState();
}

/// Whether [box] and every render box above it have been laid out, so that
/// localToGlobal can walk their transforms. An ancestor being laid out again
/// as a new render object (the tree rebuilt by a rotation or a hot reload) has
/// no size yet. Internal to the package (not exported).
bool zoomLaidOutUpToRoot(RenderBox box) {
  if (!box.attached) return false;
  for (RenderObject? node = box; node != null; node = node.parent) {
    if (node is RenderBox && !node.hasSize) return false;
  }
  return true;
}

/// A live source with [old]'s tag to take over from [old] once it is no longer
/// in the tree (its list item or tab was rebuilt as a new widget while the
/// page was open), so the close still zooms into the right place. Unlike
/// [ZoomSource.find] the source's route may be covered (by the zoom page).
ZoomSourceHandle? zoomSourceReplacement(Object tag, ZoomSourceHandle old) {
  final sources = ZoomSource._registry[tag];
  if (sources == null) return null;
  for (final source in sources.reversed) {
    if (!identical(source, old) && source.isAvailable && source._isPainted) return source;
  }
  return null;
}

/// What a [ZoomPageRoute] needs from its [ZoomSource].
abstract class ZoomSourceHandle {
  /// Whether the source is in the tree right now. It is not while its element
  /// is inactive (being moved or replaced during a frame) or once disposed;
  /// the other members then fall back to the last known values.
  bool get isAvailable;

  /// The source's current rect in global coordinates (the last known one once
  /// the source is not available).
  Rect get globalRect;

  BorderRadius get borderRadius;

  bool get isToolbarItem;

  /// Builds a copy of the source for the flight, carrying over the source's
  /// themes. [navigatorContext] must be an ancestor of the source.
  Widget buildOrigin(BuildContext navigatorContext);

  /// Hides the source (keeping its layout) while its route is on screen.
  void hide();

  void show();

  /// Shows the source the way a toolbar button comes back natively when the
  /// page closes into it: at once, but blurred, sharpening over ≈100 ms.
  void reveal();
}

class _ZoomSourceState extends State<ZoomSource> with SingleTickerProviderStateMixin implements ZoomSourceHandle {
  Object? _registeredTag;
  bool _hidden = false;
  bool _tickerEnabled = true;
  Rect _lastRect = Rect.zero;

  /// False while the element is inactive: mounted, but out of the tree for the
  /// rest of the frame (moved by a GlobalKey, or about to be disposed). Its
  /// render object and ancestors must not be looked up then.
  bool _active = true;
  Widget? _lastOrigin;

  @override
  bool get isAvailable => mounted && _active;

  @override
  void deactivate() {
    _active = false;
    super.deactivate();
  }

  @override
  void activate() {
    super.activate();
    _active = true;
  }

  /// 1 → 0 while a revealed source sharpens (see [reveal]).
  late final AnimationController _unblur = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 100),
    value: 0,
  );

  /// The value [ZoomSource._pointerDowns] reaches with the latest pointer-down
  /// that hit this source; equal to it while that is the latest one app-wide.
  int _downStamp = 0;

  /// Whether every ancestor actually paints this source, i.e. it is not in a
  /// hidden [IndexedStack] child, under [Offstage] or at zero opacity.
  bool get _isPainted {
    if (!isAvailable) return false;
    final box = context.findRenderObject();
    if (box == null) return false;
    RenderObject child = box;
    for (var parent = box.parent; parent != null; child = parent, parent = parent.parent) {
      if (!parent.paintsChild(child)) return false;
      if (parent is RenderIndexedStack && _indexOf(parent, child) != parent.index) return false;
    }
    return true;
  }

  static int _indexOf(RenderIndexedStack stack, RenderObject child) {
    var index = 0;
    for (var node = stack.firstChild; node != null; node = stack.childAfter(node), index++) {
      if (identical(node, child)) return index;
    }
    return -1;
  }

  /// Whether the source's rect overlaps the screen (a list item in the
  /// scrollable's cache area is built and painted but off screen).
  bool get _isOnScreen {
    final view = View.maybeOf(context);
    if (view == null) return true;
    final screen = Offset.zero & (view.physicalSize / view.devicePixelRatio);
    return globalRect.overlaps(screen);
  }

  bool get _canBeOrigin {
    if (!isAvailable || !_tickerEnabled) return false;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize || box.size.isEmpty) return false;
    return ModalRoute.of(context)?.isCurrent ?? true;
  }

  void _register() {
    final tag = widget.tag;
    if (!widget.enabled || tag == null) return;
    _registeredTag = tag;
    ZoomSource._registry.putIfAbsent(tag, () => []).add(this);
  }

  void _unregister() {
    final tag = _registeredTag;
    if (tag == null) return;
    final sources = ZoomSource._registry[tag];
    sources?.remove(this);
    if (sources != null && sources.isEmpty) ZoomSource._registry.remove(tag);
    _registeredTag = null;
  }

  @override
  void initState() {
    super.initState();
    ZoomSource._trackPointers();
    _register();
  }

  @override
  void didUpdateWidget(ZoomSource oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tag != widget.tag || oldWidget.enabled != widget.enabled) {
      _unregister();
      _register();
    }
  }

  @override
  void dispose() {
    _unblur.dispose();
    _unregister();
    super.dispose();
  }

  @override
  Rect get globalRect {
    final box = isAvailable ? context.findRenderObject() : null;
    if (box is RenderBox && zoomLaidOutUpToRoot(box)) {
      _lastRect = box.localToGlobal(Offset.zero) & box.size;
    }
    return _lastRect;
  }

  @override
  BorderRadius get borderRadius => widget.borderRadius;

  @override
  bool get isToolbarItem => widget.toolbar;

  @override
  Widget buildOrigin(BuildContext navigatorContext) {
    // Ancestors can't be looked up from an inactive element: reuse the last copy.
    if (!isAvailable) return _lastOrigin ?? ExcludeSemantics(child: IgnorePointer(child: widget.child));
    return _lastOrigin = InheritedTheme.capture(from: context, to: navigatorContext).wrap(
      // A visual copy only: no hits, and no duplicate semantics ids during the flight.
      ExcludeSemantics(child: IgnorePointer(child: widget.child)),
    );
  }

  @override
  void hide() => _setHidden(true);

  @override
  void show() => _setHidden(false);

  @override
  void reveal() {
    if (!mounted || !_hidden) return;
    _unblur.value = 1;
    _setHidden(false);
    _unblur.animateTo(0, curve: Curves.easeOut);
  }

  /// The state asked for during a frame, applied after it. The latest request
  /// wins: a hide then a show in the same frame leaves the source shown.
  bool? _pendingHidden;

  void _setHidden(bool hidden) {
    if (!mounted) return;
    // show() runs from the route's dispose, i.e. while the tree is being
    // finalized, where setState is not allowed; defer it to after the frame.
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      if (_pendingHidden == null) {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          final pending = _pendingHidden;
          _pendingHidden = null;
          if (pending != null) _setHidden(pending);
        });
      }
      _pendingHidden = hidden;
      return;
    }
    _pendingHidden = null;
    if (_hidden == hidden) return;
    setState(() => _hidden = hidden);
  }

  @override
  Widget build(BuildContext context) {
    _tickerEnabled = TickerMode.valuesOf(context).enabled;
    return Listener(
      // Runs before the global pointer route counts this pointer-down.
      onPointerDown: (_) => _downStamp = ZoomSource._pointerDowns + 1,
      child: Opacity(
        opacity: _hidden ? 0 : 1,
        // Always in the tree (only enabled while sharpening) so the child is
        // never remounted.
        child: AnimatedBuilder(
          animation: _unblur,
          builder: (context, child) {
            final sigma = 6 * _unblur.value;
            return ImageFiltered(
              enabled: sigma > 0,
              imageFilter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
              child: child,
            );
          },
          child: widget.child,
        ),
      ),
    );
  }
}
