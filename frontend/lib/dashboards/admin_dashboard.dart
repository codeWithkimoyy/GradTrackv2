import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../constants/app_constants.dart';
import '../providers/stats_providers.dart';
import '../repositories/stats_repository.dart';
import '../routes/app_router.dart';
import '../widgets/pending_approvals_queue.dart';
import 'dashboard_components.dart';

class AdminDashboard extends ConsumerWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(staffStatsProvider).valueOrNull ?? DashboardStats.empty;

    return DashboardPage(
      title: 'Admin Command Center',
      subtitle: 'Manage GradTrack users, content, analytics, and security.',
      icon: Icons.shield_outlined,
      accent: AppColors.primaryBlue,
      children: [
        PendingApprovalsQueue(
          onViewAll: () => context.go('${AppRoutes.staffUsers}?pending=1'),
        ),
        const SizedBox(height: 14),
        DashboardMetricGrid(
          metrics: [
            DashboardMetric('Total Users', '${stats.totalUsers}',
                Icons.people_outline_rounded, AppColors.primaryBlue),
            DashboardMetric('Total Alumni', '${stats.alumni}',
                Icons.school_outlined, AppColors.success),
            DashboardMetric('Coordinators', '${stats.coordinators}',
                Icons.badge_outlined, AppColors.gold),
            DashboardMetric('Active Users', '${stats.verifiedAlumni}',
                Icons.online_prediction_rounded, AppColors.warning),
            DashboardMetric('Total Surveys', '${stats.surveyCount}',
                Icons.fact_check_outlined, AppColors.primaryBlue),
            DashboardMetric('Completed Surveys', '${stats.responseCount}',
                Icons.task_alt_rounded, AppColors.success),
            DashboardMetric('Total Events', '${stats.eventCount}',
                Icons.event_outlined, AppColors.gold),
            DashboardMetric('Announcements', '${stats.announcementCount}',
                Icons.campaign_outlined, AppColors.warning),
          ],
        ),
        const SizedBox(height: 14),
        DashboardSectionCard(
          title: 'Administration',
          icon: Icons.settings_suggest_outlined,
          child: DashboardActionGrid(
            actions: [
              DashboardAction('Users', Icons.people_outline_rounded,
                  () => context.go(AppRoutes.staffUsers)),
              DashboardAction('Alumni', Icons.school_outlined,
                  () => context.go('${AppRoutes.staffUsers}?role=alumni')),
              DashboardAction('Coordinators', Icons.badge_outlined,
                  () =>
                      context.go('${AppRoutes.staffUsers}?role=coordinator')),
              DashboardAction('Surveys', Icons.fact_check_outlined,
                  () => context.go(AppRoutes.collectionData('surveys'))),
              DashboardAction('Reports', Icons.assessment_outlined,
                  () => context.go(AppRoutes.collectionData('reports'))),
              DashboardAction('Announcements', Icons.campaign_outlined,
                  () => context.go(
                      AppRoutes.collectionData('announcements'))),
              DashboardAction('Events', Icons.event_outlined,
                  () => context.go(AppRoutes.collectionData('events'))),
              DashboardAction('Analytics', Icons.insights_outlined,
                  () => context.go(AppRoutes.adminAnalytics)),
              DashboardAction('Audit Logs', Icons.history_rounded,
                  () => context.go(AppRoutes.collectionData('audit_logs'))),
            ],
          ),
        ),
      ],
    );
  }
}