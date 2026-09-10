import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../constants/app_constants.dart';
import '../models/user_model.dart';
import '../providers/notification_providers.dart';
import '../providers/stats_providers.dart';
import '../routes/app_router.dart';
import 'dashboard_components.dart';

class AlumniDashboard extends ConsumerWidget {
  const AlumniDashboard({super.key, required this.user});

  final UserModel user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final completion = UserModel.computeCompletion(user).round();
    final unreadCount = ref.watch(unreadCountProvider(user.uid));
    final surveyProgress =
        ref.watch(surveyProgressProvider(user.uid)).valueOrNull;
    final announcements = ref
        .watch(announcementsProvider)
        .valueOrNull;

    final surveyLabel = surveyProgress == null
        ? '—'
        : !surveyProgress.hasSurveys
            ? 'None yet'
            : '${surveyProgress.completed}/${surveyProgress.total}';

    return DashboardPage(
      title: 'Welcome back, ${user.fullName}',
      subtitle: 'Your personal graduate success dashboard.',
      icon: Icons.verified_user_outlined,
      accent: AppColors.primaryBlue,
      children: [
        if (unreadCount > 0) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primaryBlue.withValues(alpha: 0.15),
                  AppColors.secondaryBlue.withValues(alpha: 0.08),
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
                  child: const Icon(Icons.notifications_active_rounded,
                      color: Colors.white, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'You have $unreadCount unread notification${unreadCount > 1 ? 's' : ''}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13.5,
                        ),
                      ),
                      const Text(
                        'Stay updated with announcements and tracer activity.',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: () => context.go(AppRoutes.alumniNotifications),
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
                  child: const Text('View', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],
        DashboardSectionCard(
          title: 'Graduate Profile',
          icon: Icons.person_outline_rounded,
          action: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.verified_rounded, size: 13, color: AppColors.success),
                SizedBox(width: 4),
                Text(
                  'Verified Alumni',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.success,
                  ),
                ),
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  profileAvatar(user, radius: 31),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Text(
                      '${user.course ?? 'Program not set'}\nGraduated ${user.graduationYear ?? 'year not set'}'
                      '${user.academicYearGraduated != null ? ' · AY ${user.academicYearGraduated}' : ''}'
                      ' · ${user.employmentStatus.label}',
                    ),
                  ),
                  Text(
                    '$completion%',
                    style: const TextStyle(
                      color: AppColors.primaryBlue,
                      fontSize: 21,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: completion / 100,
                  backgroundColor: AppColors.borderLight.withValues(alpha: 0.5),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.primaryBlue),
                  minHeight: 6,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        DashboardMetricGrid(
          metrics: [
            DashboardMetric(
              'Profile Completion',
              '$completion%',
              Icons.account_circle_outlined,
              AppColors.primaryBlue,
              onTap: () => context.go(AppRoutes.alumniProfile),
            ),
            DashboardMetric(
              'Survey Progress',
              surveyLabel,
              Icons.fact_check_outlined,
              AppColors.success,
              onTap: () => context.go(AppRoutes.alumniSurvey),
            ),
            DashboardMetric(
              'Employment Status',
              user.employmentStatus.label,
              Icons.work_outline_rounded,
              AppColors.gold,
              onTap: () => context.push(AppRoutes.employment),
            ),
            DashboardMetric(
              'Notifications',
              unreadCount == 0 ? 'All read' : '$unreadCount new',
              Icons.notifications_none_rounded,
              AppColors.warning,
              onTap: () => context.go(AppRoutes.alumniNotifications),
            ),
          ],
        ),
        const SizedBox(height: 14),
        DashboardSectionCard(
          title: 'Quick Actions',
          icon: Icons.bolt_outlined,
          child: DashboardActionGrid(
            actions: [
              DashboardAction('My Profile', Icons.person_outline_rounded,
                  () => context.go(AppRoutes.alumniProfile)),
              DashboardAction('Tracer Survey', Icons.fact_check_outlined,
                  () => context.go(AppRoutes.alumniSurvey)),
              DashboardAction('Employment History', Icons.work_outline_rounded,
                  () => context.push(AppRoutes.employment)),
              DashboardAction('Message Admin', Icons.chat_outlined,
                  () => context.push('/messages')),
              DashboardAction('Notifications', Icons.notifications_none_rounded,
                  () => context.go(AppRoutes.alumniNotifications)),
              DashboardAction('Job Opportunities', Icons.business_center_outlined,
                  () => context.go(AppRoutes.collectionData('jobs'))),
              DashboardAction('Events', Icons.event_outlined,
                  () => context.go(AppRoutes.collectionData('events'))),
              DashboardAction('Certificates', Icons.workspace_premium_outlined,
                  () => context.go(AppRoutes.alumniDocuments)),
            ],
          ),
        ),
        const SizedBox(height: 14),
        DashboardSectionCard(
          title: 'Recent Announcements',
          icon: Icons.campaign_outlined,
          action: TextButton(
            onPressed: () =>
                context.go(AppRoutes.collectionData('announcements')),
            child: const Text('View All'),
          ),
          child: announcements == null || announcements.isEmpty
              ? const Text('No announcements posted yet.')
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final item in announcements.take(3))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.campaign_outlined,
                                size: 18, color: AppColors.gold),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item['title']?.toString() ??
                                        'Announcement',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600),
                                  ),
                                  if (item['description'] != null)
                                    Text(
                                      item['description'].toString(),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 12.5,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}