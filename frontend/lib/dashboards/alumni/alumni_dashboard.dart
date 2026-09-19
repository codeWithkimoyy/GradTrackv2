import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../constants/app_constants.dart';
import '../../models/user_model.dart';
import '../../providers/messaging_providers.dart';
import '../../providers/notification_providers.dart';
import '../../providers/stats_providers.dart';
import '../../routes/app_router.dart';
import '../../widgets/campus_hero_banner.dart';
import 'alumni_components.dart';

class AlumniDashboard extends ConsumerWidget {
  const AlumniDashboard({super.key, required this.user});

  final UserModel user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final completion = UserModel.computeCompletion(user).round();
    final unreadCount = ref.watch(unreadCountProvider(user.uid));
    final unreadMessages =
        ref.watch(unreadAlumniMessagesCountProvider(user.uid));
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

    return AlumniDashboardPage(
      title: 'Welcome back, ${user.fullName.split(' ').first}',
      subtitle: 'Your personal graduate success dashboard.',
      icon: Icons.verified_user_outlined,
      accent: AppColors.bisuBlue700,
      children: [
        CampusHeroBanner(
          title: 'A graduate for a day.\nAn alumnus for life.',
          subtitle:
              'Keep your contact details and career milestones up to date to stay connected with Bohol Island State University and your cohort.',
          action: ElevatedButton.icon(
            onPressed: () => context.go(AppRoutes.alumniProfile),
            icon: const Icon(Icons.person_outline_rounded, size: 16),
            label: const Text('View Profile'),
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
        if (unreadCount > 0) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primaryBlue.withOpacity(0.15),
                  AppColors.secondaryBlue.withOpacity(0.08),
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
        if (unreadMessages > 0) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFF43F5E).withOpacity(0.15),
                  AppColors.primaryBlue.withOpacity(0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFFF43F5E).withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF43F5E),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.chat_bubble_rounded,
                      color: Colors.white, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'You have $unreadMessages unread message${unreadMessages > 1 ? 's' : ''} from Admin',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13.5,
                        ),
                      ),
                      const Text(
                        'The administrator has replied to your inquiry.',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: () => context.go(AppRoutes.alumniMessages),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF43F5E),
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
        AlumniSectionCard(
          title: 'Graduate Profile',
          icon: Icons.person_outline_rounded,
          action: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.14),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.success.withOpacity(0.3)),
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
                  alumniAvatar(user, radius: 31),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Text(
                      '${user.course ?? AppStrings.defaultCourse}\nGraduated ${user.graduationYear ?? 'year not set'}'
                      '${user.academicYearGraduated != null ? ' · AY ${user.academicYearGraduated}' : ''}'
                      ' · ${user.employmentStatus.label}',
                    ),
                  ),
                  Text(
                    '$completion%',
                    style: const TextStyle(
                      color: AppColors.bisuBlue700,
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
                  backgroundColor: AppColors.bisuBlue100.withOpacity(0.6),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.bisuBlue700),
                  minHeight: 6,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        AlumniMetricGrid(
          metrics: [
            AlumniMetric(
              'Profile Completion',
              '$completion%',
              Icons.account_circle_outlined,
              AppColors.bisuBlue700,
              onTap: () => context.go(AppRoutes.alumniProfile),
            ),
            AlumniMetric(
              'Survey Progress',
              surveyLabel,
              Icons.fact_check_outlined,
              AppColors.bisuBlue600,
              onTap: () => context.go(AppRoutes.alumniSurvey),
            ),
            AlumniMetric(
              'Employment Status',
              user.employmentStatus.label,
              Icons.work_outline_rounded,
              AppColors.bisuBlue500,
              onTap: () => context.push(AppRoutes.employment),
            ),
            AlumniMetric(
              'Notifications',
              unreadCount == 0 ? 'All read' : '$unreadCount new',
              Icons.notifications_none_rounded,
              AppColors.bisuBlue400,
              onTap: () => context.go(AppRoutes.alumniNotifications),
            ),
            AlumniMetric(
              'Messages',
              unreadMessages == 0 ? 'No unread' : '$unreadMessages unread',
              Icons.chat_outlined,
              AppColors.teal,
              onTap: () => context.go(AppRoutes.alumniMessages),
            ),
          ],
        ),
        const SizedBox(height: 14),
        AlumniSectionCard(
          title: 'Quick Actions',
          icon: Icons.bolt_outlined,
          child: AlumniActionGrid(
            actions: [
              AlumniAction('My Profile', Icons.person_outline_rounded,
                  () => context.go(AppRoutes.alumniProfile),
                  color: AppColors.primaryBlue),
              AlumniAction('Tracer Survey', Icons.fact_check_outlined,
                  () => context.go(AppRoutes.alumniSurvey),
                  color: const Color(0xFF10B981)),
              AlumniAction('Employment History', Icons.work_outline_rounded,
                  () => context.push(AppRoutes.employment),
                  color: const Color(0xFF0D9488)),
              AlumniAction(
                unreadMessages > 0
                    ? 'Messages ($unreadMessages)'
                    : 'Message Admin',
                Icons.chat_bubble_outline_rounded,
                () => context.go(AppRoutes.alumniMessages),
                color: const Color(0xFFF43F5E),
              ),
              AlumniAction('Notifications', Icons.notifications_none_rounded,
                  () => context.go(AppRoutes.alumniNotifications),
                  color: const Color(0xFF8B5CF6)),
              AlumniAction('Jobs & Careers', Icons.business_center_outlined,
                  () => context.go(AppRoutes.alumniJobs),
                  color: const Color(0xFFF59E0B)),
              AlumniAction('Events', Icons.event_outlined,
                  () => context.go(AppRoutes.collectionData('events')),
                  color: const Color(0xFF06B6D4)),
              AlumniAction('Certificates', Icons.workspace_premium_outlined,
                  () => context.go(AppRoutes.alumniDocuments),
                  color: const Color(0xFFEAB308)),
            ],
          ),
        ),
        const SizedBox(height: 14),
        AlumniSectionCard(
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