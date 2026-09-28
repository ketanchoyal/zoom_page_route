# zoom_page_route

iOS-style **zoom navigation** for Flutter: a page grows out of the widget you
tapped (a card, an icon) and shrinks back into it, with drag-down and left-edge
swipe to dismiss. Its motion was measured from native SwiftUI
(`.navigationTransition(.zoom)`) and fitted, so it can sit next to the native
transition without looking different.

The destination page is **built once**. (A heroine-based zoom route rebuilt the
whole page inside its flight shuttle, so every push, pop and drag ran the page's
`initState`, and any API calls in it, twice.)

## Usage

```dart
import 'package:zoom_page_route/zoom_page_route.dart';

// Once at startup: the device's display corner radius (0 = square corners).
ZoomPageRoute.defaultScreenCornerRadius = () => myPlugin.screenCornerRadius;

// The widget to zoom out of:
ZoomSource(
  tag: order.id,
  borderRadius: BorderRadius.circular(6),
  child: OrderCard(order),
);

// Push:
Navigator.of(context).push(ZoomPageRoute(tag: order.id, builder: (_) => OrderScreen(order)));
```

Push with the same `tag` as a `ZoomSource` on the current route. With no
matching source (deep links, pushes from code) it does what SwiftUI does: the
page grows out of a small centred rect (35% of the width, 1 : 1.31) while
fading in from 35%, and on close shrinks back into it while fading out
completely.

- Tags may repeat (the same item in two lists, a copy in a hidden tab). The
  route zooms from, in order: the source given as `sourceContext` (any
  context at or below that `ZoomSource`); the source the finger just went
  down on; a source that is painted and on screen; a painted one off screen.
  Unpainted sources (hidden `IndexedStack` child, `Offstage`, zero opacity)
  are never used. In debug, two on-screen matches with no tap log a warning.
  Tags compare with `==` app-wide, so use typed tags like `('order', id)`
  when ids of different kinds could collide.
- Mark app-bar / toolbar sources with `ZoomSource(toolbar: true)`: iOS zooms
  out of toolbar items with a quicker spring than out of content, and it does
  not blow the icon up into the page: the button's white glass grows into the
  page's shape (≈72%) and the page fades in on top (opaque at 80% of the
  way; on close alpha ≈ progress^1.3 and the glass fades with it). Measured
  with a magenta page over a pure green background, so page, glass and
  background shares can be solved per pixel; Flutter matches native within
  ~0.03 at the same page size. Make the whole toolbar button the source (not
  just its glyph), as natively. When closing, the button is shown again as
  soon as the page is gone (≈100 ms, native ≈120 ms), not when the spring
  finally settles. A 36×36
  in-content source zooms at the normal pace, so size is not the cause.
- `ZoomDismissBuilder` rebuilds with the drag-to-dismiss progress (0–1), e.g.
  to fade a back button while the page is dragged.
- `ZoomTransitionSpec` (const) holds the choices an app makes: the four
  springs, `recedeRouteBelow`, `backgroundFillColor`, `toolbarGlassColor`,
  `edgeWidth` and the dismiss thresholds. Pass one as `spec:` to override.
  How iOS itself animates (drag geometry, fades, dim, shadow) is measured and
  fixed (see below), not configurable.
- Pages with a vertical list: drag-down dismiss only starts when the page's
  main vertical scrollable is at the top when the finger goes down. Otherwise
  the list scrolls, and reaching the top mid-gesture does not switch to a
  dismiss. Native SwiftUI behaves the same (checked side by side). Horizontal
  and nested scrollables don't block it, and the left-edge swipe always works.
  Drag-down dismiss wins over pull-to-refresh at the top of a page.
- The route below stays still by default. Pass
  `ZoomTransitionSpec(recedeRouteBelow: true)` to shrink it like iOS does.
  Natively only the content shrinks and the navigation bar stays put. This
  route can only shrink the whole screen below (rounded to the display
  corners), so turn it on only when your screens look right that way. The
  `example` app turns it on for the parity comparison.
