import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

const homeSectionTitles = {
  'trending': 'Trending',
  'rec': 'AI Nebula Recommendations',
  'popular': 'Popular',
  'new': 'New Releases',
  'top': 'Top Rated',
  'library': 'My Library',
};

class HomeSection {
  final String key;
  final bool visible;
  const HomeSection(this.key, this.visible);
}

/// Customizable home: order + visibility persisted in Hive.
class HomeLayoutNotifier extends StateNotifier<List<HomeSection>> {
  HomeLayoutNotifier() : super(_load());

  static List<HomeSection> _load() {
    final raw = Hive.box<String>('prefs').get('homeLayout');
    final saved = <HomeSection>[];
    if (raw != null) {
      for (final j in jsonDecode(raw) as List) {
        final k = j['k'] as String;
        if (homeSectionTitles.containsKey(k)) saved.add(HomeSection(k, j['v'] as bool));
      }
    }
    for (final k in homeSectionTitles.keys) {
      if (!saved.any((s) => s.key == k)) saved.add(HomeSection(k, true));
    }
    return saved;
  }

  void _save(List<HomeSection> l) {
    state = l;
    Hive.box<String>('prefs').put('homeLayout',
        jsonEncode([for (final s in l) {'k': s.key, 'v': s.visible}]));
  }

  void reorder(int oldI, int newI) {
    if (newI > oldI) newI -= 1;
    final l = [...state];
    l.insert(newI, l.removeAt(oldI));
    _save(l);
  }

  void toggle(int i) => _save([
        for (var j = 0; j < state.length; j++)
          j == i ? HomeSection(state[j].key, !state[j].visible) : state[j]
      ]);
}
final homeLayoutProvider =
    StateNotifierProvider<HomeLayoutNotifier, List<HomeSection>>((_) => HomeLayoutNotifier());
