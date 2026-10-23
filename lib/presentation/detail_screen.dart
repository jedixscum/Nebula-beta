import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/starfield.dart';
import '../core/theme.dart';
import '../data/addon_client.dart';
import '../data/addon_service.dart';
import '../data/download_manager.dart';
import '../data/providers.dart';
import '../domain/media_item.dart';
import '../l10n/app_localizations.dart';

class DetailScreen extends ConsumerStatefulWidget {
  final MediaItem item;
  const DetailScreen({super.key, required this.item});
  @override
  ConsumerState<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends ConsumerState<DetailScreen> {
  int? _season;

  /// Lists playable streams from installed addons and opens the player with the chosen one.
  Future<void> _pickStream(MediaItem target) async {
    final future = streamsFor(ref, target.typeStr, target.id);
    final chosen = await showModalBottomSheet<StreamOption>(
      context: context,
      isScrollControlled: true,
      builder: (c) => FutureBuilder<List<StreamOption>>(
        future: future,
        builder: (c, s) {
          if (s.connectionState != ConnectionState.done) {
            return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()));
          }
          final l = s.data ?? [];
          if (l.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(24),
              child: Text('No playable streams found. Install an addon that returns direct links '
                  '(for example one configured with a debrid service).'),
            );
          }
          return ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(c).size.height * 0.7),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: l.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) => ListTile(
                title: Text(l[i].name),
                subtitle: Text(l[i].title, maxLines: 4, overflow: TextOverflow.ellipsis),
                trailing: Text(l[i].addonName, style: const TextStyle(color: Colors.white54, fontSize: 11)),
                onTap: () => Navigator.pop(c, l[i]),
              ),
            ),
          );
        },
      ),
    );
    if (chosen != null && mounted) {
      context.push('/player', extra: target.copyWith(streamUrl: chosen.url, headers: chosen.headers, extSubs: chosen.subtitles));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final base = widget.item;
    final isAddonItem = base.streamUrl == null;
    final meta = isAddonItem ? ref.watch(metaProvider((base.typeStr, base.id))).valueOrNull : null;
    final item = meta?.item ?? base;
    final episodes = meta?.episodes ?? const <Episode>[];
    final seasons = {for (final e in episodes) e.season}.toList()..sort();
    final season = _season ?? (seasons.contains(1) ? 1 : (seasons.isEmpty ? null : seasons.first));
    final inLib = ref.watch(libraryProvider).contains(item.id);
    final dl = ref.watch(downloadsProvider)[item.id];
    final done = dl?.status == DlStatus.done;
    final playable = done ? item.copyWith(streamUrl: 'file://${dl!.path}') : item;
    final canDownload = (item.streamUrl ?? '').startsWith('http') && item.type != MediaType.live;
    final isSeries = isAddonItem && item.type == MediaType.show;

    return Starfield(
      child: Scaffold(
        appBar: AppBar(backgroundColor: Colors.transparent, title: Text(item.title)),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          Wrap(spacing: 8, children: [
            if (item.year > 0) Chip(label: Text('${item.year}')),
            if (item.runtimeMin > 0) Chip(label: Text('${item.runtimeMin} min')),
            if (item.rating > 0)
              Chip(avatar: const Icon(Icons.star, size: 16, color: Colors.amber), label: Text(item.rating.toStringAsFixed(1))),
            for (final g in item.genres) Chip(label: Text(g)),
          ]),
          const SizedBox(height: 12),
          Text(item.synopsis),
          const SizedBox(height: 12),
          if (item.director != '-') Text('Director: ${item.director}', style: const TextStyle(color: nebulaCyan)),
          if (item.cast.isNotEmpty) Text('Cast: ${item.cast.take(8).join(', ')}'),
          const SizedBox(height: 24),
          if (!isSeries)
            FilledButton.icon(
              icon: const Icon(Icons.rocket_launch),
              label: Text(done ? '${t.launch} (offline)' : t.launch),
              onPressed: isAddonItem ? () => _pickStream(item) : (playable.streamUrl == null ? null : () => context.push('/player', extra: playable)),
            ),
          if (isSeries && season != null) ...[
            DropdownButton<int>(
              value: season,
              items: [for (final s in seasons) DropdownMenuItem(value: s, child: Text(s == 0 ? 'Specials' : 'Season $s'))],
              onChanged: (v) => setState(() => _season = v),
            ),
            for (final e in episodes.where((e) => e.season == season))
              ListTile(
                leading: Text('${e.number}'),
                title: Text(e.title),
                trailing: const Icon(Icons.play_arrow),
                onTap: () => _pickStream(item.copyWith(id: e.id, title: '${item.title} S${e.season}E${e.number}')),
              ),
          ],
          if (isSeries && season == null)
            const Text('Loading episodes… (needs an installed addon that provides metadata)', style: TextStyle(color: Colors.white54)),
          const SizedBox(height: 8),
          if (canDownload)
            OutlinedButton.icon(
              icon: Icon(done ? Icons.download_done : Icons.download),
              label: Text(done
                  ? 'Downloaded'
                  : dl?.status == DlStatus.running
                      ? 'Downloading ${(dl!.progress * 100).toStringAsFixed(0)}% (tap to pause)'
                      : dl != null ? 'Resume download' : 'Download'),
              onPressed: done
                  ? null
                  : () {
                      final m = ref.read(downloadsProvider.notifier);
                      dl?.status == DlStatus.running ? m.pause(item.id) : m.start(item);
                    },
            ),
          OutlinedButton.icon(
            icon: Icon(inLib ? Icons.bookmark_remove : Icons.bookmark_add),
            label: Text(inLib ? 'Remove from library' : 'Add to library'),
            onPressed: () => ref.read(libraryProvider.notifier).toggle(item),
          ),
        ]),
      ),
    );
  }
}
