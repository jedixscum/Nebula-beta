class Program {
  final String title;
  final DateTime start, end;
  const Program(this.title, this.start, this.end);
  String get label => '${_two(start.hour)}:${_two(start.minute)}';
  static String _two(int n) => n.toString().padLeft(2, '0');
}

const _titles = ['Deep Space News', 'Galaxy Cinema', 'Orbit Kids', 'Nebula Nights', 'Star Chef',
  'Cosmic Docs', 'Void Sports', 'Quasar Music'];

/// Mock EPG: deterministic half-hour grid for a channel.
List<Program> scheduleFor(String channelId, DateTime now, {int count = 8}) {
  final base = DateTime(now.year, now.month, now.day, now.hour, now.minute < 30 ? 0 : 30);
  final seed = channelId.codeUnits.fold<int>(0, (a, b) => a + b);
  return List.generate(count, (i) {
    final s = base.add(Duration(minutes: 30 * i));
    return Program(_titles[(seed + s.hour * 2 + s.minute ~/ 30) % _titles.length], s, s.add(const Duration(minutes: 30)));
  });
}
