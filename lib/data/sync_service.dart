import 'dart:convert';
import 'package:hive/hive.dart';

/// Multi-device sync via a portable JSON blob (copy/paste or share between devices).
/// Firebase cloud sync is NOT included: it needs your own google-services.json.
String exportAll() {
  final h = Hive.box<String>('history');
  return jsonEncode({
    'v': 1,
    'library': {for (final k in Hive.box<String>('library').keys) k as String: Hive.box<String>('library').get(k)},
    'history': {for (final k in h.keys) k as String: h.get(k)},
    'catalog': Hive.box<String>('catalog').get('all'),
    'homeLayout': Hive.box<String>('prefs').get('homeLayout'),
  });
}

/// Replaces local library/history/catalog/layout. Throws FormatException if invalid.
Future<void> importAll(String json) async {
  final j = jsonDecode(json);
  if (j is! Map || j['v'] != 1) throw const FormatException('Not a Nebula sync file');
  final lib = Hive.box<String>('library');
  await lib.clear();
  final l = j['library'];
  if (l is Map) {
    for (final e in l.entries) { await lib.put(e.key as String, e.value as String); }
  } else if (l is List) {
    for (final id in l) { await lib.put(id as String, '1'); }
  }
  final hist = Hive.box<String>('history');
  await hist.clear();
  (j['history'] as Map? ?? const {}).forEach((k, v) { hist.put(k as String, v as String); });
  final cat = Hive.box<String>('catalog');
  j['catalog'] == null ? await cat.delete('all') : await cat.put('all', j['catalog'] as String);
  final prefs = Hive.box<String>('prefs');
  j['homeLayout'] == null ? await prefs.delete('homeLayout') : await prefs.put('homeLayout', j['homeLayout'] as String);
}
