import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../constants/app_constants.dart';
import '../../providers/stats_providers.dart';
import '../../repositories/stats_repository.dart';

/// Real analytics for staff: role distribution (admin), employment-status
/// distribution, verification rate and survey completion, all derived live
/// from Firestore.
class AnalyticsScreen extends ConsumerWidget {
  final bool adminMode;

  const AnalyticsScreen({super.key, this.adminMode = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(staffStatsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(adminMode ? 'System Analytics' : 'Alumni Analytics')),
      body: statsAsync.when(
        data: (stats) => ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            if (adminMode) _buildRoleChart(context, stats),
            _buildEmploymentChart(context, stats),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                _buildRateCard(context, 'Employment Rate',
                    '${stats.employmentRate.toStringAsFixed(1)}%',
                    Icons.trending_up_rounded, AppColors.success),
                const SizedBox(width: AppSpacing.sm),
                _buildRateCard(context, 'Verification Rate',
                    '${stats.verificationRate.toStringAsFixed(1)}%',
                    Icons.verified_rounded, AppColors.info),
                const SizedBox(width: AppSpacing.sm),
                _buildRateCard(context, 'Survey Completion',
                    '${stats.surveyCompletionRate.toStringAsFixed(1)}%',
                    Icons.fact_check_outlined, AppColors.gold),
              ],
            ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text('Analytics unavailable.\n\n$e',
                textAlign: TextAlign.center),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleChart(BuildContext context, DashboardStats stats) {
    final items = [
      ('Admin', stats.admins.toDouble(), AppColors.error),
      ('Alumni', stats.alumni.toDouble(), AppColors.primaryBlue),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Users by Role',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              height: 210,
              child: BarChart(
                BarChartData(
                  maxY: _maxY([for (final i in items) i.$2]),
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(),
                    topTitles: const AxisTitles(),
                    rightTitles: const AxisTitles(),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (v, m) => _bottomLabel(
                            v, m, [for (final i in items) i.$1]),
                      ),
                    ),
                  ),
                  barGroups: [
                    for (var i = 0; i < items.length; i++)
                      BarChartGroupData(x: i, barRods: [
                        BarChartRodData(
                          toY: items[i].$2,
                          color: items[i].$3,
                          width: 26,
                          borderRadius: BorderRadius.circular(7),
                        ),
                      ]),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmploymentChart(BuildContext context, DashboardStats stats) {
    final items = [
      ('Employed', stats.employed.toDouble(), AppColors.success),
      ('Self-employed', stats.selfEmployed.toDouble(), AppColors.info),
      ('Freelance', stats.freelance.toDouble(), AppColors.primaryBlue),
      ('Unemployed', stats.unemployed.toDouble(), AppColors.warning),
      ('Studying', stats.studying.toDouble(), AppColors.gold),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Employment Status (Alumni)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              height: 210,
              child: BarChart(
                BarChartData(
                  maxY: _maxY([for (final i in items) i.$2]),
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(),
                    topTitles: const AxisTitles(),
                    rightTitles: const AxisTitles(),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (v, m) => _bottomLabel(
                            v, m, [for (final i in items) i.$1]),
                      ),
                    ),
                  ),
                  barGroups: [
                    for (var i = 0; i < items.length; i++)
                      BarChartGroupData(x: i, barRods: [
                        BarChartRodData(
                          toY: items[i].$2,
                          color: items[i].$3,
                          width: 26,
                          borderRadius: BorderRadius.circular(7),
                        ),
                      ]),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRateCard(BuildContext context, String title, String value,
      IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withValues(alpha: .25)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(value,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(title,
                maxLines: 2,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10.5, color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }

  double _maxY(List<double> values) {
    final max = values.fold<double>(0, (a, b) => b > a ? b : a);
    return max <= 0 ? 4 : max * 1.15;
  }
}

Widget _bottomLabel(double value, TitleMeta meta, List<String> labels) {
  final index = value.toInt();
  if (index < 0 || index >= labels.length) return const SizedBox.shrink();
  return Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Text(
      labels[index],
      style: const TextStyle(fontSize: 10),
    ),
  );
}