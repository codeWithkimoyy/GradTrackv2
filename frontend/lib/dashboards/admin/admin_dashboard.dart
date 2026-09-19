import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../constants/app_constants.dart';
import '../../providers/auth_providers.dart';
import '../../providers/messaging_providers.dart';
import '../../providers/stats_providers.dart';
import '../../repositories/stats_repository.dart';
import '../../routes/app_router.dart';
import '../../widgets/campus_hero_banner.dart';
import '../../widgets/pending_approvals_queue.dart';
import 'admin_components.dart';

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
    final user = ref.watch(currentUserProfileProvider).valueOrNull;
    final firstName = user?.fullName.split(' ').first ?? 'Admin';

    return AdminDashboardPage(
      title: 'Admin Command Center',
      subtitle: 'Manage GradTrack users, content, analytics, and security.',
      icon: Icons.shield_outlined,
      accent: AppColors.bisuBlue700,
      children: [
        CampusHeroBanner(
          title: 'Good morning, $firstName! 👋',
          subtitle:
              "Here's what's happening with your Bohol Island State University graduate community today.",
          action: ElevatedButton.icon(
            onPressed: () => context.push(AppRoutes.adminAlumni),
            icon: const Icon(Icons.school_rounded, size: 16),
            label: const Text('View Registry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.primaryBlue,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        if (unreadMessages > 0) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primaryBlue.withOpacity(0.15),
                  AppColors.teal.withOpacity(0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.primaryBlue.withOpacity(0.3),
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
        AdminMetricGrid(
          metrics: [
            AdminMetric('Total Users', '${stats.totalUsers}',
                Icons.people_outline_rounded, AppColors.bisuBlue700),
            AdminMetric('Alumni', '${stats.alumni}',
                Icons.school_outlined, AppColors.bisuBlue600),
            AdminMetric('Total Surveys', '${stats.surveyCount}',
                Icons.fact_check_outlined, AppColors.bisuBlue800),
            AdminMetric('Survey Responses', '${stats.responseCount}',
                Icons.task_alt_rounded, AppColors.bisuBlue400),
            AdminMetric('Total Events', '${stats.eventCount}',
                Icons.event_outlined, AppColors.gold),
            AdminMetric('Announcements', '${stats.announcementCount}',
                Icons.campaign_outlined, AppColors.warning),
          ],
        ),
      ],
    );
  }
}