import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Marks [child] as the widget a [ZoomPageRoute] with the same [tag] zooms out
/// of (and back into when popped).
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

  /// The source to zoom from for [tag]: a mounted, on-screen source whose route
  /// is the current one. Call it while the pushing route is still current (e.g.
  /// from the route's constructor).
  static ZoomSourceHandle? find(Object? tag) {
    final sources = _registry[tag];
    if (sources == null) return null;
    for (final source in sources.reversed) {
      if (source._canBeOrigin) return source;
    }
    return null;
  }

  @override
  State<ZoomSource> createState() => _ZoomSourceState();
}

/// What a [ZoomPageRoute] needs from its [ZoomSource].
abstract class ZoomSourceHandle {
  /// The source's current rect in global coordinates (the last known one once
  /// the source has been disposed).
  Rect get globalRect;

  BorderRadius get borderRadius;

  bool get isToolbarItem;

  /// Builds a copy of the source for the flight, carrying over the source's
  /// themes. [navigatorContext] must be an ancestor of the source.
  Widget buildOrigin(BuildContext navigatorContext);

  /// Hides the source (keeping its layout) while its route is on screen.
  void hide();

  void show();
}

class _ZoomSourceState extends State<ZoomSource> implements ZoomSourceHandle {
  Object? _registeredTag;
  bool _hidden = false;
  bool _tickerEnabled = true;
  Rect _lastRect = Rect.zero;

  bool get _canBeOrigin {
    if (!mounted || !_tickerEnabled) return false;
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
    _unregister();
    super.dispose();
  }

  @override
  Rect get globalRect {
    final box = mounted ? context.findRenderObject() : null;
    if (box is RenderBox && box.attached && _laidOutUpToRoot(box)) {
      _lastRect = box.localToGlobal(Offset.zero) & box.size;
    }
    return _lastRect;
  }

  /// localToGlobal walks every ancestor's transform, and an ancestor that is
  /// being laid out again (the route below rebuilding during a rotation or a
  /// hot reload) has no size yet; keep the last good rect for that frame.
  static bool _laidOutUpToRoot(RenderBox box) {
    for (RenderObject? node = box; node != null; node = node.parent) {
      if (node is RenderBox && !node.hasSize) return false;
    }
    return true;
  }

  @override
  BorderRadius get borderRadius => widget.borderRadius;

  @override
  bool get isToolbarItem => widget.toolbar;

  @override
  Widget buildOrigin(BuildContext navigatorContext) {
    return InheritedTheme.capture(from: context, to: navigatorContext).wrap(
      // A visual copy only: no hits, and no duplicate semantics ids during the flight.
      ExcludeSemantics(child: IgnorePointer(child: widget.child)),
    );
  }

  @override
  void hide() => _setHidden(true);

  @override
  void show() => _setHidden(false);

  void _setHidden(bool hidden) {
    if (!mounted || _hidden == hidden) return;
    // show() runs from the route's dispose, i.e. while the tree is being
    // finalized, where setState is not allowed; defer it to after the frame.
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) => _setHidden(hidden));
      return;
    }
    setState(() => _hidden = hidden);
  }

  @override
  Widget build(BuildContext context) {
    _tickerEnabled = TickerMode.valuesOf(context).enabled;
    return Opacity(opacity: _hidden ? 0 : 1, child: widget.child);
  }
}