- `maintainState` (default `true`) is exposed for apps that relied on the page
  being rebuilt when it is covered.

## iOS spring presets

`IOSSpring` gives SwiftUI's spring presets as `SpringDescription`s, usable
anywhere (`SpringSimulation`, `AnimationController.animateWith`, or
`ZoomTransitionSpec(openSpring: IOSSpring.snappy)`):

| Flutter | SwiftUI |
|---|---|
| `IOSSpring.smooth` / `IOSSpring.standard` | `.smooth` / `.spring` (0.5 s, bounce 0) |
| `IOSSpring.snappy` | `.snappy` (0.5 s, bounce 0.15) |
| `IOSSpring.bouncy` | `.bouncy` (0.5 s, bounce 0.3) |
| `IOSSpring.interactive` | `.interactiveSpring` (response 0.15 s, damping 0.86) |
| `IOSSpring.legacyDefault` | `.spring(response: 0.55, dampingFraction: 0.825)` |
| `IOSSpring.of(duration:bounce:)` | `Spring(duration:bounce:)` |
| `IOSSpring.withResponse(response:dampingRatio:)` | `Spring(response:dampingRatio:)`, `UISpringTimingParameters` |
| `IOSSpring.smoothWith/snappyWith/bouncyWith(duration:extraBounce:)` | `.smooth/.snappy/.bouncy(duration:extraBounce:)` |

This is Apple's conversion: mass 1, stiffness (2π/duration)², damping
4π·ζ/duration, with ζ = 1 − bounce (or 1/(1 + bounce) when bounce < 0).
Checked against SwiftUI by logging every animated value per frame
(`native_reference` → SPRINGS): each preset stays within 1.8–3.6 pt of the
native curve over a 300 pt move. The `example` app's SPRINGS screen runs the
same presets for a side-by-side look.

## Measured spec

Measured from screen recordings of the native reference app (iOS 27 simulator,
402×874 pt): a solid cyan source opens a solid magenta page, so the page's
on-screen rect, corner radius and the background dim can be tracked frame by
frame (`native_reference/`, see below).

| | Native measurement | Flutter (fixed unless noted) |
|---|---|---|
| Open spring | ζ ≈ 0.975–0.98, response ≈ 0.37–0.38 s (2 runs, RMS < 0.004) | mass 1, stiffness 281, damping 32.8 |
| Close spring | ζ ≈ 0.98, response ≈ 0.33 s (6 usable frames) | mass 1, stiffness 365, damping 37.5 |
| Toolbar source (e.g. cart button) | clearly quicker, slightly bouncier: response ≈ 0.25–0.33 s, ζ ≈ 0.83–0.92 (the iOS 26 glass-button morph blends into the start; varies more between runs) | `ZoomSource(toolbar: true)` → `toolbarOpenSpring` (0.28 s, ζ 0.87), `toolbarCloseSpring` (0.24 s, ζ 0.9) |
| Background dim | black α ≈ 0.33 × progress | `maxDim` 0.33 |
| Previous page | content shrinks about the screen centre to ≈0.915 as the page opens, holds it while dragging, grows back on close; uncovered area shows the page background. Natively the navigation bar stays full size, so no corners show | off by default (`recedeRouteBelow`); when on, the whole route shrinks (`backgroundScale` 0.915, via `delegatedTransition`), clipped to the display corner radius so a coloured app bar's corners stay inside the screen shape; `backgroundFillColor` (theme scaffold background) |
| Page shadow | soft and centred: ~15% darker 6 pt out, ~8% at 20 pt | `shadowOpacity` 0.18, `shadowBlur` 40 |
| Source ↔ page cross-fade | opening: source hidden by ~45% progress; closing: source back early (≈60% at 64% of the way, opaque from 40%) while the page fades to ≈60%; the source keeps its proportions, width-fitted at the top of the page | `crossfadeEnd` 0.45, `closeCrossfadeLength` 0.6, `contentCloseEndOpacity` 0.6 |
| Long drag down | rubber-bands: page top stops near 0.65 of the screen (card, not a sliver) | `verticalDragRubberBand` 0.7 |
| Page shape | width, centre and aspect ratio (h/w) lerp with progress, so the height lags: 45% of the way at 57% width (iPhone), 38% at 50% (iPad) | same (`ZoomGeometry`) |
| Corner radius (open) | source radius → screen radius with progress | lerp(source, screen, progress) |
| Drag down | the page scales uniformly about the point the finger grabbed, which stays under the finger: scale = (1 − 0.662·dy/height)·b; the bottom edge stays on the screen bottom in landscape and rises to b·height in portrait, b = 1 − 0.453·u³ (u = page top / height); radius ∝ width. Same numbers on iPhone and iPad | `verticalDragScaleSlope` 0.662, `portraitDragLift` 0.453 |
| Drag dim | 0.33 − 0.49u, floor 0.15 | `verticalDragDimSlope` 0.49, `minDragDim` 0.15 |
| Left-edge swipe (u = dx / width) | uniform scale 1 − 0.65u about the point the finger grabbed (a swipe started at 80% height stays anchored there) | `edgeDragScaleSlope` 0.65 |
| Edge dim | ≈ 0.33 − 1.0u, floor 0.15 | `edgeDragDimSlope` 1.0 |

