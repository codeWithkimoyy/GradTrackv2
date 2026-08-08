import 'dart:ui';

import 'package:flutter/material.dart';

class SplashBrandContent extends StatelessWidget {
  const SplashBrandContent({
    super.key,
    required this.logoScale,
    required this.logoOpacity,
    required this.textSlide,
    required this.glow,
  });

  final Animation<double> logoScale;
  final Animation<double> logoOpacity;
  final Animation<Offset> textSlide;
  final Animation<double> glow;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 700;
        final logoSize =
            (constraints.maxWidth * .36).clamp(126.0, 166.0).toDouble();
        return SafeArea(
          minimum: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Column(
            children: [
              const Spacer(flex: 3),
              AnimatedBuilder(
                animation: Listenable.merge([logoScale, logoOpacity, glow]),
                builder: (context, child) => Opacity(
                  opacity: logoOpacity.value,
                  child: Transform.scale(
                    scale: logoScale.value,
                    child: Container(
                      width: logoSize,
                      height: logoSize,
                      padding: EdgeInsets.all(logoSize * .06),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: .08),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: .17),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0A66FF).withValues(
                              alpha: .24 + glow.value * .16,
                            ),
                            blurRadius: 34 + glow.value * 18,
                            spreadRadius: 2 + glow.value * 3,
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Padding(
                            padding: EdgeInsets.all(logoSize * .09),
                            child: Image.asset(
                              'assets/images/logo_full.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: compact ? 22 : 30),
              SlideTransition(
                position: textSlide,
                child: FadeTransition(
                  opacity: logoOpacity,
                  child: Column(
                    children: [
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: 'Grad',
                              style: TextStyle(
                                color: Colors.white,
                                shadows: const [
                                  Shadow(
                                    color: Color(0x66000000),
                                    blurRadius: 18,
                                  ),
                                ],
                              ),
                            ),
                            TextSpan(
                              text: 'Track',
                              style: TextStyle(
                                color: Color(0xFFFFC83D),
                                shadows: const [
                                  Shadow(
                                    color: Color(0x66000000),
                                    blurRadius: 18,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 40,
                          height: 1,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'GRADUATE TRACKING SYSTEM',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: .88),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.7,
                        ),
                      ),
                      const SizedBox(height: 9),
                      Text(
                        'Bohol Island State University - Bilar Campus',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: .68),
                          fontSize: 11.5,
                          height: 1.45,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(flex: 2),
              FadeTransition(
                opacity: logoOpacity,
                child: const _LoadingMark(),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LoadingMark extends StatelessWidget {
  const _LoadingMark();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            backgroundColor: Color(0x22FFFFFF),
            valueColor: AlwaysStoppedAnimation(Color(0xFFFFC83D)),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Preparing your experience',
          style: TextStyle(
            color: Colors.white.withValues(alpha: .48),
            fontSize: 10.5,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
