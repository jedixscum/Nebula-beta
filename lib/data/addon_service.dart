import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/addon.dart';
import '../domain/media_item.dart';
import 'addon_client.dart';
import 'providers.dart';
import 'sample_data.dart';

final addonClientProvider = Provider((_) => AddonClient());

final genreFilterProvider = StateProvider<String?>((_) => null);
final minRatingProvider = StateProvider<double>((_) => 0);
final fromYearProvider = StateProvider<int>((_) => 0);

class AddonRow {
  final String title;
  final List<MediaItem> items;
  const AddonRow(this.title, this.items);
}

/// Home rows from installed addons' catalogs (first few per addon).
final addonRowsProvider = FutureProvider<List<AddonRow>>((ref) async {
  final addons = ref.watch(addonsProvider);
  final client = ref.read(addonClientProvider);
  final jobs = <Future<AddonRow?>>[];
  for (final a in addons.where((a) => a.remote && a.resources.containsKey('catalog'))) {
    for (final c in a.browseCatalogs.take(3)) {
      jobs.add(() async {
        try {
          final items = await client.catalog(a, c.type, c.id);
          return items.isEmpty ? null : AddonRow('${c.name} · ${a.name}', items);
        } catch (_) {
          return null;
        }
      }());
    }
  }
  return (await Future.wait(jobs)).whereType<AddonRow>().take(8).toList();
});

/// Search across the sample catalog and addon catalogs that support search.
final searchResultsProvider = FutureProvider<List<MediaItem>>((ref) async {
  final q = ref.watch(queryProvider).trim();
  final g = ref.watch(genreFilterProvider);
  final r = ref.watch(minRatingProvider);
  final y = ref.watch(fromYearProvider);
  bool ok(MediaItem m) =>
      m.type != MediaType.live && (g == null || m.genres.contains(g)) && m.rating >= r && m.year >= y;
  final local = sampleItems
      .where((m) => ok(m) && (q.isEmpty || m.title.toLowerCase().contains(q.toLowerCase())))
      .toList();
  if (q.isEmpty) return local;

  var cancelled = false;
  ref.onDispose(() => cancelled = true);
  await Future.delayed(const Duration(milliseconds: 350)); // debounce typing
  if (cancelled) return local;

  final addons = ref.read(addonsProvider);
  final client = ref.read(addonClientProvider);
  final jobs = <Future<List<MediaItem>>>[];
  for (final a in addons.where((a) => a.remote && a.resources.containsKey('catalog'))) {
    for (final c in a.catalogs.where((c) => c.supportsSearch).take(2)) {
      jobs.add(client.catalog(a, c.type, c.id, search: q).catchError((_) => <MediaItem>[]));
    }
  }
  final seen = {for (final m in local) m.id};
  final remote = <MediaItem>[];
  for (final list in await Future.wait(jobs)) {
    for (final m in list) {
      if (ok(m) && seen.add(m.id)) remote.add(m);
    }
  }
  return [...local, ...remote];
});

/// Full metadata (cast, runtime, episodes) from the first addon that serves it.
final metaProvider = FutureProvider.family<MetaDetail?, (String, String)>((ref, key) async {
  final (type, id) = key;
  final client = ref.read(addonClientProvider);
  for (final a in ref.read(addonsProvider).where((a) => a.remote && a.supports('meta', type, id))) {
    try {
      final m = await client.meta(a, type, id);
      if (m != null) return m;
    } catch (_) {/* try next addon */}
  }
  return null;
});

/// Playable (direct-URL) streams from every addon that can serve this id.
Future<List<StreamOption>> streamsFor(WidgetRef ref, String type, String id) async {
  final client = ref.read(addonClientProvider);
  final jobs = [
    for (final a in ref.read(addonsProvider).where((a) => a.remote && a.supports('stream', type, id)))
      client.streams(a, type, id).catchError((_) => <StreamOption>[])
  ];
  return (await Future.wait(jobs)).expand((e) => e).toList();
}

/// Subtitles from every addon that offers the subtitles resource.
Future<List<ExtSub>> subtitlesFor(WidgetRef ref, String type, String id) async {
  final client = ref.read(addonClientProvider);
  final jobs = [
    for (final a in ref.read(addonsProvider).where((a) => a.remote && a.supports('subtitles', type, id)))
      client.subtitles(a, type, id).catchError((_) => <ExtSub>[])
  ];
  return (await Future.wait(jobs)).expand((e) => e).toList();
}
