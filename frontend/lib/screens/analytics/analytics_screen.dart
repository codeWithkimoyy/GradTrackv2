import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../constants/app_constants.dart';
import '../../providers/stats_providers.dart';
import '../../repositories/stats_repository.dart';
import '../../widgets/skeleton_loader.dart';

const _monthLabels = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// Real analytics for staff: role distribution (admin), employment-status
/// distribution, verification rate and survey completion, all derived live
/// from the MySQL backend — plus 12-month signup/response trend lines and
/// employment outcomes by graduation batch.
class AnalyticsScreen extends ConsumerWidget {
  final bool adminMode;

  /// When true, no AppBar is built so the screen can be embedded as a tab.
  final bool hideAppBar;

  const AnalyticsScreen(
      {super.key, this.adminMode = false, this.hideAppBar = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(staffStatsProvider);

    return Scaffold(
      appBar: hideAppBar
          ? null
          : AppBar(
              title:
                  Text(adminMode ? 'System Analytics' : 'Alumni Analytics')),
      body: statsAsync.when(
        data: (stats) => ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
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
            const SizedBox(height: AppSpacing.md),
            _TrendCard(
              title: 'New User Signups',
              subtitle: 'Last 12 months',
              icon: Icons.person_add_alt_1_rounded,
              color: AppColors.primaryBlue,
              points: stats.signupTrend,
            ),
            const SizedBox(height: AppSpacing.md),
            _TrendCard(
              title: 'Survey Responses',
              subtitle: 'Last 12 months',
              icon: Icons.fact_check_outlined,
              color: AppColors.success,
              points: stats.responseTrend,
            ),
            const SizedBox(height: AppSpacing.md),
            if (adminMode) _buildRoleChart(context, stats),
            _buildEmploymentChart(context, stats),
            const SizedBox(height: AppSpacing.md),
            _EmploymentByYearChart(stats: stats),
          ],
        ),
        loading: () => ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: const [
            SkeletonCard(height: 88),
            SizedBox(height: AppSpacing.md),
            SkeletonCard(height: 260),
            SizedBox(height: AppSpacing.md),
            SkeletonCard(height: 260),
          ],
        ),
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
    return _ChartCard(
      title: 'Users by Role',
      child: SizedBox(
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
    return _ChartCard(
      title: 'Employment Status (Alumni)',
      child: SizedBox(
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

/// Shared card wrapper for charts, matching the dashboard section style.
class _ChartCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _ChartCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: AppSpacing.md),
            child,
          ],
        ),
      ),
    );
  }
}