`test/zoom_geometry_test.dart` pins these defaults to the native samples (the
open spring stays within ±0.02 of the native curve at every sample).

Previous-page scale over the first 117 ms of an open (native / Flutter):
0.989/0.990, 0.978/0.983, 0.967/0.975, 0.959/0.965, 0.951/0.955, 0.944/0.952,
0.937/0.943; during a drag 0.914–0.916 / 0.916–0.918.

The Flutter example, measured with the same script, gives an open spring of
ζ 0.965–0.988 and response 0.367–0.386 s, and drag slopes of −0.625 (width)
and −1.135 (height), against native's −0.614 and −1.118.

iPad (iPad Pro 11", 834×1210 pt, display radius 30 pt) behaves the same as
iPhone: the same springs, drag rule, edge scale, dim, and corners that follow
the display radius. The
example reads the display radius natively, so it is right on either device.
Time from 65% to 90% width progress: native 88–91 ms, Flutter 94–96 ms.
Landscape iPad (1210×834) matches too. The drag rule was fitted to nine
native slow drags (iPhone, iPad portrait, iPad landscape; fingers starting at
15%, 45% and 20%/30%), and the example reproduces all of them within 1% of
the screen size.

## Parity check: native vs Flutter

Two apps with the same screens, meant to run side by side:

| | Path | Run |
|---|---|---|
| Native reference (SwiftUI) | `native_reference/` | `cd native_reference && xcodegen generate`, then open `ZoomNavDemo.xcodeproj` (or `xcodebuild … -destination 'platform=iOS Simulator,…'`) |
| Flutter parity app | `example/` | `cd example && fvm flutter run -d <simulator>` |

Launch the native app with `-measure`, and run the example with
`--dart-define=MEASURE=true`, to paint the Cart page magenta so the cart
(toolbar) zoom can be tracked too.

Both have a **MEASURE** card (cyan, 150×100) that opens a solid **magenta**
page with a Close button, plus menu category cards, order cards and a cart
icon. Each detail screen shows `load ran N×`; it goes up by exactly one per push.
Record both simulators (`xcrun simctl io <udid> recordVideo`), extract frames
with their timestamps (`ffmpeg -fps_mode passthrough`), and track the magenta
bounding box per frame to compare the curves.

Bundle IDs use the Recipe account: `com.cara.zoomnavdemo` and
`com.cara.zoomPageRouteExample`, team `QTKCGR6K6G`.
