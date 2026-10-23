import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

class Collection {
  final String id, name, description;
  final List<String> itemIds;
  const Collection(this.id, this.name, this.description, this.itemIds);
  Collection copyWith({String? name, String? description, List<String>? itemIds}) =>
      Collection(id, name ?? this.name, description ?? this.description, itemIds ?? this.itemIds);
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'description': description, 'items': itemIds};
  factory Collection.fromJson(Map<String, dynamic> j) => Collection(
      j['id'] as String, j['name'] as String, (j['description'] as String?) ?? '',
      List<String>.from(j['items'] ?? const []));
}

/// User-built catalog: named collections of titles, reorderable, JSON import/export.
class CatalogNotifier extends StateNotifier<List<Collection>> {
  Box<String> get _box => Hive.box<String>('catalog');
  CatalogNotifier() : super(_load());

  static List<Collection> _load() {
    final raw = Hive.box<String>('catalog').get('all');
    if (raw == null) return [];
    return [for (final j in jsonDecode(raw) as List) Collection.fromJson(j as Map<String, dynamic>)];
  }

  void _save(List<Collection> l) {
    state = l;
    _box.put('all', jsonEncode([for (final c in l) c.toJson()]));
  }

  void add(String name) => _save([...state,
    Collection(DateTime.now().microsecondsSinceEpoch.toString(), name, '', [])]);
  void edit(String id, String name, String desc) =>
      _save([for (final c in state) c.id == id ? c.copyWith(name: name, description: desc) : c]);
  void remove(String id) => _save(state.where((c) => c.id != id).toList());
  void addItem(String id, String itemId) => _save([
        for (final c in state)
          if (c.id == id && !c.itemIds.contains(itemId)) c.copyWith(itemIds: [...c.itemIds, itemId]) else c
      ]);
  void removeItem(String id, String itemId) => _save([
        for (final c in state)
          if (c.id == id) c.copyWith(itemIds: c.itemIds.where((e) => e != itemId).toList()) else c
      ]);
  void reorder(String id, int oldI, int newI) {
    if (newI > oldI) newI -= 1;
    _save([
      for (final c in state)
        if (c.id == id) c.copyWith(itemIds: _moved(c.itemIds, oldI, newI)) else c
    ]);
  }

  static List<String> _moved(List<String> src, int oldI, int newI) {
    final l = [...src];
    l.insert(newI, l.removeAt(oldI));
    return l;
  }

  String exportJson() => jsonEncode([for (final c in state) c.toJson()]);

  /// Merges by id. Throws FormatException on bad input.
  void importJson(String json) {
    final list = jsonDecode(json);
    if (list is! List) throw const FormatException('Expected a JSON list');
    final incoming = [for (final j in list) Collection.fromJson(j as Map<String, dynamic>)];
    final ids = incoming.map((c) => c.id).toSet();
    _save([...state.where((c) => !ids.contains(c.id)), ...incoming]);
  }
}
final catalogProvider = StateNotifierProvider<CatalogNotifier, List<Collection>>((_) => CatalogNotifier());
