import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/theme_settings.dart';
import '../core/starfield.dart';
import '../core/theme.dart';
import '../domain/media_item.dart';

/// Poster card with a high-contrast focus state for TV remotes and keyboards.
class PosterCard extends StatefulWidget {
  final MediaItem item;
  final double width;
  const PosterCard({super.key, required this.item, this.width = 130});
  @override
  State<PosterCard> createState() => _PosterCardState();
}
class _PosterCardState extends State<PosterCard> {
  bool _focused = false;
  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return Semantics(button: true, label: 'Open ${item.title}', child: InkWell(
      onTap: () => context.push('/detail', extra: item),
      onFocusChange: (focused) { if (_focused != focused) setState(() => _focused = focused); },
      borderRadius: BorderRadius.circular(16), focusColor: nebulaCyan.withOpacity(0.18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120), width: widget.width,
        margin: const EdgeInsets.only(right: 14, top: 4, bottom: 8),
        transform: Matrix4.identity()..scale(_focused ? 1.035 : 1.0), transformAlignment: Alignment.center,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _focused ? nebulaCyan : nebulaViolet.withOpacity(0.62), width: _focused ? 3 : 1),
          boxShadow: [BoxShadow(color: (_focused ? nebulaCyan : nebulaViolet).withOpacity(_focused ? 0.48 : 0.24), blurRadius: _focused ? 22 : 10, spreadRadius: _focused ? 1 : 0)]),
        child: ClipRRect(borderRadius: BorderRadius.circular(13), child: AspectRatio(aspectRatio: 2 / 3, child: Stack(fit: StackFit.expand, children: [
          if (item.posterUrl != null) CachedNetworkImage(imageUrl: item.posterUrl!, fit: BoxFit.cover, placeholder: (_, __) => const ShimmerBox(), errorWidget: (_, __, ___) => _fallback(item)) else _fallback(item),
          Align(alignment: Alignment.bottomCenter, child: Container(
            padding: const EdgeInsets.fromLTRB(10, 24, 10, 10),
            decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Colors.black87, Colors.transparent])),
            child: Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: MediaQuery.sizeOf(context).width >= 800 ? 14 : 12, color: Colors.white)))),
          if (_focused) const Positioned(top: 8, right: 8, child: DecoratedBox(
            decoration: BoxDecoration(color: Color(0xDD05060F), shape: BoxShape.circle),
            child: Padding(padding: EdgeInsets.all(5), child: Icon(Icons.play_arrow_rounded, size: 20, color: nebulaCyan)))),
        ]))),
      ),
    ));
  }
  Widget _fallback(MediaItem item) => Container(decoration: BoxDecoration(gradient: LinearGradient(colors: [
    Color((item.title.hashCode & 0xFFFFFF) | 0xFF000000).withOpacity(0.7), nebulaViolet.withOpacity(0.4),
  ])), child: const Icon(Icons.auto_awesome, size: 36, color: Colors.white54));
}
class ShimmerBox extends StatelessWidget {
  const ShimmerBox({super.key});
  @override
  Widget build(BuildContext context) => Shimmer.fromColors(
      baseColor: Colors.white10, highlightColor: Colors.white24, child: Container(color: Colors.white));
}

class CosmicRow extends StatelessWidget {
  final String title;
  final List<MediaItem> items;
  final VoidCallback? onSeeAll;
  const CosmicRow({super.key, required this.title, required this.items, this.onSeeAll});
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(children: [
            Expanded(child: Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(color: nebulaCyan, fontWeight: FontWeight.w800))),
            if (onSeeAll != null)
              TextButton.icon(
                onPressed: onSeeAll,
                icon: const Icon(Icons.grid_view_rounded, size: 18),
                label: const Text('See all'),
              ),
          ]),
        ),
        SizedBox(
          height: (MediaQuery.sizeOf(context).width >= 800 ? 190 : 130) * 1.5 + 16,
          child: items.isEmpty
              ? const Center(child: Text('Nothing here yet', style: TextStyle(color: Colors.white38)))
              : ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(left: 16),
                  itemCount: items.length,
                  itemBuilder: (context, i) => PosterCard(item: items[i], width: MediaQuery.sizeOf(context).width >= 800 ? 190 : 130)),
        ),
      ]);
}

/// Starfield-backed page with an app bar, used for pushed sub-screens.
class SubPage extends ConsumerWidget {
  final String title;
  final Widget child;
  const SubPage({super.key, required this.title, required this.child});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Starfield(
        enabled: ref.watch(themeSettingsProvider).starfieldEnabled,
        child: Scaffold(
          appBar: AppBar(backgroundColor: Colors.transparent, title: Text(title)),
          body: SafeArea(child: child),
        ),
      );
}
