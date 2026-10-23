import 'dart:convert';
import 'package:hive/hive.dart';
import '../domain/media_item.dart';

class WatchEntry {
  final String id, title;
  final int posMs, durMs;
  final DateTime at;
  final List<String> genres;
  const WatchEntry(this.id, this.title, this.posMs, this.durMs, this.at, [this.genres = const []]);
}

/// "Continuum Watch History": resume positions + stats source.
class HistoryStore {
  Box<String> get _b => Hive.box<String>('history');

  void save(MediaItem m, Duration pos, Duration dur) => _b.put(
      m.id,
      jsonEncode({'t': m.title, 'p': pos.inMilliseconds, 'd': dur.inMilliseconds,
        'a': DateTime.now().millisecondsSinceEpoch, 'g': m.genres}));

  WatchEntry? get(String id) {
    final raw = _b.get(id);
    return raw == null ? null : _parse(id, raw);
  }

  List<WatchEntry> all() {
    final l = [for (final k in _b.keys.cast<String>()) _parse(k, _b.get(k)!)];
    l.sort((a, b) => b.at.compareTo(a.at));
    return l;
  }

  WatchEntry _parse(String id, String raw) {
    final j = jsonDecode(raw) as Map<String, dynamic>;
    return WatchEntry(id, j['t'] as String, j['p'] as int, j['d'] as int,
        DateTime.fromMillisecondsSinceEpoch(j['a'] as int),
        List<String>.from((j['g'] as List?) ?? const []));
  }
}
