import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_constants.dart';

class DashboardStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String? subtitle;
  final String? badgeLabel;
  final Color? badgeColor;
  final double? progressValue;
  final String? actionLabel;
  final VoidCallback? onTap;

  const DashboardStatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.color = AppColors.primaryBlue,
    this.subtitle,
    this.badgeLabel,
    this.badgeColor,
    this.progressValue,
    this.actionLabel,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveBadgeColor = badgeColor ?? color;

    final content = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? color.withValues(alpha: 0.30)
              : AppColors.outlineCard,
          width: 1.5,
        ),
        boxShadow: isDark
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ]
            : const [
                BoxShadow(
                  color: Color(0x0A0052CC),
                  blurRadius: 16,
                  offset: Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: isDark ? 0.20 : 0.10),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: color.withValues(alpha: 0.28),
                    width: 1.5,
                  ),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
              if (badgeLabel != null && badgeLabel!.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: effectiveBadgeColor.withValues(alpha: isDark ? 0.18 : 0.10),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: effectiveBadgeColor.withValues(alpha: 0.30),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    badgeLabel!,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: effectiveBadgeColor,
                    ),
                  ),
                )
              else if (onTap != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withValues(alpha: isDark ? 0.15 : 0.08),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: AppColors.primaryBlue.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        actionLabel ?? 'View',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryBlue,
                        ),
                      ),
                      const SizedBox(width: 3),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        size: 12,
                        color: AppColors.primaryBlue,
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  maxLines: 1,
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : AppColors.primaryNavy,
                    height: 1.1,
                  ),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
                ),
              ),
              if (subtitle != null && subtitle!.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
                  ),
                ),
              ],
              if (progressValue != null) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progressValue,
                    minHeight: 6,
                    backgroundColor: isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : AppColors.primaryBlue.withValues(alpha: 0.1),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: content,
        ),
      );
    }

    return content;
  }
}
