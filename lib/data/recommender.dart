import 'dart:math';
import '../domain/media_item.dart';

/// "Nebula Pattern Matching": item-item collaborative filtering over a preloaded mock matrix.
const _likes = <String, Set<String>>{
  'u1': {'bbb', 'ed', 'sintel'},
  'u2': {'ed', 'tos', 'sintel'},
  'u3': {'bbb', 'sintel'},
  'u4': {'tos', 'ed'},
  'u5': {'fire', 'joy', 'bbb'},
};

double similarity(String a, String b) {
  final ca = _likes.values.where((s) => s.contains(a)).length;
  final cb = _likes.values.where((s) => s.contains(b)).length;
  if (ca == 0 || cb == 0) return 0;
  final both = _likes.values.where((s) => s.contains(a) && s.contains(b)).length;
  return both / sqrt(ca * cb);
}

List<MediaItem> recommend(Set<String> liked, List<MediaItem> pool) {
  double score(MediaItem m) =>
      liked.fold<double>(0, (t, l) => t + similarity(m.id, l)) + m.rating / 100;
  final candidates = pool.where((m) => !liked.contains(m.id)).toList()
    ..sort((a, b) => score(b).compareTo(score(a)));
  return candidates;
}
