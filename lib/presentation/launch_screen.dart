import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class LaunchScreen extends StatefulWidget {
  const LaunchScreen({super.key});

  @override
  State<LaunchScreen> createState() => _LaunchScreenState();
}

class _LaunchScreenState extends State<LaunchScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1900),
  )..forward();

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 1800), () {
      if (mounted) context.go('/');
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF02030A),
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = Curves.easeOutCubic.transform(_controller.value);
          return Stack(
            fit: StackFit.expand,
            children: [
              CustomPaint(painter: _NebulaPainter(progress: t)),
              SafeArea(
                child: Column(
                  children: [
                    const Spacer(flex: 2),
                    FadeTransition(
                      opacity: CurvedAnimation(
                        parent: _controller,
                        curve: const Interval(0.08, 0.58, curve: Curves.easeOut),
                      ),
                      child: Transform.scale(
                        scale: 0.86 + t * 0.14,
                        child: const _NebulaMark(),
                      ),
                    ),
                    const SizedBox(height: 22),
                    FadeTransition(
                      opacity: CurvedAnimation(
                        parent: _controller,
                        curve: const Interval(0.28, 0.7, curve: Curves.easeOut),
                      ),
                      child: const Text(
                        'STREAM  •  DISCOVER  •  EXPLORE',
                        style: TextStyle(
                          color: Color(0xFFD8E9FF),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 3.4,
                        ),
                      ),
                    ),
                    const Spacer(flex: 5),
                    FadeTransition(
                      opacity: CurvedAnimation(
                        parent: _controller,
                        curve: const Interval(0.52, 0.9, curve: Curves.easeOut),
                      ),
                      child: const Column(
                        children: [
                          SizedBox(
                            width: 150,
                            child: LinearProgressIndicator(
                              minHeight: 3,
                              backgroundColor: Color(0x442D3560),
                              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF45E7FF)),
                              value: 0.62,
                            ),
                          ),
                          SizedBox(height: 14),
                          Text(
                            'INITIALIZING',
                            style: TextStyle(
                              color: Color(0xFF8E9AB8),
                              fontSize: 9,
                              letterSpacing: 3.8,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 34),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _NebulaMark extends StatelessWidget {
  const _NebulaMark();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 96,
          height: 96,
          child: CustomPaint(painter: _LogoPainter()),
        ),
        const SizedBox(height: 18),
        const Text(
          'NEBULA',
          style: TextStyle(
            color: Colors.white,
            fontSize: 38,
            fontWeight: FontWeight.w300,
            letterSpacing: 10,
          ),
        ),
      ],
    );
  }
}

class _LogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final rect = Rect.fromCircle(center: c, radius: size.width * .44);
    final gradient = const LinearGradient(
      colors: [Color(0xFF8B36FF), Color(0xFF2B8DFF), Color(0xFF39E7FF)],
      begin: Alignment.bottomLeft,
      end: Alignment.topRight,
    );
    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.square;
    final path = Path()
      ..moveTo(size.width * .25, size.height * .76)
      ..lineTo(size.width * .25, size.height * .25)
      ..lineTo(size.width * .72, size.height * .76)
      ..lineTo(size.width * .72, size.height * .25);
    canvas.drawPath(path, paint);
    final orbit = Paint()
      ..color = const Color(0xFF53E9FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2;
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(-.32);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: size.width * .96, height: size.height * .34),
      orbit,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _NebulaPainter extends CustomPainter {
  final double progress;
  _NebulaPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * .62, size.height * .61);
    final maxR = math.max(size.width, size.height) * .75;

    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(.2, .2),
          radius: 1.1,
          colors: [Color(0xFF111044), Color(0xFF070B25), Color(0xFF02030A)],
          stops: [0, .52, 1],
        ).createShader(Offset.zero & size),
    );

    final nebulaPaint = Paint()
      ..shader = RadialGradient(
        colors: const [
          Color(0x664D20FF),
          Color(0x334D86FF),
          Color(0x0014DFFF),
        ],
        stops: const [0, .45, 1],
      ).createShader(Rect.fromCircle(center: center, radius: maxR));
    canvas.drawCircle(center, maxR, nebulaPaint);

    final cyanPaint = Paint()
      ..shader = RadialGradient(
        colors: const [Color(0x6640E8FF), Color(0x002D66FF)],
      ).createShader(Rect.fromCircle(
        center: Offset(size.width * .75, size.height * .66),
        radius: size.width * .55,
      ));
    canvas.drawCircle(Offset(size.width * .75, size.height * .66), size.width * .55, cyanPaint);

    final stars = <Offset>[];
    final random = math.Random(42);
    for (var i = 0; i < 145; i++) {
      stars.add(Offset(random.nextDouble() * size.width, random.nextDouble() * size.height));
    }
    final starPaint = Paint()..color = const Color(0xB8FFFFFF);
    for (var i = 0; i < stars.length; i++) {
      final p = stars[i];
      final r = i % 13 == 0 ? 1.25 : .45 + (i % 4) * .16;
      canvas.drawCircle(p, r, starPaint);
    }

    final planet = Offset(size.width * .13, size.height * .18);
    final planetR = size.width * .15;
    canvas.drawCircle(
      planet,
      planetR,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-.35, -.4),
          colors: [Color(0xFF324F80), Color(0xFF071022), Color(0xFF02030A)],
        ).createShader(Rect.fromCircle(center: planet, radius: planetR)),
    );

    final planet2 = Offset(size.width * .92, size.height * .70);
    final planet2R = size.width * .11;
    canvas.drawCircle(
      planet2,
      planet2R,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-.3, -.35),
          colors: [Color(0xFF273C66), Color(0xFF050817), Color(0xFF010207)],
        ).createShader(Rect.fromCircle(center: planet2, radius: planet2R)),
    );

    final glow = Paint()
      ..color = const Color(0xCC9A7BFF)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);
    canvas.drawCircle(Offset(size.width * .57, size.height * .69), 3 + progress * 2, glow);

    final ground = Path()
      ..moveTo(0, size.height * .88)
      ..quadraticBezierTo(size.width * .2, size.height * .79, size.width * .4, size.height * .88)
      ..quadraticBezierTo(size.width * .63, size.height * .78, size.width, size.height * .87)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      ground,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xDD07081A), Color(0xFF010207)],
        ).createShader(Offset.zero & size),
    );

    // Minimal astronaut silhouette, kept deliberately low-contrast so the logo remains dominant.
    final ax = size.width * .18;
    final ay = size.height * .84;
    final suit = Paint()..color = const Color(0xE0080A18);
    canvas.drawCircle(Offset(ax, ay - 62), 25, suit);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(ax - 27, ay - 40, 58, 78), const Radius.circular(20)),
      suit,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(ax - 50, ay - 30, 25, 70), const Radius.circular(12)),
      suit,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(ax + 30, ay - 30, 25, 70), const Radius.circular(12)),
      suit,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(ax - 23, ay + 28, 20, 60), const Radius.circular(10)),
      suit,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(ax + 8, ay + 28, 20, 60), const Radius.circular(10)),
      suit,
    );
  }

  @override
  bool shouldRepaint(covariant _NebulaPainter oldDelegate) => oldDelegate.progress != progress;
}