/// Smooth 12-month line chart built from [TrendPoint]s.
class _TrendCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final List<TrendPoint> points;

  const _TrendCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.points,
  });

  @override
  Widget build(BuildContext context) {
    final hasData = points.any((p) => p.count > 0);
    final spots = [
      for (var i = 0; i < points.length; i++)
        FlSpot(i.toDouble(), points[i].count.toDouble()),
    ];

    return _ChartCard(
      title: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 5),
              Text(subtitle,
                  style: TextStyle(
                      fontSize: 11.5,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: .55))),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 190,
            child: hasData
                ? LineChart(
                    LineChartData(
                      minX: 0,
                      maxX: 11,
                      minY: 0,
                      maxY: _maxY(),
                      lineBarsData: [
                        LineChartBarData(
                          spots: spots,
                          isCurved: true,
                          curveSmoothness: 0.35,
                          preventCurveOverShooting: true,
                          barWidth: 3,
                          color: color,
                          dotData: FlDotData(
                            show: true,
                            getDotPainter: (spot, percent, bar, index) =>
                                FlDotCirclePainter(
                              radius: spots.length <= 12 ? 3.2 : 2,
                              color: color,
                              strokeColor: Theme.of(context)
                                  .colorScheme
                                  .surface,
                              strokeWidth: 1.5,
                            ),
                          ),
                          belowBarData: BarAreaData(
                            show: true,
                            color: color.withValues(alpha: 0.12),
                          ),
                        ),
                      ],
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: _gridInterval(),
                        getDrawingHorizontalLine: (v) => FlLine(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: .07),
                          strokeWidth: 1,
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(),
                        rightTitles: const AxisTitles(),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 28,
                            interval: _gridInterval(),
                            getTitlesWidget: (v, m) => Text(
                              v.toInt().toString(),
                              style: const TextStyle(fontSize: 10),
                            ),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 24,
                            interval: 2,
                            getTitlesWidget: (v, m) {
                              final index = v.toInt();
                              if (index < 0 || index > 11) {
                                return const SizedBox.shrink();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  _monthLabels[points[index].month.month - 1],
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: .6),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      lineTouchData: LineTouchData(
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipColor: (_) =>
                              Theme.of(context).colorScheme.surface,
                          getTooltipItems: (spots) => [
                            for (final spot in spots)
                              LineTooltipItem(
                                '${spot.y.toInt()}',
                                GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: color,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  )
                : Center(
                    child: Text(
                      'No activity recorded yet.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: .5),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  double _maxY() {
    final max =
        points.fold<double>(0, (a, p) => p.count > a ? p.count.toDouble() : a);
    return max <= 0 ? 4 : max * 1.2;
  }

  double _gridInterval() {
    final max =
        points.fold<double>(0, (a, p) => p.count > a ? p.count.toDouble() : a);
    if (max <= 4) return 1;
    if (max <= 12) return 2;
    return (max / 4).ceilToDouble();
  }
}

/// Employment rate per graduation batch as a dual-series bar chart:
/// working alumni count vs batch size, with the rate as a label.
class _EmploymentByYearChart extends StatelessWidget {
  final DashboardStats stats;

  const _EmploymentByYearChart({required this.stats});

  @override
  Widget build(BuildContext context) {
    final entries = stats.employmentByYear;
    if (entries.isEmpty) {
      return const SizedBox.shrink();
    }
    // Cap at the 8 most recent batches so the chart stays readable.
    final recent = entries.length > 8 ? entries.sublist(entries.length - 8) : entries;

    return _ChartCard(
      title: 'Employment by Graduation Year',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _legendDot(AppColors.success, 'Working'),
              const SizedBox(width: 5),
              Text('Working',
                  style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: .55))),
              const SizedBox(width: 14),
              _legendDot(AppColors.borderLight, 'Batch size'),
              const SizedBox(width: 5),
              Text('Batch size',
                  style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: .55))),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 230,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: _maxY(recent),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(),
                  topTitles: const AxisTitles(),
                  rightTitles: const AxisTitles(),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (v, m) {
                        final index = v.toInt();
                        if (index < 0 || index >= recent.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            "'${(recent[index].year % 100).toString().padLeft(2, '0')}",
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: .6),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: [
                  for (var i = 0; i < recent.length; i++)
                    BarChartGroupData(
                      x: i,
                      barsSpace: 3,
                      barRods: [
                        BarChartRodData(
                          toY: recent[i].employedCount.toDouble(),
                          color: AppColors.success,
                          width: 14,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        BarChartRodData(
                          toY: recent[i].total.toDouble(),
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: .12),
                          width: 14,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
                    ),
                ],
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) =>
                        Theme.of(context).colorScheme.surface,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final e = recent[groupIndex];
                      if (rodIndex == 0) {
                        return BarTooltipItem(
                          '${e.employedCount}/${e.total} working\n${e.rate.toStringAsFixed(0)}% employed',
                          GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.success,
                          ),
                        );
                      }
                      return BarTooltipItem(
                        '${e.total} graduates',
                        GoogleFonts.poppins(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String _) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }

  double _maxY(List<YearEmployment> entries) {
    final max = entries
        .fold<double>(0, (a, e) => e.total > a ? e.total.toDouble() : a);
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
