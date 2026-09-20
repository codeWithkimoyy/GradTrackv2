import 'dart:math' as math;
import 'package:flutter/material.dart';

class AnimatedBackground extends StatefulWidget {
  final Widget child;
  const AnimatedBackground({super.key, required this.child});

  @override
  State<AnimatedBackground> createState() => _AnimatedBackgroundState();
}

class _AnimatedBackgroundState extends State<AnimatedBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final p = _controller.value;
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF0A2540),
          ),
          child: Stack(
            children: [
              ..._buildOrbs(p),
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _ParticlePainter(progress: p),
                  ),
                ),
              ),
              if (child != null) child,
            ],
          ),
        );
      },
      child: widget.child,
    );
  }

  List<Widget> _buildOrbs(double p) {
    final orbs = [
      const _OrbData(180, Color(0xFF60A5FA), -0.84, -0.76, 0),
      const _OrbData(220, Color(0xFF3B82F6), 0.70, -0.30, 1.2),
      const _OrbData(160, Color(0xFF93C5FD), -0.64, 0.60, 2.5),
      const _OrbData(140, Color(0xFF1D4ED8), 0.76, 0.70, 3.7),
    ];

    return orbs.map((orb) {
      final wobble = math.sin(p * math.pi * 2 * 0.5 + orb.phase) * 0.1 + 1;
      final dx = math.sin(p * math.pi * 2 + orb.phase) * 12;
      final dy = math.cos(p * math.pi * 2 + orb.phase) * 10;
      return Align(
        alignment: Alignment(orb.alignX, orb.alignY),
        child: Transform.translate(
          offset: Offset(dx, dy),
          child: Container(
            width: orb.size * wobble,
            height: orb.size * wobble,
            decoration: BoxDecoration(
              color: orb.color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: orb.color.withOpacity(0.3),
                  blurRadius: orb.size * 0.5,
                  spreadRadius: orb.size * 0.2,
                ),
              ],
            ),
          ),
        ),
      );
    }).toList();
  }
}

class _OrbData {
  final double size;
  final Color color;
  final double alignX;
  final double alignY;
  final double phase;
  const _OrbData(this.size, this.color, this.alignX, this.alignY, this.phase);
}

class _ParticlePainter extends CustomPainter {
  final double progress;

  _ParticlePainter({required this.progress});

  static final List<_Particle> _particles = List.generate(30, (i) {
    final rng = math.Random(i * 73 + 42);
    return _Particle(
      x: rng.nextDouble(),
      y: rng.nextDouble(),
      radius: rng.nextDouble() * 2 + 0.5,
      phase: rng.nextDouble() * math.pi * 2,
      speed: rng.nextDouble() * 0.5 + 0.3,
    );
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in _particles) {
      final x = (p.x * size.width +
              math.sin(progress * math.pi * 2 * p.speed + p.phase) * 12) %
          size.width;
      final y = (p.y * size.height +
              math.cos(progress * math.pi * 2 * p.speed + p.phase) * 12) %
          size.height;
      canvas.drawCircle(
        Offset(x, y),
        p.radius,
        Paint()..color = Colors.white.withOpacity(0.04 + p.radius * 0.015),
      );
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter oldDelegate) => true;
}

class _Particle {
  final double x, y, radius, phase, speed;
  const _Particle({
    required this.x,
    required this.y,
    required this.radius,
    required this.phase,
    required this.speed,
  });
}
