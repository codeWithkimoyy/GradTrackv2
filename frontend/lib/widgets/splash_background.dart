import 'dart:math' as math;

import 'package:flutter/material.dart';

class SplashBackground extends StatefulWidget {
  const SplashBackground({super.key, required this.child});

  final Widget child;

  @override
  State<SplashBackground> createState() => _SplashBackgroundState();
}

class _SplashBackgroundState extends State<SplashBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeOut,
          builder: (context, opacity, child) => Opacity(
            opacity: opacity,
            child: child,
          ),
          child: Image.asset(
            'assets/images/bisu.png',
            fit: BoxFit.cover,
            alignment: const Alignment(.2, -.45),
          ),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(color: Color(0xEA081B33)),
        ),
        AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => CustomPaint(
            painter: SplashAtmospherePainter(progress: _controller.value),
          ),
        ),
        widget.child,
      ],
    );
  }
}

class SplashAtmospherePainter extends CustomPainter {
  SplashAtmospherePainter({required this.progress});

  final double progress;

  static final _particles = List.generate(18, (index) {
    final random = math.Random(index * 41 + 17);
    return (
      x: random.nextDouble(),
      y: random.nextDouble(),
      size: 1.0 + random.nextDouble() * 2.2,
      phase: random.nextDouble() * math.pi * 2,
    );
  });

  @override
  void paint(Canvas canvas, Size size) {
    _paintAmbientCircles(canvas, size);
    _paintParticles(canvas, size);
    _paintWaves(canvas, size);
  }

  void _paintAmbientCircles(Canvas canvas, Size size) {
    final pulse = .92 + math.sin(progress * math.pi * 2) * .05;
    final circles = [
      (Offset(size.width * .88, size.height * .25), size.width * .18),
      (Offset(size.width * .08, size.height * .58), size.width * .11),
      (Offset(size.width * .82, size.height * .72), size.width * .08),
    ];
    for (var i = 0; i < circles.length; i++) {
      final circle = circles[i];
      canvas.drawCircle(
        circle.$1,
        circle.$2 * pulse,
        Paint()
          ..color = Colors.white.withOpacity(i == 0 ? .035 : .025)
          ..style = PaintingStyle.fill,
      );
      canvas.drawCircle(
        circle.$1,
        circle.$2 * pulse,
        Paint()
          ..color = Colors.white.withOpacity(.06)
          ..style = PaintingStyle.stroke
          ..strokeWidth = .8,
      );
    }
  }

  void _paintParticles(Canvas canvas, Size size) {
    for (var i = 0; i < _particles.length; i++) {
      final particle = _particles[i];
      final x = particle.x * size.width +
          math.sin(progress * math.pi * 2 + particle.phase) * 9;
      final y = (particle.y * size.height - progress * 34 + size.height) %
          size.height;
      final color =
          i % 6 == 0 ? const Color(0xFFFFC83D) : const Color(0xFFB9DCFF);
      canvas.drawCircle(
        Offset(x, y),
        particle.size * 2.4,
        Paint()
          ..color = color.withOpacity(.12)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
      );
      canvas.drawCircle(
        Offset(x, y),
        particle.size,
        Paint()..color = color.withOpacity(.48),
      );
    }
  }

  void _paintWaves(Canvas canvas, Size size) {
    final baseY = size.height * .78;
    for (var i = 0; i < 4; i++) {
      final shift = math.sin(progress * math.pi * 2 + i) * 8;
      final path = Path()
        ..moveTo(-30, baseY + i * 25 + shift)
        ..cubicTo(
          size.width * .22,
          baseY - 48 + i * 18,
          size.width * .58,
          baseY + 58 + i * 16,
          size.width + 30,
          baseY - 12 + i * 22 - shift,
        );
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = i == 0 ? 1.25 : .75
          ..color = Colors.white.withOpacity(.12 - i * .018),
      );
    }
  }

  @override
  bool shouldRepaint(covariant SplashAtmospherePainter oldDelegate) =>
      oldDelegate.progress != progress;
}
