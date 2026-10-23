class AddonCatalog {
  final String type, id, name;
  final bool supportsSearch, requiresExtra;
  const AddonCatalog({required this.type, required this.id, required this.name,
      this.supportsSearch = false, this.requiresExtra = false});
}

class AddonResource {
  final List<String> types, idPrefixes; // empty = inherit from the manifest
  const AddonResource({this.types = const [], this.idPrefixes = const []});
}

/// Addon described by a manifest.json (catalogs, meta, streams, subtitles resources).
class Addon {
  final String id, name, description, version;
  final List<String> types, idPrefixes;
  final bool builtIn;
  final String? baseUrl; // null for built-ins
  final Map<String, AddonResource> resources;
  final List<AddonCatalog> catalogs;
  final Map<String, dynamic> raw;
  const Addon({required this.id, required this.name, required this.description,
      required this.version, required this.types, this.builtIn = false, this.baseUrl,
      this.idPrefixes = const [], this.resources = const {}, this.catalogs = const [],
      this.raw = const {}});

  bool get remote => baseUrl != null;
  String get host => Uri.tryParse(baseUrl ?? '')?.host ?? '';
  List<AddonCatalog> get browseCatalogs => catalogs.where((c) => !c.requiresExtra).toList();

  bool supports(String resource, String type, String itemId) {
    final r = resources[resource];
    if (r == null) return false;
    final t = r.types.isNotEmpty ? r.types : types;
    if (t.isNotEmpty && !t.contains(type)) return false;
    final p = r.idPrefixes.isNotEmpty ? r.idPrefixes : idPrefixes;
    if (p.isNotEmpty && !p.any(itemId.startsWith)) return false;
    return true;
  }

  factory Addon.fromManifest(Map<String, dynamic> j, {String? baseUrl}) {
    for (final k in ['id', 'name']) {
      if (j[k] is! String || (j[k] as String).isEmpty) {
        throw FormatException('Addon manifest missing "$k"');
      }
    }
    List<String> strs(dynamic v) => v is List ? [for (final e in v) e.toString()] : <String>[];
    final res = <String, AddonResource>{};
    for (final r in (j['resources'] as List?) ?? const []) {
      if (r is String) {
        res[r] = const AddonResource();
      } else if (r is Map && r['name'] != null) {
        res[r['name'].toString()] =
            AddonResource(types: strs(r['types']), idPrefixes: strs(r['idPrefixes']));
      }
    }
    final cats = <AddonCatalog>[];
    for (final c in (j['catalogs'] as List?) ?? const []) {
      if (c is! Map || c['type'] == null || c['id'] == null) continue;
      var search = false, required = false;
      for (final e in (c['extra'] as List?) ?? const []) {
        if (e is Map) {
          if (e['name'] == 'search') search = true;
          if (e['isRequired'] == true) required = true;
        }
      }
      if (strs(c['extraSupported']).contains('search')) search = true;
      if (strs(c['extraRequired']).isNotEmpty) required = true;
      cats.add(AddonCatalog(
          type: c['type'].toString(), id: c['id'].toString(),
          name: (c['name'] ?? '${c['type']} ${c['id']}').toString(),
          supportsSearch: search, requiresExtra: required));
    }
    return Addon(
      id: j['id'] as String, name: j['name'] as String,
      version: (j['version'] ?? '0').toString(),
      description: (j['description'] as String?) ?? '',
      types: strs(j['types']), idPrefixes: strs(j['idPrefixes']),
      baseUrl: baseUrl, resources: res, catalogs: cats, raw: j,
    );
  }

  Map<String, dynamic> toManifest() => raw.isNotEmpty
      ? raw
      : {'id': id, 'name': name, 'version': version, 'description': description, 'types': types};
}
