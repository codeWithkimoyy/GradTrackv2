import 'package:flutter/material.dart';

import '../constants/app_constants.dart';

/// Filter pill used to narrow a staff list down to one graduation batch.
/// Label and count keep WCAG AA contrast in both brightness modes.
class BatchFilterChip extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  const BatchFilterChip({
    super.key,
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return FilterChip(
      selected: selected,
      onSelected: (_) => onTap(),
      showCheckmark: false,
      selectedColor: AppColors.primaryBlue,
      backgroundColor: isDark ? AppColors.cardDark : Colors.white,
      side: BorderSide(
        color: selected
            ? AppColors.primaryBlue
            : (isDark ? AppColors.borderDark : AppColors.outlineCard),
        width: 1.5,
      ),
      label: Text(
        '$label · $count',
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: selected
              ? Colors.white
              : (isDark ? Colors.white : AppColors.textPrimary),
        ),
      ),
    );
  }
}

/// Section header grouping one graduation batch of records.
class BatchSectionHeader extends StatelessWidget {
  final String label;
  final int count;

  const BatchSectionHeader(
      {super.key, required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 8),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
              color: AppColors.primaryBlue,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 14),
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withValues(
                  alpha: isDark ? 0.22 : 0.10),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.primaryBlue.withValues(alpha: 0.30),
              ),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.tealLight : AppColors.primaryBlue,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
