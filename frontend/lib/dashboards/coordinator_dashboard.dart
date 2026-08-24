import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../constants/app_constants.dart';
import '../providers/stats_providers.dart';
import '../repositories/stats_repository.dart';
import '../routes/app_router.dart';
import 'dashboard_components.dart';

class CoordinatorDashboard extends ConsumerWidget {
  const CoordinatorDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(staffStatsProvider).valueOrNull ?? DashboardStats.empty;

    return DashboardPage(
      title: 'Coordinator Workspace',
      subtitle: 'Monitor alumni outcomes, surveys, and campus engagement.',
      icon: Icons.analytics_outlined,
      accent: AppColors.success,
      children: [
        DashboardMetricGrid(
          metrics: [
            DashboardMetric('Total Alumni', '${stats.alumni}',
                Icons.groups_outlined, AppColors.primaryBlue),
            DashboardMetric('Verified Alumni', '${stats.verifiedAlumni}',
                Icons.verified_outlined, AppColors.success),
            DashboardMetric('Survey Completion',
                stats.surveyCount == 0
                    ? 'No surveys'
                    : '${stats.surveyCompletionRate.toStringAsFixed(0)}%',
                Icons.fact_check_outlined, AppColors.gold),
            DashboardMetric('Employment Rate',
                stats.alumni == 0
                    ? '—'
                    : '${stats.employmentRate.toStringAsFixed(0)}%',
                Icons.trending_up_rounded, AppColors.info),
            DashboardMetric('Pending Verification',
                '${stats.pendingAlumni}', Icons.pending_actions_outlined,
                AppColors.warning),
          ],
        ),
        const SizedBox(height: 14),
        DashboardSectionCard(
          title: 'Analytics Overview',
          icon: Icons.insights_outlined,
          action: TextButton(
            onPressed: () => context.go(AppRoutes.coordinatorAnalytics),
            child: const Text('View All'),
          ),
          child: _EmploymentBarChart(stats: stats),
        ),
        const SizedBox(height: 14),
        DashboardSectionCard(
          title: 'Management Tools',
          icon: Icons.admin_panel_settings_outlined,
          child: DashboardActionGrid(
            actions: [
              DashboardAction('Alumni', Icons.groups_outlined,
                  () => context.go('${AppRoutes.staffUsers}?role=alumni')),
              DashboardAction('Surveys', Icons.fact_check_outlined,
                  () => context.go(AppRoutes.collectionData('surveys'))),
              DashboardAction('Reports', Icons.assessment_outlined,
                  () => context.go(AppRoutes.collectionData('reports'))),
              DashboardAction('Events', Icons.event_outlined,
                  () => context.go(AppRoutes.collectionData('events'))),
              DashboardAction('Announcements', Icons.campaign_outlined,
                  () => context.go(
                      AppRoutes.collectionData('announcements'))),
              DashboardAction('Verify Alumni', Icons.verified_outlined,
                  () => context.go('${AppRoutes.staffUsers}?role=alumni')),
            ],
          ),
        ),
      ],
    );
  }
}

class _EmploymentBarChart extends StatelessWidget {
  final DashboardStats stats;

  const _EmploymentBarChart({required this.stats});

  @override
  Widget build(BuildContext context) {
    final items = <(String, double)>[
      ('Employed', stats.employed.toDouble()),
      ('Self-emp', stats.selfEmployed.toDouble()),
      ('Freelance', stats.freelance.toDouble()),
      ('Unemployed', stats.unemployed.toDouble()),
      ('Studying', stats.studying.toDouble()),
    ];
    final max = items.map((i) => i.$2).fold<double>(0, (a, b) => b > a ? b : a);
    final denominator = max == 0 ? 1.0 : max;

    if (stats.alumni == 0) {
      return const SizedBox(
        height: 150,
        child: Center(
          child: Text('No alumni records yet — the chart appears once '
              'alumni register.'),
        ),
      );
    }

    return SizedBox(
      height: 150,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final item in items)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      item.$2 == 0 ? '' : item.$2.toStringAsFixed(0),
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      height: (item.$2 / denominator) * 88,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [AppColors.primaryBlue, AppColors.secondaryBlue],
                        ),
                        borderRadius:
                            BorderRadius.vertical(top: Radius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.$1,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 9.5,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: .6),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}