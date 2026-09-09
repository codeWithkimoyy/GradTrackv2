import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../constants/app_constants.dart';
import '../models/employment_model.dart';

/// Read-only card rendering a single [EmploymentRecord]. Used by alumni
/// (own history previews) and admins (per-user and aggregate history views).
class EmploymentRecordCard extends StatelessWidget {
  final EmploymentRecord record;
  const EmploymentRecordCard({super.key, required this.record});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final r = record;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
        boxShadow: isDark
            ? []
            : const [
                BoxShadow(
                  color: Color(0x0C0F172A),
                  blurRadius: 12,
                  offset: Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  r.position,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppColors.primaryNavy,
                  ),
                ),
              ),
              if (r.isCurrent)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppRadius.chip),
                    border: Border.all(
                        color: AppColors.success.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    'Current Job',
                    style: GoogleFonts.poppins(
                      color: AppColors.success,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            r.company,
            style: GoogleFonts.poppins(
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              fontSize: 13.5,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _tag(context, Icons.calendar_today_outlined,
                  DateFormat.yMMM().format(r.dateHired)),
              _tag(context, Icons.location_on_outlined, '${r.city}, ${r.country}'),
              _tag(context, Icons.laptop_mac_outlined, r.workSetup.label),
              _tag(context, Icons.badge_outlined, r.employmentType),
              if (r.industry.isNotEmpty)
                _tag(context, Icons.apartment_outlined, r.industry),
              if (r.salaryRange != null)
                _tag(context, Icons.payments_outlined, r.salaryRange!),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tag(BuildContext context, IconData icon, String text) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primaryBlue.withValues(alpha: isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primaryBlue.withValues(alpha: 0.20),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.primaryBlue),
          const SizedBox(width: 5),
          Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 11.5,
              color: isDark ? Colors.white : AppColors.primaryNavy,
            ),
          ),
        ],
      ),
    );
  }
}