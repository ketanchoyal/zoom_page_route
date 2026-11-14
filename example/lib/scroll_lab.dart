import 'package:flutter/material.dart';
import 'package:zoom_page_route/zoom_page_route.dart';

/// Flutter twin of the native `ScrollLab` (`native_reference`, `-scrollLab`):
/// where the zoom page's drag-down dismiss may start next to scrollables.
/// Layouts: `plain` (a list), `nested` (a list on a horizontally paged view)
/// and `header` (a fixed header above a list). Run with
/// `--dart-define=SCROLL_LAB=<layout>`.
class ScrollLabApp extends StatelessWidget {
  const ScrollLabApp({super.key, required this.layout});

  final String layout;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(platform: TargetPlatform.iOS),
      home: Builder(
        builder: (context) => Material(
          color: Colors.white,
          child: Center(
            child: ZoomSource(
              tag: 'lab',
              borderRadius: BorderRadius.circular(12),
              child: GestureDetector(
                onTap: () => Navigator.of(context).push(
                  ZoomPageRoute<void>(tag: 'lab', builder: (_) => _ScrollLabPage(layout: layout)),
                ),
                child: Container(
                  width: 200,
                  height: 120,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: Colors.cyan, borderRadius: BorderRadius.circular(12)),
                  child: const Text('SOURCE', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ScrollLabPage extends StatelessWidget {
  const _ScrollLabPage({required this.layout});

  final String layout;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: switch (layout) {
        'nested' => PageView(children: const [_Rows(prefix: 'A'), _Rows(prefix: 'B')]),
        'header' => Column(
          children: [
            Container(
              color: Colors.yellow,
              alignment: Alignment.center,
              padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top),
              height: 200 + MediaQuery.paddingOf(context).top,
              child: const Text('HEADER', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
            const Expanded(child: _Rows(prefix: 'A', topInset: false)),
          ],
        ),
        _ => const _Rows(prefix: 'A'),
      },
    );
  }
}

class _Rows extends StatelessWidget {
  const _Rows({required this.prefix, this.topInset = true});

  final String prefix;
  final bool topInset;

  @override
  Widget build(BuildContext context) {
    return MediaQuery.removePadding(
      context: context,
      removeTop: !topInset,
      child: ListView.builder(
        itemCount: 60,
        itemExtent: 56,
        itemBuilder: (context, i) => Container(
          color: i.isEven ? Colors.white : const Color(0xFFEBEBEB),
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text('$prefix Row $i'),
        ),
      ),
    );
  }
}
