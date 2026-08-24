import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../constants/app_constants.dart';
import '../providers/stats_providers.dart';
import '../routes/app_router.dart';
import 'dashboard_components.dart';

class GuestDashboard extends ConsumerWidget {
  const GuestDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final announcements =
        ref.watch(publicAnnouncementsProvider).valueOrNull;

    return DashboardPage(
      title: 'Welcome to GradTrack',
      subtitle: 'Explore the BISU graduate community before you sign in.',
      icon: Icons.explore_outlined,
      accent: AppColors.secondaryBlue,
      children: [
        const DashboardSectionCard(
          title: 'About GradTrack',
          icon: Icons.school_outlined,
          child: Text(
            'A secure graduate tracking system connecting Bohol Island State University alumni with career, survey, and community opportunities.',
          ),
        ),
        const SizedBox(height: 14),
        const DashboardMetricGrid(
          metrics: [
            DashboardMetric(
              'Graduate community',
              'BISU',
              Icons.groups_outlined,
              AppColors.primaryBlue,
            ),
            DashboardMetric(
              'Campus',
              'Bilar',
              Icons.location_on_outlined,
              AppColors.gold,
            ),
            DashboardMetric(
              'Public events',
              'Open',
              Icons.event_available_outlined,
              AppColors.success,
            ),
            DashboardMetric(
              'Announcements',
              'Latest',
              Icons.campaign_outlined,
              AppColors.warning,
            ),
          ],
        ),
        const SizedBox(height: 14),
        DashboardActionGrid(
          actions: [
            DashboardAction('Login', Icons.login_rounded, () {
              context.go(AppRoutes.login);
            }),
            DashboardAction('Register', Icons.person_add_alt_1_rounded, () {
              context.go(AppRoutes.register);
            }),
            DashboardAction('Announcements', Icons.campaign_outlined, () {
              context.go(AppRoutes.collectionData('announcements'));
            }),
            DashboardAction('Events', Icons.event_outlined, () {
              context.go(AppRoutes.collectionData('events'));
            }),
            DashboardAction('About BISU', Icons.account_balance_outlined, () {
              context.go(AppRoutes.about);
            }),
            DashboardAction('Contact', Icons.mail_outline_rounded, () {
              context.go(AppRoutes.about);
            }),
          ],
        ),
        const SizedBox(height: 14),
        DashboardSectionCard(
          title: 'Public Announcements',
          icon: Icons.campaign_outlined,
          action: TextButton(
            onPressed: () =>
                context.go(AppRoutes.collectionData('announcements')),
            child: const Text('View All'),
          ),
          child: announcements == null || announcements.isEmpty
              ? const Text('No public announcements yet.')
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
                              child: Text(
                                item['title']?.toString() ?? 'Announcement',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 14),
        const DashboardSectionCard(
          title: 'Frequently Asked Questions',
          icon: Icons.help_outline_rounded,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Who can use GradTrack?'),
              SizedBox(height: 5),
              Text('BISU graduates and authorized university staff.'),
              SizedBox(height: 12),
              Text('How do I join?'),
              SizedBox(height: 5),
              Text('Create an account to begin your graduate profile.'),
            ],
          ),
        ),
      ],
    );
  }
}
