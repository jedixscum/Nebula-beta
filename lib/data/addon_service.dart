import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/addon.dart';
import '../domain/media_item.dart';
import 'addon_client.dart';
import 'providers.dart';

final addonClientProvider = Provider((_) => AddonClient());

final genreFilterProvider = StateProvider<String?>((_) => null);
final minRatingProvider = StateProvider<double>((_) => 0);
final fromYearProvider = StateProvider<int>((_) => 0);

class AddonRow {
  final String title;
  final List<MediaItem> items;
  final Addon addon;
  final AddonCatalog catalog;
  const AddonRow(this.title, this.items, this.addon, this.catalog);
}

/// Home rows are fetched directly from installed add-ons. A failed catalog is
/// isolated so one broken add-on does not hide content from the others.
final addonRowsProvider = FutureProvider<List<AddonRow>>((ref) async {
  final addons = ref.watch(addonsProvider);
  final client = ref.read(addonClientProvider);
  final jobs = <Future<AddonRow?>>[];
  for (final a in addons.where((a) => a.remote && a.enabled && a.showInHome && a.resources.containsKey('catalog'))) {
    for (final catalog in a.browseCatalogs) {
      jobs.add(() async {
        try {
          final items = await client.catalog(a, catalog.type, catalog.id);
          return items.isEmpty ? null : AddonRow('${catalog.name} · ${a.name}', items, a, catalog);
        } catch (_) {
          return null;
        }
      }());
    }
  }
  return (await Future.wait(jobs)).whereType<AddonRow>().take(30).toList();
});

/// Search is backed only by installed add-ons; no bundled demo catalog is mixed in.
final searchResultsProvider = FutureProvider<List<MediaItem>>((ref) async {
  final q = ref.watch(queryProvider).trim();
  if (q.isEmpty) return const <MediaItem>[];

  final addons = ref.watch(addonsProvider);
  final client = ref.read(addonClientProvider);
  final jobs = <Future<List<MediaItem>>>[];
  for (final a in addons.where((a) => a.remote && a.enabled && a.includeInSearch && a.resources.containsKey('catalog'))) {
    for (final catalog in a.catalogs.where((c) => c.supportsSearch).take(3)) {
      jobs.add(client.catalog(a, catalog.type, catalog.id, search: q)
          .catchError((_) => <MediaItem>[]));
    }
  }

  final seen = <String>{};
  final results = <MediaItem>[];
  for (final list in await Future.wait(jobs)) {
    for (final item in list) {
      if (item.type != MediaType.live && seen.add(item.id)) results.add(item);
    }
  }
  return results;
});

/// Full metadata (cast, runtime, episodes) from the first addon that serves it.
final metaProvider = FutureProvider.family<MetaDetail?, (String, String)>((ref, key) async {
  final (type, id) = key;
  final client = ref.read(addonClientProvider);
  for (final a in ref.watch(addonsProvider).where((a) => a.remote && a.enabled && a.useForMetadata && a.supports('meta', type, id))) {
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
    for (final a in ref.read(addonsProvider).where((a) => a.remote && a.enabled && a.useForStreams && a.supports('stream', type, id)))
      client.streams(a, type, id).catchError((_) => <StreamOption>[])
  ];
  return (await Future.wait(jobs)).expand((e) => e).toList();
}

/// Subtitles from every addon that offers the subtitles resource.
Future<List<ExtSub>> subtitlesFor(WidgetRef ref, String type, String id) async {
  final client = ref.read(addonClientProvider);
  final jobs = [
    for (final a in ref.read(addonsProvider).where((a) => a.remote && a.enabled && a.useForSubtitles && a.supports('subtitles', type, id)))
      client.subtitles(a, type, id).catchError((_) => <ExtSub>[])
  ];
  return (await Future.wait(jobs)).expand((e) => e).toList();
}
