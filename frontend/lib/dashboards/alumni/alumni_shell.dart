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
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: .34)
                : const Color(0xFF0B1F3A).withValues(alpha: .16),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            height: 78,
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 7),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF171B24).withValues(alpha: .94)
                  : Colors.white.withValues(alpha: .92),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: .10)
                    : Colors.white.withValues(alpha: .72),
              ),
            ),
            child: Row(
              children: List.generate(items.length, (index) {
                final item = items[index];
                final selected = selectedIndex == index;
                return Expanded(
                  child: Semantics(
                    button: true,
                    selected: selected,
                    label: item.label,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(22),
                        child: InkWell(
                          onTap: () => onSelected(index),
                          borderRadius: BorderRadius.circular(22),
                          splashColor: AppColors.secondaryBlue
                              .withValues(alpha: selected ? .20 : .13),
                          highlightColor:
                              AppColors.primaryBlue.withValues(alpha: .06),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeInOutCubic,
                            constraints: const BoxConstraints(minHeight: 58),
                            decoration: BoxDecoration(
                              color: selected ? item.color : null,
                              borderRadius: BorderRadius.circular(22),
                              boxShadow: selected
                                  ? [
                                      BoxShadow(
                                        color: item.color
                                            .withValues(alpha: .32),
                                        blurRadius: 14,
                                        offset: const Offset(0, 6),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Stack(
                                  clipBehavior: Clip.none,
                                  alignment: Alignment.center,
                                  children: [
                                    AnimatedScale(
                                      scale: selected ? 1 : .90,
                                      duration:
                                          const Duration(milliseconds: 250),
                                      curve: Curves.easeInOutCubic,
                                       child: Icon(
                                         selected
                                             ? item.activeIcon
                                             : item.icon,
                                         size: selected ? 28 : 24,
                                         color: selected
                                             ? Colors.white
                                             : inactiveColor,
                                       ),
                                     ),
                                     if ((item.path == AppRoutes.alumniNotifications && unreadCount > 0) ||
                                         (item.path == AppRoutes.alumniMessages && unreadMessages > 0))
                                       Positioned(
                                         right: -8,
                                         top: -6,
                                         child: Container(
                                           padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                                           decoration: BoxDecoration(
                                             color: AppColors.error,
                                             borderRadius: BorderRadius.circular(10),
                                             border: Border.all(
                                               color: isDark ? const Color(0xFF171B24) : Colors.white,
                                               width: 1.5,
                                             ),
                                           ),
                                           constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                                           child: Text(
                                             (item.path == AppRoutes.alumniMessages ? unreadMessages : unreadCount) > 99
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
                                     if (selected && item.sticker.isNotEmpty)
                                      Positioned(
                                        right: -10,
                                        top: -11,
                                        child: Container(
                                          padding: const EdgeInsets.all(2),
                                          decoration: BoxDecoration(
                                            color: isDark
                                                ? const Color(0xFF171B24)
                                                : Colors.white,
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black
                                                    .withValues(alpha: .18),
                                                blurRadius: 4,
                                              ),
                                            ],
                                          ),
                                          child: Text(
                                            item.sticker,
                                            style: const TextStyle(
                                                fontSize: 10),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                AnimatedDefaultTextStyle(
                                  duration: const Duration(milliseconds: 220),
                                  curve: Curves.easeInOut,
                                  style: TextStyle(
                                    color:
                                        selected ? Colors.white : inactiveColor,
                                    fontSize:
                                        item.label == 'Employment' ? 8.5 : 9.5,
                                    height: 1,
                                    fontWeight: selected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                  ),
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      item.label,
                                      maxLines: 1,
                                      softWrap: false,
                                    ),
                                  ),
                                ),
                              ],
                            ),
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
  const _AlumniShellNavItem(this.icon, this.activeIcon, this.label, this.path,
      this.color, {this.sticker = ''});

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String path;
  final Color color;

  /// Optional emoji "sticker" shown above the selected nav item.
  final String sticker;
}

const _alumniNavItems = [
  _AlumniShellNavItem(Icons.home_outlined, Icons.home_rounded, 'Home',
      AppRoutes.alumniDashboard, Color(0xFF2563EB),
      sticker: '\u{1F3E0}'),
  _AlumniShellNavItem(Icons.fact_check_outlined, Icons.fact_check_rounded,
      'Survey', AppRoutes.alumniSurvey, Color(0xFF0D9488),
      sticker: '\u{1F4C3}'),
  _AlumniShellNavItem(Icons.work_outline_rounded, Icons.work_rounded,
      'Employment', AppRoutes.alumniJobs, Color(0xFFD97706),
      sticker: '\u{1F4BC}'),
  _AlumniShellNavItem(Icons.chat_outlined, Icons.chat_rounded,
      'Messages', AppRoutes.alumniMessages, Color(0xFFF43F5E),
      sticker: '\u{1F4E9}'),
  _AlumniShellNavItem(
      Icons.notifications_none_rounded,
      Icons.notifications_rounded,
      'Notifications',
      AppRoutes.alumniNotifications,
      Color(0xFFA855F7),
      sticker: '\u{1F514}'),
  _AlumniShellNavItem(Icons.person_outline_rounded, Icons.person_rounded,
      'Profile', AppRoutes.alumniProfile, Color(0xFF06B6D4),
      sticker: '\u{1F464}'),
];

int _selectedIndex(String location, List<_AlumniShellNavItem> items) {
  final index = items.lastIndexWhere((item) => location.startsWith(item.path));
  return index < 0 ? 0 : index;
}
