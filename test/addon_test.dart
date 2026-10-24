import 'package:flutter_test/flutter_test.dart';
import 'package:nebula/data/addon_client.dart';
import 'package:nebula/domain/addon.dart';
import 'package:nebula/domain/media_item.dart';

void main() {
  const manifest = {
    'id': 'org.example.streams', 'name': 'Example', 'version': '1.0.0',
    'types': ['movie', 'series'], 'idPrefixes': ['tt'],
    'resources': [
      'catalog',
      {'name': 'stream', 'types': ['movie'], 'idPrefixes': ['tt']},
    ],
    'catalogs': [
      {'type': 'movie', 'id': 'top', 'name': 'Top', 'extra': [{'name': 'skip'}]},
      {'type': 'movie', 'id': 'search', 'extra': [{'name': 'search', 'isRequired': true}]},
    ],
  };

  test('manifest parses resources and catalogs', () {
    final a = Addon.fromManifest(manifest, baseUrl: 'https://x.test/cfg');
    expect(a.remote, isTrue);
    expect(a.browseCatalogs.map((c) => c.id), ['top']); // search-only catalog excluded
    expect(a.catalogs.last.supportsSearch, isTrue);
    expect(a.supports('stream', 'movie', 'tt123'), isTrue);
    expect(a.supports('stream', 'series', 'tt123'), isFalse); // resource limits types
    expect(a.supports('stream', 'movie', 'kitsu:1'), isFalse);
  });

  test('add-on preferences default on and can be changed independently', () {
    final a = Addon.fromManifest(manifest, baseUrl: 'https://x.test');
    final customized = a.copyWithSettings(showInHome: false, useForStreams: false);
    expect(customized.enabled, isTrue);
    expect(customized.showInHome, isFalse);
    expect(customized.includeInSearch, isTrue);
    expect(customized.useForStreams, isFalse);
    expect(customized.useForMetadata, isTrue);
    expect(customized.useForSubtitles, isTrue);
    expect(a.showInHome, isTrue); // original remains immutable
  });

  test('manifest without id throws', () {
    expect(() => Addon.fromManifest({'name': 'X'}), throwsFormatException);
  });

  test('parseStreams keeps only direct http links and proxy headers', () {
    final s = parseStreams('A', {
      'streams': [
        {'url': 'https://cdn.test/a.mkv', 'name': 'RD 1080p', 'title': 'Movie\n2GB',
          'behaviorHints': {'proxyHeaders': {'request': {'User-Agent': 'x'}}},
          'subtitles': [{'url': 'https://s.test/en.srt', 'lang': 'eng'}]},
        {'infoHash': 'abc'}, // torrent-only: not playable without debrid
        {'url': 'magnet:?xt=urn:btih:abc'},
      ]
    });
    expect(s.length, 1);
    expect(s.first.headers, {'User-Agent': 'x'});
    expect(s.first.subtitles.single.lang, 'eng');
  });

  test('metaToItem maps addon meta', () {
    final m = metaToItem({'id': 'tt1', 'type': 'series', 'name': 'Show', 'releaseInfo': '2019–2022',
      'imdbRating': '8.1', 'runtime': '45 min', 'genres': ['Drama'], 'poster': 'https://p.test/p.jpg'});
    expect(m.type, MediaType.show);
    expect(m.typeStr, 'series');
    expect(m.year, 2019);
    expect(m.runtimeMin, 45);
    expect(m.rating, 8.1);
  });
}
