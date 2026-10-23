import 'dart:convert';
import 'package:dio/dio.dart';
import '../domain/addon.dart';
import '../domain/media_item.dart';

class Episode {
  final String id, title;
  final int season, number;
  const Episode(this.id, this.season, this.number, this.title);
}

class MetaDetail {
  final MediaItem item;
  final List<Episode> episodes;
  const MetaDetail(this.item, this.episodes);
}

class StreamOption {
  final String addonName, name, title, url;
  final Map<String, String>? headers;
  final List<ExtSub> subtitles;
  const StreamOption(this.addonName, this.name, this.title, this.url, this.headers, this.subtitles);
}

MediaItem metaToItem(Map m) {
  int digits(dynamic v) {
    final x = RegExp(r'\d+').firstMatch('${v ?? ''}');
    return x == null ? 0 : int.parse(x.group(0)!);
  }
  List<String> ls(dynamic v) => v is List ? [for (final e in v) if (e is String) e] : v is String ? [v] : <String>[];
  final t = m['type'];
  final type = t == 'series' ? MediaType.show : t == 'tv' ? MediaType.live : MediaType.movie;
  final y = RegExp(r'\d{4}').firstMatch('${m['year'] ?? m['releaseInfo'] ?? ''}');
  final dir = ls(m['director']).join(', ');
  return MediaItem(
    id: '${m['id']}', title: '${m['name'] ?? m['title'] ?? ''}',
    year: y == null ? 0 : int.parse(y.group(0)!), type: type,
    synopsis: '${m['description'] ?? ''}', director: dir.isEmpty ? '-' : dir,
    runtimeMin: digits(m['runtime']), rating: double.tryParse('${m['imdbRating'] ?? ''}') ?? 0,
    cast: ls(m['cast']), genres: ls(m['genres']),
    posterUrl: m['poster'] is String ? m['poster'] as String : null,
  );
}

/// Keeps only streams with a direct http(s) URL (what debrid-configured addons return).
/// Streams that only carry an infoHash/magnet cannot be played without a debrid service.
List<StreamOption> parseStreams(String addonName, Map j) {
  final out = <StreamOption>[];
  for (final s in (j['streams'] as List?) ?? const []) {
    if (s is! Map) continue;
    final url = s['url'];
    if (url is! String || !(url.startsWith('http://') || url.startsWith('https://'))) continue;
    Map<String, String>? headers;
    final req = (s['behaviorHints'] is Map ? s['behaviorHints']['proxyHeaders'] : null);
    if (req is Map && req['request'] is Map) {
      headers = {for (final e in (req['request'] as Map).entries) '${e.key}': '${e.value}'};
    }
    final subs = <ExtSub>[
      for (final x in (s['subtitles'] as List?) ?? const [])
        if (x is Map && x['url'] is String) ExtSub(x['url'] as String, '${x['lang'] ?? 'und'}')
    ];
    out.add(StreamOption(addonName, '${s['name'] ?? addonName}',
        '${s['title'] ?? s['description'] ?? ''}', url, headers, subs));
  }
  return out;
}

class AddonClient {
  final Dio _d = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 10), receiveTimeout: const Duration(seconds: 25)));

  Future<Map<String, dynamic>> _get(String url) async {
    final r = await _d.get(url);
    final d = r.data;
    if (d is Map) return Map<String, dynamic>.from(d);
    if (d is String) return Map<String, dynamic>.from(jsonDecode(d) as Map);
    throw const FormatException('Addon did not return JSON');
  }

  Future<Map<String, dynamic>> manifest(String url) => _get(url);

  Future<List<MediaItem>> catalog(Addon a, String type, String id, {String? search, int? skip}) async {
    final extras = [
      if (search != null) 'search=${Uri.encodeComponent(search)}',
      if (skip != null && skip > 0) 'skip=$skip',
    ];
    final path = extras.isEmpty ? '$id.json' : '$id/${extras.join('&')}.json';
    final j = await _get('${a.baseUrl}/catalog/$type/$path');
    return [for (final m in (j['metas'] as List?) ?? const []) if (m is Map) metaToItem(m)];
  }

  Future<MetaDetail?> meta(Addon a, String type, String id) async {
    final j = await _get('${a.baseUrl}/meta/$type/$id.json');
    final m = j['meta'];
    if (m is! Map) return null;
    final eps = <Episode>[];
    for (final v in (m['videos'] as List?) ?? const []) {
      if (v is! Map || v['id'] == null) continue;
      final s = int.tryParse('${v['season'] ?? ''}');
      final n = int.tryParse('${v['episode'] ?? v['number'] ?? ''}');
      if (s == null || n == null) continue;
      eps.add(Episode('${v['id']}', s, n, '${v['title'] ?? v['name'] ?? 'Episode $n'}'));
    }
    eps.sort((x, y) => x.season != y.season ? x.season.compareTo(y.season) : x.number.compareTo(y.number));
    return MetaDetail(metaToItem(m), eps);
  }

  Future<List<StreamOption>> streams(Addon a, String type, String id) async =>
      parseStreams(a.name, await _get('${a.baseUrl}/stream/$type/$id.json'));

  Future<List<ExtSub>> subtitles(Addon a, String type, String id) async {
    final j = await _get('${a.baseUrl}/subtitles/$type/$id.json');
    return [
      for (final x in (j['subtitles'] as List?) ?? const [])
        if (x is Map && x['url'] is String) ExtSub(x['url'] as String, '${x['lang'] ?? 'und'}')
    ];
  }
}
