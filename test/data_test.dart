import 'package:flutter_test/flutter_test.dart';
import 'package:nebula/data/epg.dart';
import 'package:nebula/data/recommender.dart';
import 'package:nebula/data/sample_data.dart';

void main() {
  test('recommender prefers co-liked items and excludes liked', () {
    final pool = sampleItems.where((m) => m.id != 'live1').toList();
    final r = recommend({'bbb'}, pool);
    expect(r.any((m) => m.id == 'bbb'), isFalse);
    expect(r.first.id, isNot('live2'));
  });
  test('epg returns consecutive slots', () {
    final s = scheduleFor('live1', DateTime(2026, 1, 1, 10, 10));
    expect(s.first.start.minute, 0);
    expect(s[1].start.difference(s[0].start), const Duration(minutes: 30));
  });
}
