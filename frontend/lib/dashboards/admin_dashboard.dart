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
    final unreadMessages = ref.watch(unreadAdminMessagesCountProvider);

    return DashboardPage(
      title: 'Admin Command Center',
      subtitle: 'Manage GradTrack users, content, analytics, and security.',
      icon: Icons.shield_outlined,
      accent: AppColors.bisuBlue700,
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
              DashboardAction(
                unreadMessages > 0 ? 'Messages ($unreadMessages)' : 'Alumni Messages',
                Icons.chat_bubble_outline_rounded,
                () => context.push(AppRoutes.adminMessages),
              ),
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