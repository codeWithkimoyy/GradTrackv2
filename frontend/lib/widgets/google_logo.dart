import 'package:flutter/material.dart';

/// A widget that draws the official, authentic 4-color Google "G" logo.
class GoogleLogo extends StatelessWidget {
  const GoogleLogo({super.key, this.size = 24});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        size: Size(size, size),
        painter: const _GoogleLogoPainter(),
      ),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  const _GoogleLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final double s = size.width / 24.0;

    // 1. Blue path (#4285F4)
    final bluePaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;
    final bluePath = Path()
      ..moveTo(23.745 * s, 12.27 * s)
      ..relativeCubicTo(0, -0.7 * s, -0.06 * s, -1.4 * s, -0.19 * s, -2.07 * s)
      ..lineTo(12.0 * s, 10.2 * s)
      ..lineTo(12.0 * s, 14.71 * s)
      ..lineTo(18.6 * s, 14.71 * s)
      ..relativeCubicTo(-0.29 * s, 1.52 * s, -1.14 * s, 2.82 * s, -2.4 * s, 3.68 * s)
      ..relativeLineTo(0, 3.0 * s)
      ..relativeLineTo(3.88 * s, 0)
      ..relativeCubicTo(2.27 * s, -2.09 * s, 3.665 * s, -5.17 * s, 3.665 * s, -9.12 * s)
      ..close();
    canvas.drawPath(bluePath, bluePaint);

    // 2. Green path (#34A853)
    final greenPaint = Paint()
      ..color = const Color(0xFF34A853)
      ..style = PaintingStyle.fill;
    final greenPath = Path()
      ..moveTo(12.0 * s, 24.0 * s)
      ..relativeCubicTo(3.24 * s, 0, 5.95 * s, -1.08 * s, 7.93 * s, -2.91 * s)
      ..relativeLineTo(-3.88 * s, -3.0 * s)
      ..relativeCubicTo(-1.08 * s, 0.72 * s, -2.45 * s, 1.16 * s, -4.05 * s, 1.16 * s)
      ..relativeCubicTo(-3.12 * s, 0, -5.77 * s, -2.11 * s, -6.72 * s, -4.96 * s)
      ..lineTo(1.29 * s, 14.29 * s)
      ..lineTo(1.29 * s, 17.38 * s)
      ..cubicTo(3.26 * s, 21.3 * s, 7.31 * s, 24.0 * s, 12.0 * s, 24.0 * s)
      ..close();
    canvas.drawPath(greenPath, greenPaint);

    // 3. Yellow path (#FBBC05)
    final yellowPaint = Paint()
      ..color = const Color(0xFFFBBC05)
      ..style = PaintingStyle.fill;
    final yellowPath = Path()
      ..moveTo(5.28 * s, 14.29 * s)
      ..relativeCubicTo(-0.25 * s, -0.72 * s, -0.38 * s, -1.49 * s, -0.38 * s, -2.29 * s)
      ..relativeCubicTo(0, -0.80 * s, 0.13 * s, -1.57 * s, 0.38 * s, -2.29 * s)
      ..lineTo(5.28 * s, 6.62 * s)
      ..lineTo(1.29 * s, 6.62 * s)
      ..cubicTo(0.47 * s, 8.24 * s, 0, 10.06 * s, 0, 12.0 * s)
      ..cubicTo(0, 13.94 * s, 0.47 * s, 15.76 * s, 1.29 * s, 17.38 * s)
      ..relativeLineTo(3.99 * s, -3.09 * s)
      ..close();
    canvas.drawPath(yellowPath, yellowPaint);

    // 4. Red path (#EA4335)
    final redPaint = Paint()
      ..color = const Color(0xFFEA4335)
      ..style = PaintingStyle.fill;
    final redPath = Path()
      ..moveTo(12.0 * s, 4.75 * s)
      ..relativeCubicTo(1.77 * s, 0, 3.35 * s, 0.61 * s, 4.6 * s, 1.8 * s)
      ..relativeLineTo(3.42 * s, -3.42 * s)
      ..cubicTo(17.95 * s, 1.19 * s, 15.24 * s, 0, 12.0 * s, 0)
      ..cubicTo(7.31 * s, 0, 3.26 * s, 2.7 * s, 1.29 * s, 6.62 * s)
      ..relativeLineTo(3.99 * s, 3.09 * s)
      ..cubicTo(6.23 * s, 6.86 * s, 8.88 * s, 4.75 * s, 12.0 * s, 4.75 * s)
      ..close();
    canvas.drawPath(redPath, redPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
