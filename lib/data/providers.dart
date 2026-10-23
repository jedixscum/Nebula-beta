import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import '../domain/addon.dart';
import '../domain/media_item.dart';
import 'addon_client.dart';
import 'sample_data.dart';

final queryProvider = StateProvider<String>((_) => '');

/// Library: full item JSON per id (so addon titles survive restarts).
class LibraryNotifier extends StateNotifier<Set<String>> {
  final Box<String> _box = Hive.box<String>('library');
  LibraryNotifier() : super(Hive.box<String>('library').keys.cast<String>().toSet());
  void toggle(MediaItem m) {
    if (state.contains(m.id)) {
      _box.delete(m.id);
      state = {...state}..remove(m.id);
    } else {
      _box.put(m.id, jsonEncode(m.toJson()));
      state = {...state, m.id};
    }
  }
}
final libraryProvider = StateNotifierProvider<LibraryNotifier, Set<String>>((_) => LibraryNotifier());

MediaItem? _fromLibraryBox(String id) {
  final v = Hive.box<String>('library').get(id);
  if (v == null) return null;
  try {
    return MediaItem.fromJson(jsonDecode(v) as Map<String, dynamic>);
  } catch (_) {
    return null; // legacy entry
  }
}

/// Sample catalog first, then anything saved in the library.
MediaItem? resolveItem(String id) => findItem(id) ?? _fromLibraryBox(id);

final libraryItemsProvider = Provider<List<MediaItem>>((ref) {
  ref.watch(libraryProvider);
  final out = <MediaItem>[];
  for (final k in Hive.box<String>('library').keys.cast<String>()) {
    final m = _fromLibraryBox(k) ?? findItem(k);
    if (m != null) out.add(m);
  }
  return out;
});

const builtInAddons = [
  Addon(id: 'local', name: 'Local Media', version: '1.0.0', types: ['movie', 'series'],
      description: 'Play mp4/mkv from device storage.', builtIn: true),
  Addon(id: 'demo', name: 'Demo Streams', version: '1.0.0', types: ['movie', 'series'],
      description: 'Public sample videos.', builtIn: true),
];

class AddonNotifier extends StateNotifier<List<Addon>> {
  final Box<String> _box = Hive.box<String>('addons');
  final _client = AddonClient();
  AddonNotifier() : super([...builtInAddons, ..._stored()]);

  static List<Addon> _stored() {
    final out = <Addon>[];
    for (final v in Hive.box<String>('addons').values) {
      try {
        final j = jsonDecode(v) as Map<String, dynamic>;
        out.add(j['manifest'] is Map
            ? Addon.fromManifest(Map<String, dynamic>.from(j['manifest'] as Map), baseUrl: j['base'] as String?)
            : Addon.fromManifest(j));
      } catch (_) {/* skip corrupt entry */}
    }
    return out;
  }

  void _store(Addon a) {
    _box.put(a.id, jsonEncode({'base': a.baseUrl, 'manifest': a.raw}));
    state = [...state.where((e) => e.id != a.id), a];
  }

  /// Install from a manifest URL (https://, or the stremio:// form). Throws on failure.
  Future<Addon> installFromUrl(String input) async {
    var u = input.trim();
    if (u.startsWith('stremio://')) u = 'https://${u.substring(10)}';
    if (!u.startsWith('http')) throw const FormatException('Enter a manifest URL');
    if (!u.endsWith('/manifest.json')) u = u.endsWith('/') ? '${u}manifest.json' : '$u/manifest.json';
    final base = u.substring(0, u.length - '/manifest.json'.length);
    final a = Addon.fromManifest(await _client.manifest(u), baseUrl: base);
    _store(a);
    return a;
  }

  /// Install from pasted manifest JSON (no network resources).
  void installManifest(String json) => _store(Addon.fromManifest(jsonDecode(json) as Map<String, dynamic>));

  void remove(String id) {
    if (state.firstWhere((e) => e.id == id).builtIn) return;
    _box.delete(id);
    state = state.where((e) => e.id != id).toList();
  }
}
final addonsProvider = StateNotifierProvider<AddonNotifier, List<Addon>>((_) => AddonNotifier());

class FavoritesNotifier extends StateNotifier<Set<String>> {
 final Box<String> _prefs=Hive.box<String>('prefs');
 FavoritesNotifier():super(_load());
 static Set<String> _load(){try{return (jsonDecode(Hive.box<String>('prefs').get('favorites',defaultValue:'[]')!) as List).cast<String>().toSet();}catch(_){return {};}}
 void toggle(MediaItem item){final next={...state};if(!next.add(item.id)){next.remove(item.id);_prefs.delete('favoriteItem:${item.id}');}else{_prefs.put('favoriteItem:${item.id}',jsonEncode(item.toJson()));}_prefs.put('favorites',jsonEncode(next.toList()));state=next;}
}
final favoritesProvider=StateNotifierProvider<FavoritesNotifier,Set<String>>((_)=>FavoritesNotifier());
final favoritesItemsProvider=Provider<List<MediaItem>>((ref){final ids=ref.watch(favoritesProvider);final prefs=Hive.box<String>('prefs');return [for(final id in ids) if(resolveItem(id)!=null) resolveItem(id)! else if(prefs.get('favoriteItem:$id')!=null) MediaItem.fromJson(jsonDecode(prefs.get('favoriteItem:$id')!) as Map<String,dynamic>)];});
