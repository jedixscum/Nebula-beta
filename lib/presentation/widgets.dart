import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/theme_settings.dart';
import '../core/starfield.dart';
import '../core/theme.dart';
import '../domain/media_item.dart';

/// Poster card with glowing border. Falls back to a cosmic gradient when no poster.
class PosterCard extends StatelessWidget {
  final MediaItem item;
  final double width;
  const PosterCard({super.key, required this.item, this.width = 130});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: () => context.push('/detail', extra: item),
        borderRadius: BorderRadius.circular(14),
        focusColor: nebulaCyan.withOpacity(0.20),
        child: Container(
          width: width,
          margin: const EdgeInsets.only(right: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: nebulaViolet.withOpacity(0.6)),
            boxShadow: [BoxShadow(color: nebulaViolet.withOpacity(0.35), blurRadius: 12)],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(13),
            child: AspectRatio(
              aspectRatio: 2 / 3,
              child: Stack(fit: StackFit.expand, children: [
                if (item.posterUrl != null)
                  CachedNetworkImage(
                      imageUrl: item.posterUrl!, fit: BoxFit.cover,
                      placeholder: (_, __) => const ShimmerBox(),
                      errorWidget: (_, __, ___) => _fallback())
                else
                  _fallback(),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                        gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter,
                            colors: [Colors.black87, Colors.transparent])),
                    child: Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                  ),
                ),
              ]),
            ),
          ),
        ),
      );

  Widget _fallback() => Container(
        decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
          Color((item.title.hashCode & 0xFFFFFF) | 0xFF000000).withOpacity(0.7),
          nebulaViolet.withOpacity(0.4),
        ])),
        child: const Icon(Icons.auto_awesome, size: 36, color: Colors.white54),
      );
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
            Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: nebulaCyan))),
            if (onSeeAll != null)
              TextButton.icon(
                onPressed: onSeeAll,
                icon: const Icon(Icons.grid_view_rounded, size: 18),
                label: const Text('See all'),
              ),
          ]),
        ),
        SizedBox(
          height: (MediaQuery.sizeOf(context).width >= 800 ? 170 : 130) * 1.5 + 8,
          child: items.isEmpty
              ? const Center(child: Text('Nothing here yet', style: TextStyle(color: Colors.white38)))
              : ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(left: 16),
                  itemCount: items.length,
                  itemBuilder: (context, i) => PosterCard(item: items[i], width: MediaQuery.sizeOf(context).width >= 800 ? 170 : 130)),
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
