import 'package:flutter/material.dart';

/// A custom widget that renders the official 4-color Google "G" logo.
class GoogleLogo extends StatelessWidget {
  const GoogleLogo({super.key, this.size = 24});

  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: const _GoogleLogoPainter(),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  const _GoogleLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final double cx = w / 2;
    final double cy = h / 2;
    final double radius = w * 0.45;
    final double strokeWidth = w * 0.20;

    final rect = Rect.fromCircle(
      center: Offset(cx, cy),
      radius: radius - strokeWidth / 2,
    );

    // Blue (right arc)
    final bluePaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    // Green (bottom arc)
    final greenPaint = Paint()
      ..color = const Color(0xFF34A853)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    // Yellow (left arc)
    final yellowPaint = Paint()
      ..color = const Color(0xFFFBBC05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    // Red (top arc)
    final redPaint = Paint()
      ..color = const Color(0xFFEA4335)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    // Draw arcs: angles in radians
    // Red top arc
    canvas.drawArc(rect, -0.85, -1.50, false, redPaint);
    // Yellow left arc
    canvas.drawArc(rect, -2.35, -1.40, false, yellowPaint);
    // Green bottom arc
    canvas.drawArc(rect, 0.70, 1.55, false, greenPaint);
    // Blue right arc
    canvas.drawArc(rect, -0.85, 1.55, false, bluePaint);

    // Blue horizontal bar in center right
    final barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;

    final barRect = Rect.fromLTWH(
      cx - strokeWidth * 0.1,
      cy - strokeWidth / 2,
      radius + strokeWidth * 0.1,
      strokeWidth,
    );
    canvas.drawRect(barRect, barPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
