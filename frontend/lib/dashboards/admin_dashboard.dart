import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../constants/app_constants.dart';
import '../providers/stats_providers.dart';
import '../repositories/stats_repository.dart';
import '../routes/app_router.dart';
import '../widgets/pending_approvals_queue.dart';
import 'dashboard_components.dart';

class AdminDashboard extends ConsumerStatefulWidget {
  const AdminDashboard({super.key});

  @override
  ConsumerState<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends ConsumerState<AdminDashboard> {
  @override
  Widget build(BuildContext context) {
    final stats =
        ref.watch(staffStatsProvider).valueOrNull ?? DashboardStats.empty;

    return DashboardPage(
      title: 'Admin Command Center',
      subtitle: 'Manage GradTrack users, content, analytics, and security.',
      icon: Icons.shield_outlined,
      accent: AppColors.bisuBlue700,
      children: [
        PendingApprovalsQueue(
          onViewAll: () => context.go('${AppRoutes.staffUsers}?pending=1'),
        ),
        const SizedBox(height: 14),
        DashboardMetricGrid(
          metrics: [
            DashboardMetric('Total Users', '${stats.totalUsers}',
                Icons.people_outline_rounded, AppColors.bisuBlue700),
            DashboardMetric('Total Alumni', '${stats.alumni}',
                Icons.school_outlined, AppColors.bisuBlue600),
            DashboardMetric('Verified Alumni', '${stats.verifiedAlumni}',
                Icons.online_prediction_rounded, AppColors.bisuBlue500),
            DashboardMetric('Total Surveys', '${stats.surveyCount}',
                Icons.fact_check_outlined, AppColors.bisuBlue800),
            DashboardMetric('Completed Surveys', '${stats.responseCount}',
                Icons.task_alt_rounded, AppColors.bisuBlue400),
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
              DashboardAction('Alumni Management', Icons.badge_outlined,
                  () => context.go(AppRoutes.adminAlumni)),
              DashboardAction('Surveys', Icons.fact_check_outlined,
                  () => context.go(AppRoutes.collectionData('surveys'))),
              DashboardAction('Reports', Icons.assessment_outlined,
                  () => context.go(AppRoutes.collectionData('reports'))),
              DashboardAction('Employment', Icons.business_center_outlined,
                  () => context.go(AppRoutes.collectionData('jobs'))),
              DashboardAction('Announcements', Icons.campaign_outlined,
                  () => context.go(
                      AppRoutes.collectionData('announcements'))),
              DashboardAction('Events', Icons.event_outlined,
                  () => context.go(AppRoutes.collectionData('events'))),
              DashboardAction('Analytics', Icons.insights_outlined,
                  () => context.go(AppRoutes.adminAnalytics)),
              DashboardAction('Employment History', Icons.work_history_outlined,
                  () => context.go(AppRoutes.adminEmploymentHistory)),
              DashboardAction('Audit Logs', Icons.history_rounded,
                  () => context.go(AppRoutes.collectionData('audit_logs'))),
            ],
          ),
        ),
      ],
    );
  }
}