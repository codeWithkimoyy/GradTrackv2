import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_constants.dart';

/// Bohol Island State University (BISU) & GradTrack Dual Brand Logo
/// Matches the exact brand identity from the GradTrack design system:
/// Official BISU Seal + Visual Divider + GradTrack Mark + Styled Typography
class BisuBrandLogo extends StatelessWidget {
  final bool compact;
  final bool inverted;
  final double size;

  const BisuBrandLogo({
    super.key,
    this.compact = false,
    this.inverted = false,
    this.size = 38,
  });

  @override
  Widget build(BuildContext context) {
    final titleColor = inverted ? Colors.white : AppColors.bisuOfficialPrimary;
    final trackColor =
        inverted ? AppColors.logoCyanLight : AppColors.primaryBlue;
    final dividerColor =
        inverted ? Colors.white.withOpacity(0.25) : AppColors.borderLight;
    final subtitleColor =
        inverted ? const Color(0xFFBFDBFE) : AppColors.textSecondary;

    if (compact) {
      return Image.asset(
        'assets/images/logo_mark.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // BISU Official Seal
        ClipRRect(
          borderRadius: BorderRadius.circular(size / 2),
          child: Image.asset(
            'assets/images/bisulogo.jpg',
            width: size,
            height: size,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => Image.asset(
              'assets/images/bisu.png',
              width: size,
              height: size,
              fit: BoxFit.contain,
            ),
          ),
        ),

        // Visual Divider
        Container(
          width: 1.2,
          height: size * 0.62,
          margin: const EdgeInsets.symmetric(horizontal: 5),
          color: dividerColor,
        ),

        // GradTrack Official Logo Mark
        Image.asset(
          'assets/images/logo_mark.png',
          width: size * 0.92,
          height: size * 0.92,
          fit: BoxFit.contain,
        ),
        const SizedBox(width: 6),

        // Typography
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: 'Grad',
                        style: GoogleFonts.poppins(
                          color: titleColor,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      TextSpan(
                        text: 'Track',
                        style: GoogleFonts.poppins(
                          color: trackColor,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  style: GoogleFonts.poppins(
                    fontSize: size * 0.50,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                    height: 1.1,
                  ),
                ),
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  'BISU ALUMNI TRACER',
                  style: GoogleFonts.poppins(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.7,
                    color: subtitleColor,
                    height: 1.1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
