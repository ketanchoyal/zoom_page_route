import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:zoom_page_route/zoom_page_route.dart';

/// Parity app: the same screens as the SwiftUI demo (`zoom-nav-demo`, which uses
/// `.navigationTransition(.zoom)`), so the two can be run side by side and
/// recorded. The cyan MEASURE card opens a solid magenta page, which lets a
/// screen recording be tracked frame by frame on both platforms.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // The device's display corner radius (62 pt on iPhone 17 Pro, much smaller
  // on iPad), read natively in AppDelegate.swift.
  final cornerRadius = await const MethodChannel('zoom_page_route_example/display').invokeMethod<double>('cornerRadius');
  ZoomPageRoute.defaultScreenCornerRadius = () => cornerRadius ?? 0;
  runApp(const ParityApp());
}

const accentRed = Color(0xFFE53935);
const accentYellow = Color(0xFFFFC107);
const groupedBackground = Color(0xFFF2F2F7);

class ParityApp extends StatelessWidget {
  const ParityApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: accentRed),
        platform: TargetPlatform.iOS,
        scaffoldBackgroundColor: groupedBackground,
      ),
      home: const HomeScreen(),
    );
  }
}

class MenuCategory {
  const MenuCategory(this.id, this.name, this.icon, this.colors);
  final int id;
  final String name;
  final IconData icon;
  final List<Color> colors;

  static const all = [
    MenuCategory(1, 'Burgers', Icons.lunch_dining, [Colors.orange, Colors.red]),
    MenuCategory(2, 'Pizza', Icons.local_pizza, [Colors.brown, Colors.orange]),
    MenuCategory(3, 'Salads', Icons.rice_bowl, [Colors.red, Colors.pink]),
    MenuCategory(4, 'Starters', Icons.eco, [Colors.green, Colors.teal]),
    MenuCategory(5, 'Sides', Icons.takeout_dining, [Colors.yellow, Colors.orange]),
    MenuCategory(6, 'Desserts', Icons.cake, [Colors.purple, Colors.pink]),
  ];
}

class Order {
  const Order(this.id, this.number, this.status, this.total, this.progress);
  final int id;
  final String number;
  final String status;
  final double total;
  final int progress;

  static const all = [
    Order(1001, '#1001', 'Cooking', 21.45, 1),
    Order(1002, '#1002', 'Placed', 18.20, 0),
    Order(1003, '#1003', 'On the way', 25.39, 2),
    Order(1004, '#1004', 'Delivered', 32.10, 3),
  ];
}

/// Counts how many times each screen's load ran; with one page instance per
/// push it goes up by exactly one each time (same badge as the SwiftUI demo).
final _loads = <String, int>{};
int recordLoad(String key) => _loads[key] = (_loads[key] ?? 0) + 1;

