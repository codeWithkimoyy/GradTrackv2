import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../constants/app_constants.dart';
import '../providers/messaging_providers.dart';
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
    final unreadMessages = ref.watch(unreadAdminMessagesCountProvider);

    return DashboardPage(
      title: 'Admin Command Center',
      subtitle: 'Manage GradTrack users, content, analytics, and security.',
      icon: Icons.shield_outlined,
      accent: AppColors.primaryBlue,
      children: [
        if (unreadMessages > 0) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primaryBlue.withValues(alpha: 0.15),
                  AppColors.teal.withValues(alpha: 0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.primaryBlue.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: AppColors.primaryBlue,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.chat_rounded,
                      color: Colors.white, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'You have $unreadMessages unread alumni message${unreadMessages > 1 ? 's' : ''}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13.5,
                        ),
                      ),
                      const Text(
                        'Alumni have submitted inquiries or requested assistance.',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: () => context.push(AppRoutes.adminMessages),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Reply', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],
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
              DashboardAction(
                unreadMessages > 0 ? 'Messages ($unreadMessages)' : 'Alumni Messages',
                Icons.chat_bubble_outline_rounded,
                () => context.push(AppRoutes.adminMessages),
              ),
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