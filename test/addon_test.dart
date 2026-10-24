import 'package:flutter_test/flutter_test.dart';
import 'package:nebula/data/addon_client.dart';
import 'package:nebula/domain/addon.dart';
import 'package:nebula/domain/media_item.dart';

void main() {
  final manifest = <String, dynamic>{
    'id': 'org.example.streams',
    'name': 'Example',
    'version': '1.0.0',
    'types': <String>['movie', 'series'],
    'idPrefixes': <String>['tt'],
    'resources': <dynamic>[
      'catalog',
      <String, dynamic>{'name': 'stream', 'types': <String>['movie'], 'idPrefixes': <String>['tt']},
    ],
    'catalogs': <dynamic>[
      <String, dynamic>{'type': 'movie', 'id': 'top', 'name': 'Top', 'extra': <dynamic>[<String, dynamic>{'name': 'skip'}]},
      <String, dynamic>{'type': 'movie', 'id': 'search', 'name': 'Search', 'extra': <dynamic>[<String, dynamic>{'name': 'search', 'isRequired': true}]},
    ],
  };

  test('manifest parses resources and catalogs', () {
    final a = Addon.fromManifest(manifest, baseUrl: 'https://x.test/cfg');
    expect(a.remote, isTrue);
    expect(a.browseCatalogs.map((c) => c.id), ['top']);
    expect(a.catalogs.last.supportsSearch, isTrue);
    expect(a.supports('stream', 'movie', 'tt123'), isTrue);
    expect(a.supports('stream', 'series', 'tt123'), isFalse);
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
    expect(a.showInHome, isTrue);
  });

  test('catalog preferences hide and reorder Home catalogs', () {
    final customized = Addon.fromManifest({...manifest, 'catalogs': <dynamic>[
      <String, dynamic>{'type': 'movie', 'id': 'one', 'name': 'One'},
      <String, dynamic>{'type': 'movie', 'id': 'two', 'name': 'Two'},
      <String, dynamic>{'type': 'movie', 'id': 'three', 'name': 'Three'},
    ]}).copyWithSettings(catalogSettings: <String, Map<String, dynamic>>{
      'one': <String, dynamic>{'showInHome': true, 'order': 2},
      'two': <String, dynamic>{'showInHome': false, 'order': 1},
      'three': <String, dynamic>{'showInHome': true, 'order': 0},
    });
    expect(customized.browseCatalogs.map((c) => c.id), ['three', 'one']);
    expect(customized.catalogs.first.id, 'three');
    expect(customized.catalogs[1].showInHome, isFalse);
  });

  test('manifest without id throws', () {
    expect(() => Addon.fromManifest(<String, dynamic>{'name': 'X'}), throwsA(isA<FormatException>()));
  });

  test('parseStreams keeps only direct http links and proxy headers', () {
    final streams = parseStreams('A', {'streams': <dynamic>[
      <String, dynamic>{
        'url': 'https://cdn.test/a.mkv', 'name': 'RD 1080p', 'title': 'Movie\n2GB',
        'behaviorHints': <String, dynamic>{'proxyHeaders': <String, dynamic>{'request': <String, dynamic>{'User-Agent': 'x'}}},
        'subtitles': <dynamic>[<String, dynamic>{'url': 'https://s.test/en.srt', 'lang': 'eng'}],
      },
      <String, dynamic>{'infoHash': 'abc'}, <String, dynamic>{'url': 'magnet:?xt=urn:btih:abc'},
    ]});
    expect(streams.length, 1);
    expect(streams.first.headers, {'User-Agent': 'x'});
    expect(streams.first.subtitles.single.lang, 'eng');
  });

  test('metaToItem maps addon meta', () {
    final item = metaToItem({'id': 'tt1', 'type': 'series', 'name': 'Show', 'releaseInfo': '2019–2022', 'imdbRating': '8.1', 'runtime': '45 min', 'genres': ['Drama'], 'poster': 'https://p.test/p.jpg'});
    expect(item.type, MediaType.show);
    expect(item.typeStr, 'series');
    expect(item.year, 2019);
    expect(item.runtimeMin, 45);
    expect(item.rating, 8.1);
  });
}