void _push(BuildContext context, Object tag, WidgetBuilder builder) {
  Navigator.of(context).push(ZoomPageRoute<void>(tag: tag, builder: builder));
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Demo Kitchen', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        centerTitle: true,
        backgroundColor: groupedBackground,
        surfaceTintColor: Colors.transparent,
        actions: [
          Builder(
            builder: (context) => IconButton(
              onPressed: () => _push(context, 'cart', (_) => const CartScreen()),
              icon: ZoomSource(
                tag: 'cart',
                toolbar: true,
                borderRadius: BorderRadius.circular(20),
                child: Badge(
                  label: const Text('4'),
                  backgroundColor: accentRed,
                  child: const Icon(CupertinoIcons.bag_fill, color: accentRed),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          const _PickupBar(),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: GestureDetector(
                onTap: () => _push(context, 'measure', (_) => const MeasureScreen()),
                child: ZoomSource(
                  tag: 'measure',
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 150,
                    height: 100,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: const Color(0xFF00FFFF), borderRadius: BorderRadius.circular(12)),
                    child: const Text('MEASURE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SpringsScreen())),
                child: const Text('SPRINGS', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 17)),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const _SectionTitle('Menu'),
          const SizedBox(height: 12),
          SizedBox(
            height: 150,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: MenuCategory.all.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final category = MenuCategory.all[index];
                return GestureDetector(
                  onTap: () => _push(context, 'menu-${category.id}', (_) => MenuItemsScreen(category)),
                  child: ZoomSource(
                    tag: 'menu-${category.id}',
                    borderRadius: BorderRadius.circular(12),
                    child: _CategoryCard(category),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          const _SectionTitle('Ongoing Orders'),
          const SizedBox(height: 12),
          for (final order in Order.all)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: GestureDetector(
                onTap: () => _push(context, 'order-${order.id}', (_) => OrderTrackingScreen(order)),
                child: ZoomSource(
                  tag: 'order-${order.id}',
                  borderRadius: BorderRadius.circular(6),
                  child: _OrderCard(order),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Text(text, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
  );
}

class _PickupBar extends StatelessWidget {
  const _PickupBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: const Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Pick-Up', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                SizedBox(height: 2),
                Text('30 min | 123 Main Street', style: TextStyle(color: Colors.black54, fontSize: 15)),
              ],
            ),
          ),
          Text('Edit', style: TextStyle(color: accentRed)),
        ],
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard(this.category);
  final MenuCategory category;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 150,
        height: 150,
        decoration: BoxDecoration(gradient: LinearGradient(colors: category.colors)),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(category.icon, size: 48, color: Colors.white.withValues(alpha: 0.35)),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                category.name.toUpperCase(),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 17),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard(this.order);
  final Order order;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Thank you for your order: ${order.number}', style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Text('Status: ${order.status}', style: const TextStyle(color: Colors.black54, fontSize: 13)),
          const SizedBox(height: 12),
          _ProgressSteps(order.progress),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10),
            alignment: Alignment.center,
            decoration: const ShapeDecoration(color: accentYellow, shape: StadiumBorder()),
            child: const Text('Track Ongoing Order', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _ProgressSteps extends StatelessWidget {
  const _ProgressSteps(this.progress);
  final int progress;
  static const steps = ['Placed', 'Cooking', 'On the way', 'Delivered'];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < steps.length; i++)
          Expanded(
            child: Column(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i <= progress ? Colors.green : Colors.grey.withValues(alpha: 0.3),
                  ),
                ),
                const SizedBox(height: 4),
                Text(steps[i], style: const TextStyle(fontSize: 11)),
              ],
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Destinations

class _LoadBadge extends StatelessWidget {
  const _LoadBadge(this.count);
  final int count;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(right: 12),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: ShapeDecoration(color: Colors.black.withValues(alpha: 0.06), shape: const StadiumBorder()),
    child: Text('load ran $count×', style: const TextStyle(fontSize: 12, fontFeatures: [FontFeature.tabularFigures()])),
  );
}

/// Records one load in initState — the Flutter equivalent of the SwiftUI
/// demo's `.task`. A second copy of the page would show up as 2×.
mixin _CountsLoads<T extends StatefulWidget> on State<T> {
  String get loadKey;
  late final int loads = recordLoad(loadKey);
}

AppBar _detailAppBar(String title, int loads) => AppBar(
  title: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
  centerTitle: true,
  backgroundColor: groupedBackground,
  surfaceTintColor: Colors.transparent,
  leading: Builder(
    builder: (context) => ZoomDismissBuilder(
      builder: (context, progress, child) => Opacity(opacity: 1 - progress, child: child),
      child: IconButton(icon: const Icon(CupertinoIcons.back), onPressed: () => Navigator.of(context).pop()),
    ),
  ),
  actions: [_LoadBadge(loads)],
);

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> with _CountsLoads {
  @override
  String get loadKey => 'cart';
  int quantity = 4;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // --dart-define=MEASURE=true: magenta behind the cart so its zoom can be
      // tracked frame by frame (same as the SwiftUI demo's -measure).
      backgroundColor: const bool.fromEnvironment('MEASURE') ? const Color(0xFFFF00FF) : null,
      appBar: _detailAppBar('Cart', loads),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Card(children: const [
            ListTile(title: Text('Pickup location'), trailing: Text('123 Main Street')),
            ListTile(title: Text('Pickup time'), trailing: Text('30 min')),
          ]),
          _Card(children: [
            ListTile(
              title: const Text('Veggie Spring Rolls'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(onPressed: () => setState(() => quantity--), icon: const Icon(CupertinoIcons.minus)),
                  Text('$quantity'),
                  IconButton(onPressed: () => setState(() => quantity++), icon: const Icon(CupertinoIcons.plus)),
                ],
              ),
            ),
          ]),
          _Card(children: [
            SizedBox(
              height: 120,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.all(12),
                children: [
                  for (final name in const ['Caesar Salad', 'Chicken Soup', 'Garlic Bread'])
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Column(
                        children: [
                          Container(
                            width: 120,
                            height: 70,
                            decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(8)),
                          ),
                          const SizedBox(height: 4),
                          Text(name, style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 16),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
    child: Column(children: children),
  );
}

class MenuItemsScreen extends StatefulWidget {
  const MenuItemsScreen(this.category, {super.key});
  final MenuCategory category;

  @override
  State<MenuItemsScreen> createState() => _MenuItemsScreenState();
}

class _MenuItemsScreenState extends State<MenuItemsScreen> with _CountsLoads {
  @override
  String get loadKey => 'menu-${widget.category.id}';

  @override
  Widget build(BuildContext context) {
    final category = widget.category;
    return Scaffold(
      appBar: _detailAppBar(category.name, loads),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 12,
        itemBuilder: (context, index) => Container(
          margin: const EdgeInsets.only(bottom: 1),
          color: Colors.white,
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: category.colors, begin: Alignment.topCenter, end: Alignment.bottomCenter),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(category.icon, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${category.name} #${index + 1}', style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text('\$${(7.99 + index).toStringAsFixed(2)}', style: const TextStyle(color: Colors.black54)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class OrderTrackingScreen extends StatefulWidget {
  const OrderTrackingScreen(this.order, {super.key});
  final Order order;

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> with _CountsLoads {
  @override
  String get loadKey => 'order-${widget.order.id}';

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    return Scaffold(
      appBar: _detailAppBar('Order Tracking', loads),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Thank you for your order!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          const Text('PICKUP TIME', style: TextStyle(fontSize: 12, color: Colors.black54)),
          const Text('4:35 pm'),
          const SizedBox(height: 20),
          _ProgressSteps(order.progress),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Icon(CupertinoIcons.flame_fill, size: 120, color: accentRed),
          ),
          for (var line = 1; line <= 8; line++) ...[
            Row(
              children: [
                Text('Receipt line $line'),
                const Spacer(),
                Text('\$$line.99', style: const TextStyle(color: Colors.black54)),
              ],
            ),
            const Divider(),
          ],
          Row(
            children: [
              Text('ORDER ID: ${order.number}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const Spacer(),
              Text('\$${order.total.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }
}

/// Solid magenta page for measuring the transition (same as the SwiftUI demo).
class MeasureScreen extends StatelessWidget {
  const MeasureScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFFF00FF),
      child: Center(
        child: FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ),
    );
  }
}

/// One dot per iOS spring preset, all moving 300 pt at once — the same screen
/// as the SwiftUI demo's Springs view, for recording both side by side.
class SpringsScreen extends StatefulWidget {
  const SpringsScreen({super.key});

  @override
  State<SpringsScreen> createState() => _SpringsScreenState();
}

class _SpringsScreenState extends State<SpringsScreen> with TickerProviderStateMixin {
  static final _presets = <(String, Color, SpringDescription)>[
    ('smooth', const Color(0xFFFF0000), IOSSpring.smooth),
    ('snappy', const Color(0xFF00FF00), IOSSpring.snappy),
    ('bouncy', const Color(0xFF0000FF), IOSSpring.bouncy),
    ('spring', const Color(0xFFFFFF00), IOSSpring.standard),
    ('interactiveSpring', const Color(0xFF00FFFF), IOSSpring.interactive),
    ('spring(response:0.55, dampingFraction:0.825)', const Color(0xFFFF8000), IOSSpring.legacyDefault),
  ];

  late final _controllers = [for (final _ in _presets) AnimationController.unbounded(vsync: this)];
  bool _on = false;

  void _toggle() {
    setState(() => _on = !_on);
    for (var i = 0; i < _presets.length; i++) {
      final c = _controllers[i];
      c.animateWith(SpringSimulation(_presets[i].$3, c.value, _on ? 1 : 0, c.velocity));
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Springs'), backgroundColor: Colors.white, surfaceTintColor: Colors.transparent),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < _presets.length; i++) ...[
              Text(_presets[i].$1, style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 6),
              AnimatedBuilder(
                animation: _controllers[i],
                builder: (context, child) =>
                    Transform.translate(offset: Offset(300 * _controllers[i].value, 0), child: child),
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(color: _presets[i].$2, shape: BoxShape.circle),
                ),
              ),
              const SizedBox(height: 28),
            ],
            FilledButton(onPressed: _toggle, child: Text(_on ? 'Reset' : 'Animate')),
          ],
        ),
      ),
    );
  }
}
