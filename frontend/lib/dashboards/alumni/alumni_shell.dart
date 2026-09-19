import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../constants/app_constants.dart';
import '../../providers/auth_providers.dart';
import '../../providers/execution_trace_provider.dart';
import '../../providers/messaging_providers.dart';
import '../../providers/notification_providers.dart';
import '../../routes/app_router.dart';

/// Mobile app-style shell for alumni: bottom navigation, regardless of
/// viewport width. Alumni-only; the admin shell lives in
/// `dashboards/admin/admin_shell.dart`.
class AlumniShell extends ConsumerWidget {
  final Widget child;
  const AlumniShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const items = _alumniNavItems;
    final location = GoRouterState.of(context).matchedLocation;
    final selected = _selectedIndex(location, items);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    void navigate(int index) {
      final path = items[index].path;
      ref.read(traceRecorderProvider).record(
            '[Nav] ${items[index].label}',
            TracePhase.call,
            detail: path,
          );
      context.go(path);
    }

    return Scaffold(
      backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      body: SafeArea(
        child: child,
      ),
      extendBody: true,
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        child: _AlumniBottomNavigation(
          items: items,
          selectedIndex: selected,
          onSelected: navigate,
        ),
      ),
    );
  }
}

class _AlumniBottomNavigation extends ConsumerWidget {
  const _AlumniBottomNavigation({
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<_AlumniShellNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inactiveColor =
        isDark ? Colors.white.withValues(alpha: .68) : const Color(0xFF667085);
    final user = ref.watch(currentUserProfileProvider).valueOrNull;
    final unreadCount = user != null
        ? ref.watch(unreadCountProvider(user.uid))
        : 0;
    final unreadMessages = user != null
        ? ref.watch(unreadAlumniMessagesCountProvider(user.uid))
        : 0;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: .40)
                : const Color(0xFF0B1F3A).withValues(alpha: .12),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            height: 72,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF131720).withValues(alpha: .96)
                  : Colors.white.withValues(alpha: .96),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: .08)
                    : AppColors.outlineCard,
                width: 1.5,
              ),
            ),
            child: Row(
              children: List.generate(items.length, (index) {
                final item = items[index];
                final selected = selectedIndex == index;
                final activeColor = item.color;

                return Expanded(
                  child: Semantics(
                    button: true,
                    selected: selected,
                    label: item.label,
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(18),
                      child: InkWell(
                        onTap: () => onSelected(index),
                        borderRadius: BorderRadius.circular(18),
                        splashColor: activeColor.withValues(alpha: .14),
                        highlightColor: activeColor.withValues(alpha: .06),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutCubic,
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Stack(
                                clipBehavior: Clip.none,
                                alignment: Alignment.center,
                                children: [
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 220),
                                    curve: Curves.easeOutCubic,
                                    padding: EdgeInsets.symmetric(
                                      horizontal: selected ? 14 : 6,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: selected
                                          ? activeColor.withValues(
                                              alpha: isDark ? .22 : .12,
                                            )
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Icon(
                                      selected ? item.activeIcon : item.icon,
                                      size: 22,
                                      color: selected
                                          ? activeColor
                                          : inactiveColor,
                                    ),
                                  ),
                                  if ((item.path == AppRoutes.alumniNotifications && unreadCount > 0) ||
                                      (item.path == AppRoutes.alumniMessages && unreadMessages > 0))
                                    Positioned(
                                      right: selected ? 4 : -4,
                                      top: -2,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 4, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: AppColors.error,
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          border: Border.all(
                                            color: isDark
                                                ? const Color(0xFF131720)
                                                : Colors.white,
                                            width: 1.5,
                                          ),
                                        ),
                                        constraints: const BoxConstraints(
                                            minWidth: 16, minHeight: 16),
                                        child: Text(
                                          (item.path == AppRoutes.alumniMessages
                                                      ? unreadMessages
                                                      : unreadCount) >
                                                  99
                                              ? '99+'
                                              : '${item.path == AppRoutes.alumniMessages ? unreadMessages : unreadCount}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 9,
                                            fontWeight: FontWeight.w700,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                item.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: selected
                                      ? (isDark ? Colors.white : activeColor)
                                      : inactiveColor,
                                  fontSize: 10,
                                  fontWeight: selected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _AlumniShellNavItem {
  const _AlumniShellNavItem(
      this.icon, this.activeIcon, this.label, this.path, this.color);

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String path;
  final Color color;
}

const _alumniNavItems = [
  _AlumniShellNavItem(Icons.home_outlined, Icons.home_rounded, 'Home',
      AppRoutes.alumniDashboard, AppColors.primaryBlue),
  _AlumniShellNavItem(Icons.fact_check_outlined, Icons.fact_check_rounded,
      'Survey', AppRoutes.alumniSurvey, Color(0xFF0D9488)),
  _AlumniShellNavItem(Icons.work_outline_rounded, Icons.work_rounded,
      'Jobs', AppRoutes.alumniJobs, Color(0xFFD97706)),
  _AlumniShellNavItem(Icons.chat_bubble_outline_rounded,
      Icons.chat_bubble_rounded, 'Messages', AppRoutes.alumniMessages,
      Color(0xFFF43F5E)),
  _AlumniShellNavItem(Icons.notifications_none_rounded,
      Icons.notifications_rounded, 'Alerts', AppRoutes.alumniNotifications,
      Color(0xFFA855F7)),
  _AlumniShellNavItem(Icons.person_outline_rounded, Icons.person_rounded,
      'Profile', AppRoutes.alumniProfile, Color(0xFF06B6D4)),
];

int _selectedIndex(String location, List<_AlumniShellNavItem> items) {
  final index = items.lastIndexWhere((item) => location.startsWith(item.path));
  return index < 0 ? 0 : index;
}
