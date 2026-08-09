import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../constants/app_constants.dart';
import '../models/user_model.dart';
import '../providers/auth_providers.dart';
import '../routes/app_router.dart';

class RoleDashboardShell extends ConsumerWidget {
  const RoleDashboardShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentUserProfileProvider).valueOrNull;
    final role = profile?.role ?? UserRole.guest;
    final items = _itemsFor(role);
    final currentLocation = GoRouterState.of(context).matchedLocation;
    final selected = _selectedIndex(currentLocation, items);

    if (role == UserRole.guest) {
      return Scaffold(body: SafeArea(child: child));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 900) {
          return Scaffold(
            body: SafeArea(
              child: Row(
                children: [
                  _RoleSidebar(role: role, items: items, selected: selected),
                  Expanded(
                    child: Column(
                      children: [
                        _RoleTopBar(role: role, profile: profile),
                        Expanded(child: child),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          body: SafeArea(child: child),
          extendBody: true,
          bottomNavigationBar: SafeArea(
            minimum: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: NavigationBar(
              height: 72,
              selectedIndex: selected,
              animationDuration: const Duration(milliseconds: 280),
              labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
              onDestinationSelected: (index) => context.go(items[index].path),
              destinations: [
                for (final item in items)
                  NavigationDestination(
                    icon: Icon(item.icon),
                    selectedIcon: Icon(item.selectedIcon, size: 28),
                    label: item.label,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  static int _selectedIndex(String location, List<_RoleNavItem> items) {
    final index = items.lastIndexWhere((item) => location.startsWith(item.path));
    return index < 0 ? 0 : index;
  }

  static List<_RoleNavItem> _itemsFor(UserRole role) {
    switch (role) {
      case UserRole.guest:
        return const [];
      case UserRole.alumni:
        return const [
          _RoleNavItem(Icons.home_outlined, Icons.home_rounded, 'Home', AppRoutes.alumniDashboard),
          _RoleNavItem(Icons.fact_check_outlined, Icons.fact_check_rounded, 'Survey', AppRoutes.alumniSurvey),
          _RoleNavItem(Icons.work_outline_rounded, Icons.work_rounded, 'Jobs', AppRoutes.alumniJobs),
          _RoleNavItem(Icons.notifications_none_rounded, Icons.notifications_rounded, 'Notifications', AppRoutes.alumniNotifications),
          _RoleNavItem(Icons.person_outline_rounded, Icons.person_rounded, 'Profile', AppRoutes.alumniProfile),
        ];
      case UserRole.coordinator:
        return const [
          _RoleNavItem(Icons.analytics_outlined, Icons.analytics_rounded, 'Overview', AppRoutes.coordinatorDashboard),
          _RoleNavItem(Icons.groups_outlined, Icons.groups_rounded, 'Alumni', AppRoutes.coordinatorAlumni),
          _RoleNavItem(Icons.fact_check_outlined, Icons.fact_check_rounded, 'Surveys', AppRoutes.coordinatorSurveys),
          _RoleNavItem(Icons.assessment_outlined, Icons.assessment_rounded, 'Reports', AppRoutes.coordinatorReports),
          _RoleNavItem(Icons.event_outlined, Icons.event_rounded, 'Events', AppRoutes.coordinatorEvents),
        ];
      case UserRole.admin:
        return const [
          _RoleNavItem(Icons.shield_outlined, Icons.shield_rounded, 'Overview', AppRoutes.adminDashboard),
          _RoleNavItem(Icons.people_outline_rounded, Icons.people_rounded, 'Users', AppRoutes.adminUsers),
          _RoleNavItem(Icons.analytics_outlined, Icons.analytics_rounded, 'Analytics', AppRoutes.adminAnalytics),
          _RoleNavItem(Icons.history_rounded, Icons.history_rounded, 'Audit Logs', AppRoutes.adminAuditLogs),
          _RoleNavItem(Icons.person_outline_rounded, Icons.person_rounded, 'Profile', AppRoutes.adminProfile),
        ];
    }
  }
}

class _RoleSidebar extends StatelessWidget {
  const _RoleSidebar({required this.role, required this.items, required this.selected});

  final UserRole role;
  final List<_RoleNavItem> items;
  final int selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 248,
      padding: const EdgeInsets.fromLTRB(17, 22, 17, 18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(right: BorderSide(color: AppColors.primaryBlue.withValues(alpha: .10))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text.rich(
            TextSpan(children: [
              TextSpan(text: 'Grad'),
              TextSpan(text: 'Track', style: TextStyle(color: AppColors.gold)),
            ]),
            style: TextStyle(color: AppColors.primaryBlue, fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            role.label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: .56),
                ),
          ),
          const SizedBox(height: 30),
          for (var i = 0; i < items.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Material(
                type: MaterialType.transparency,
                child: ListTile(
                  selected: i == selected,
                  selectedTileColor: AppColors.primaryBlue.withValues(alpha: .11),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  leading: Icon(i == selected ? items[i].selectedIcon : items[i].icon),
                  title: Text(items[i].label),
                  onTap: () => context.go(items[i].path),
                ),
              ),
            ),
          const Spacer(),
          const Text('BISU Bilar Campus', style: TextStyle(fontSize: 11)),
        ],
      ),
    );
  }
}

class _RoleTopBar extends StatelessWidget {
  const _RoleTopBar({required this.role, required this.profile});

  final UserRole role;
  final UserModel? profile;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(bottom: BorderSide(color: AppColors.primaryBlue.withValues(alpha: .10))),
      ),
      child: Row(
        children: [
          Text('${role.label} workspace', style: const TextStyle(fontWeight: FontWeight.w700)),
          const Spacer(),
          Text(profile?.fullName ?? 'GradTrack', style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _RoleNavItem {
  const _RoleNavItem(this.icon, this.selectedIcon, this.label, this.path);

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final String path;
}
