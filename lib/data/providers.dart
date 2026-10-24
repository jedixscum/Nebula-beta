import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import '../domain/addon.dart';
import '../domain/media_item.dart';
import 'addon_client.dart';

final queryProvider = StateProvider<String>((_) => '');
class LibraryNotifier extends StateNotifier<Set<String>> {
  final Box<String> _box = Hive.box<String>('library');
  LibraryNotifier() : super(Hive.box<String>('library').keys.cast<String>().toSet());
  void toggle(MediaItem m) { if (state.contains(m.id)) { _box.delete(m.id); state = {...state}..remove(m.id); } else { _box.put(m.id, jsonEncode(m.toJson())); state = {...state, m.id}; } }
}
final libraryProvider = StateNotifierProvider<LibraryNotifier, Set<String>>((_) => LibraryNotifier());
MediaItem? _fromLibraryBox(String id) { final v = Hive.box<String>('library').get(id); if (v == null) return null; try { return MediaItem.fromJson(jsonDecode(v) as Map<String, dynamic>); } catch (_) { return null; } }
MediaItem? resolveItem(String id) => _fromLibraryBox(id);
final libraryItemsProvider = Provider<List<MediaItem>>((ref) { ref.watch(libraryProvider); final out=<MediaItem>[]; for(final k in Hive.box<String>('library').keys.cast<String>()){final m=_fromLibraryBox(k);if(m!=null)out.add(m);} return out; });

class AddonNotifier extends StateNotifier<List<Addon>> {
  final Box<String> _box = Hive.box<String>('addons');
  final _client = AddonClient();
  AddonNotifier() : super(_stored());
  static List<Addon> _stored() {
    final out=<Addon>[];
    for(final v in Hive.box<String>('addons').values){
      try{
        final j=jsonDecode(v) as Map<String,dynamic>;
        final a=j['manifest'] is Map ? Addon.fromManifest(Map<String,dynamic>.from(j['manifest'] as Map),baseUrl:j['base'] as String?) : Addon.fromManifest(j);
        final s=j['settings'] is Map?Map<String,dynamic>.from(j['settings'] as Map):<String,dynamic>{};
        final cs=<String,Map<String,dynamic>>{};
        if(s['catalogs'] is Map){for(final e in (s['catalogs'] as Map).entries){if(e.value is Map)cs[e.key.toString()]=Map<String,dynamic>.from(e.value as Map);}}
        out.add(a.copyWithSettings(enabled:s['enabled'] is bool?s['enabled'] as bool:true,showInHome:s['showInHome'] is bool?s['showInHome'] as bool:true,includeInSearch:s['includeInSearch'] is bool?s['includeInSearch'] as bool:true,useForStreams:s['useForStreams'] is bool?s['useForStreams'] as bool:true,useForMetadata:s['useForMetadata'] is bool?s['useForMetadata'] as bool:true,useForSubtitles:s['useForSubtitles'] is bool?s['useForSubtitles'] as bool:true,catalogSettings:cs));
      }catch(_){ }
    }
    return out;
  }
  void _store(Addon a){
    _box.put(a.id,jsonEncode({'base':a.baseUrl,'manifest':a.raw,'settings':{'enabled':a.enabled,'showInHome':a.showInHome,'includeInSearch':a.includeInSearch,'useForStreams':a.useForStreams,'useForMetadata':a.useForMetadata,'useForSubtitles':a.useForSubtitles,'catalogs':{for(final c in a.catalogs)c.id:{'showInHome':c.showInHome,'order':c.order}}}}));
    final next=[...state];final i=next.indexWhere((e)=>e.id==a.id);if(i>=0)next[i]=a;else next.add(a);state=next;
  }
  Addon? _find(String id){for(final a in state){if(a.id==id)return a;}return null;}
  void updateSettings(String id,{bool? enabled,bool? showInHome,bool? includeInSearch,bool? useForStreams,bool? useForMetadata,bool? useForSubtitles}){final a=_find(id);if(a==null)return;_store(a.copyWithSettings(enabled:enabled,showInHome:showInHome,includeInSearch:includeInSearch,useForStreams:useForStreams,useForMetadata:useForMetadata,useForSubtitles:useForSubtitles));}
  void updateCatalogSettings(String addonId,String catalogId,{bool? showInHome,int? order}){final a=_find(addonId);if(a==null)return;final cs={for(final c in a.catalogs)c.id:{'showInHome':c.showInHome,'order':c.order}};final old=cs[catalogId]??{};cs[catalogId]={'showInHome':showInHome??(old['showInHome'] is bool?old['showInHome'] as bool:true),'order':order??(old['order'] is int?old['order'] as int:0)};_store(a.copyWithSettings(catalogSettings:cs));}
  Future<Addon> installFromUrl(String input) async {var u=input.trim();if(u.startsWith('stremio://'))u='https://${u.substring(10)}';if(!u.startsWith('http'))throw const FormatException('Enter a manifest URL');if(!u.endsWith('/manifest.json'))u=u.endsWith('/')?'${u}manifest.json':'$u/manifest.json';final base=u.substring(0,u.length-'/manifest.json'.length);var a=Addon.fromManifest(await _client.manifest(u),baseUrl:base);final old=_find(a.id);if(old!=null){final cs={for(final c in old.catalogs)c.id:{'showInHome':c.showInHome,'order':c.order}};a=a.copyWithSettings(enabled:old.enabled,showInHome:old.showInHome,includeInSearch:old.includeInSearch,useForStreams:old.useForStreams,useForMetadata:old.useForMetadata,useForSubtitles:old.useForSubtitles,catalogSettings:cs);} _store(a);return a;}
  void installManifest(String json)=>_store(Addon.fromManifest(jsonDecode(json) as Map<String,dynamic>));
  void remove(String id){final a=_find(id);if(a==null||a.builtIn)return;_box.delete(id);state=state.where((e)=>e.id!=id).toList();}
}
final addonsProvider=StateNotifierProvider<AddonNotifier,List<Addon>>((_)=>AddonNotifier());

class FavoritesNotifier extends StateNotifier<Set<String>>{final Box<String> _prefs=Hive.box<String>('prefs');FavoritesNotifier():super(_load());static Set<String> _load(){try{return(jsonDecode(Hive.box<String>('prefs').get('favorites',defaultValue:'[]')!) as List).cast<String>().toSet();}catch(_){return {};}}void toggle(MediaItem item){final next={...state};if(!next.add(item.id)){next.remove(item.id);_prefs.delete('favoriteItem:${item.id}');}else{_prefs.put('favoriteItem:${item.id}',jsonEncode(item.toJson()));}_prefs.put('favorites',jsonEncode(next.toList()));state=next;}}
final favoritesProvider=StateNotifierProvider<FavoritesNotifier,Set<String>>((_)=>FavoritesNotifier());
final favoritesItemsProvider=Provider<List<MediaItem>>((ref){final ids=ref.watch(favoritesProvider);final prefs=Hive.box<String>('prefs');return[for(final id in ids)if(resolveItem(id)!=null)resolveItem(id)!else if(prefs.get('favoriteItem:$id')!=null)MediaItem.fromJson(jsonDecode(prefs.get('favoriteItem:$id')!) as Map<String,dynamic>)];});
