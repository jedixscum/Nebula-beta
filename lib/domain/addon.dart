class AddonCatalog {
  final String type, id, name;
  final bool supportsSearch, requiresExtra;
  final bool showInHome;
  final int order;
  const AddonCatalog({required this.type, required this.id, required this.name,
      this.supportsSearch = false, this.requiresExtra = false,
      this.showInHome = true, this.order = 0});

  AddonCatalog copyWith({bool? showInHome, int? order}) => AddonCatalog(
    type: type, id: id, name: name, supportsSearch: supportsSearch,
    requiresExtra: requiresExtra, showInHome: showInHome ?? this.showInHome,
    order: order ?? this.order,
  );
}

class AddonResource {
  final List<String> types, idPrefixes;
  const AddonResource({this.types = const [], this.idPrefixes = const []});
}

/// Addon described by a manifest.json (catalogs, meta, streams, subtitles resources).
class Addon {
  final String id, name, description, version;
  final List<String> types, idPrefixes;
  final bool builtIn;
  final bool enabled, showInHome, includeInSearch, useForStreams, useForMetadata, useForSubtitles;
  final String? baseUrl;
  final Map<String, AddonResource> resources;
  final List<AddonCatalog> catalogs;
  final Map<String, dynamic> raw;
  const Addon({required this.id, required this.name, required this.description,
      required this.version, required this.types, this.builtIn = false, this.baseUrl,
      this.idPrefixes = const [], this.resources = const {}, this.catalogs = const [],
      this.raw = const {}, this.enabled = true, this.showInHome = true,
      this.includeInSearch = true, this.useForStreams = true,
      this.useForMetadata = true, this.useForSubtitles = true});

  Addon copyWithSettings({bool? enabled, bool? showInHome, bool? includeInSearch,
      bool? useForStreams, bool? useForMetadata, bool? useForSubtitles,
      Map<String, Map<String, dynamic>>? catalogSettings}) {
    final settings = catalogSettings ?? {
      for (final c in catalogs)
        c.id: {'showInHome': c.showInHome, 'order': c.order}
    };
    final updated = [for (final c in catalogs)
      c.copyWith(
        showInHome: settings[c.id]?['showInHome'] is bool ? settings[c.id]!['showInHome'] as bool : c.showInHome,
        order: settings[c.id]?['order'] is int ? settings[c.id]!['order'] as int : c.order,
      )];
    updated.sort((a, b) => a.order != b.order ? a.order.compareTo(b.order) : a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return Addon(id: id, name: name, description: description, version: version,
      types: types, builtIn: builtIn, baseUrl: baseUrl, idPrefixes: idPrefixes,
      resources: resources, catalogs: updated, raw: raw,
      enabled: enabled ?? this.enabled, showInHome: showInHome ?? this.showInHome,
      includeInSearch: includeInSearch ?? this.includeInSearch,
      useForStreams: useForStreams ?? this.useForStreams,
      useForMetadata: useForMetadata ?? this.useForMetadata,
      useForSubtitles: useForSubtitles ?? this.useForSubtitles);
  }

  bool get remote => baseUrl != null;
  String get host => Uri.tryParse(baseUrl ?? '')?.host ?? '';
  List<AddonCatalog> get browseCatalogs => catalogs.where((c) => !c.requiresExtra && c.showInHome).toList();

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
      if (j[k] is! String || (j[k] as String).isEmpty) throw FormatException('Addon manifest missing "$k"');
    }
    List<String> strs(dynamic v) => v is List ? [for (final e in v) e.toString()] : <String>[];
    final res = <String, AddonResource>{};
    for (final r in (j['resources'] as List?) ?? const []) {
      if (r is String) res[r] = const AddonResource();
      else if (r is Map && r['name'] != null) res[r['name'].toString()] = AddonResource(types: strs(r['types']), idPrefixes: strs(r['idPrefixes']));
    }
    final cats = <AddonCatalog>[];
    for (final c in (j['catalogs'] as List?) ?? const []) {
      if (c is! Map || c['type'] == null || c['id'] == null) continue;
      var search = false, required = false;
      for (final e in (c['extra'] as List?) ?? const []) {
        if (e is Map) { if (e['name'] == 'search') search = true; if (e['isRequired'] == true) required = true; }
      }
      if (strs(c['extraSupported']).contains('search')) search = true;
      if (strs(c['extraRequired']).isNotEmpty) required = true;
      cats.add(AddonCatalog(type: c['type'].toString(), id: c['id'].toString(),
        name: (c['name'] ?? '${c['type']} ${c['id']}').toString(), supportsSearch: search, requiresExtra: required));
    }
    return Addon(id: j['id'] as String, name: j['name'] as String,
      version: (j['version'] ?? '0').toString(), description: (j['description'] as String?) ?? '',
      types: strs(j['types']), idPrefixes: strs(j['idPrefixes']), baseUrl: baseUrl,
      resources: res, catalogs: cats, raw: j);
  }

  Map<String, dynamic> toManifest() => raw.isNotEmpty ? raw :
      {'id': id, 'name': name, 'version': version, 'description': description, 'types': types};
}
