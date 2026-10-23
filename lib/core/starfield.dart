import 'dart:math';
import 'package:flutter/material.dart';

/// Animated starfield + drifting nebula glow. One painter, one ticker: cheap on Android.
class Starfield extends StatefulWidget {
  final Widget child;
  const Starfield({super.key, required this.child});
  @override
  State<Starfield> createState() => _StarfieldState();
}

class _StarfieldState extends State<Starfield> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 60))..repeat();
  final _rnd = Random(7);
  late final stars = List.generate(120, (_) => [_rnd.nextDouble(), _rnd.nextDouble(), _rnd.nextDouble()]);

  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Stack(children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: AnimatedBuilder(
              animation: _c,
              builder: (_, __) => CustomPaint(painter: _P(stars, _c.value)),
            ),
          ),
        ),
        widget.child,
      ]);
}

class _P extends CustomPainter {
  final List<List<double>> stars;
  final double t;
  _P(this.stars, this.t);
  @override
  void paint(Canvas canvas, Size s) {
    final bg = Paint()..shader = const LinearGradient(
        begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [Color(0xFF05060F), Color(0xFF120A2A), Color(0xFF05060F)]).createShader(Offset.zero & s);
    canvas.drawRect(Offset.zero & s, bg);
    final a = 2 * pi * t;
    const glows = [Color(0x447C4DFF), Color(0x3318FFFF)];
    for (var i = 0; i < glows.length; i++) {
      final o = Offset(s.width * (0.3 + 0.4 * i + 0.1 * sin(a + i)), s.height * (0.3 + 0.2 * cos(a + i)));
      canvas.drawCircle(o, s.width * 0.6,
          Paint()..shader = RadialGradient(colors: [glows[i], Colors.transparent])
              .createShader(Rect.fromCircle(center: o, radius: s.width * 0.6)));
    }
    final p = Paint();
    for (final st in stars) {
      p.color = Colors.white.withOpacity(0.3 + 0.7 * (0.5 + 0.5 * sin(a * 3 + st[2] * 10)));
      canvas.drawCircle(Offset(st[0] * s.width, st[1] * s.height), 0.5 + st[2] * 1.2, p);
    }
  }
  @override
  bool shouldRepaint(_P o) => true;
}
