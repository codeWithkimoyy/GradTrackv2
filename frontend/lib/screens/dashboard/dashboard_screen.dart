import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_constants.dart';
import '../../models/user_model.dart';
import '../../providers/auth_providers.dart';
import '../../providers/execution_trace_provider.dart';
import '../../providers/notification_providers.dart';
import '../../routes/app_router.dart';
import '../../utils/app_snack_bar.dart';
import '../../utils/avatar_utils.dart';
import '../../widgets/dashboard_stat_card.dart';
import '../../widgets/notification_bell.dart';
import '../../widgets/profile_menu.dart';
import '../../widgets/empty_state_widget.dart';
import '../../widgets/execution_trace_button.dart';
import '../../widgets/theme_toggle_button.dart';

class DashboardShell extends ConsumerWidget {
  final Widget child;
  const DashboardShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentUserProfileProvider).valueOrNull;
    final role = profile?.role ?? UserRole.guest;
    final items = _navItemsForRole(role);
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

    if (items.isEmpty) {
      return Scaffold(
        backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        body: SafeArea(
          child: _withFloatingThemeToggle(context, child),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 900;
        if (desktop) {
          return Scaffold(
            backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
            body: SafeArea(
              child: Row(
                children: [
                  _DesktopSidebar(
                    items: items,
                    selectedIndex: selected,
                    onSelected: navigate,
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        const _DesktopTopBar(),
                        Expanded(
                          child: ColoredBox(
                            color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                            child: child,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
          body: SafeArea(
            child: _withFloatingThemeToggle(context, child),
          ),
          extendBody: true,
          bottomNavigationBar: SafeArea(
            minimum: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: _PremiumBottomNavigation(
              items: items,
              selectedIndex: selected,
              onSelected: navigate,
            ),
          ),
        );
      },
    );
  }
}

class _PremiumBottomNavigation extends StatelessWidget {
  const _PremiumBottomNavigation({
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<_ShellNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inactiveColor =
        isDark ? Colors.white.withValues(alpha: .68) : const Color(0xFF667085);

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
                              gradient: selected
                                  ? const LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Color(0xFF3978F6),
                                        Color(0xFF1E40AF),
                                      ],
                                    )
                                  : null,
                              borderRadius: BorderRadius.circular(22),
                              boxShadow: selected
                                  ? [
                                      BoxShadow(
                                        color: AppColors.primaryBlue
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
                                AnimatedScale(
                                  scale: selected ? 1 : .90,
                                  duration: const Duration(milliseconds: 250),
                                  curve: Curves.easeInOutCubic,
                                  child: Icon(
                                    selected ? item.activeIcon : item.icon,
                                    size: selected ? 28 : 24,
                                    color:
                                        selected ? Colors.white : inactiveColor,
                                  ),
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

class _ShellNavItem {
  const _ShellNavItem(this.icon, this.activeIcon, this.label, this.path);

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String path;
}

List<_ShellNavItem> _navItemsForRole(UserRole role) => switch (role) {
      UserRole.guest => const [],
      UserRole.alumni => const [
        _ShellNavItem(
            Icons.home_outlined, Icons.home_rounded, 'Home', AppRoutes.alumniDashboard),
        _ShellNavItem(
            Icons.fact_check_outlined, Icons.fact_check_rounded, 'Survey', AppRoutes.alumniSurvey),
        _ShellNavItem(
            Icons.work_outline_rounded, Icons.work_rounded, 'Jobs', AppRoutes.alumniJobs),
        _ShellNavItem(
            Icons.notifications_none_rounded, Icons.notifications_rounded, 'Notifications', AppRoutes.alumniNotifications),
        _ShellNavItem(
            Icons.person_outline_rounded, Icons.person_rounded, 'Profile', AppRoutes.alumniProfile),
      ],
      UserRole.coordinator => const [
        _ShellNavItem(
            Icons.analytics_outlined, Icons.analytics_rounded, 'Overview', AppRoutes.coordinatorDashboard),
        _ShellNavItem(
            Icons.groups_outlined, Icons.groups_rounded, 'Alumni', AppRoutes.coordinatorAlumni),
        _ShellNavItem(
            Icons.fact_check_outlined, Icons.fact_check_rounded, 'Surveys', AppRoutes.coordinatorSurveys),
        _ShellNavItem(
            Icons.assessment_outlined, Icons.assessment_rounded, 'Reports', AppRoutes.coordinatorReports),
        _ShellNavItem(
            Icons.event_outlined, Icons.event_rounded, 'Events', AppRoutes.coordinatorEvents),
      ],
      UserRole.admin => const [
        _ShellNavItem(
            Icons.shield_outlined, Icons.shield_rounded, 'Overview', AppRoutes.adminDashboard),
        _ShellNavItem(
            Icons.people_outline_rounded, Icons.people_rounded, 'Users', AppRoutes.adminUsers),
        _ShellNavItem(
            Icons.analytics_outlined, Icons.analytics_rounded, 'Analytics', AppRoutes.adminAnalytics),
        _ShellNavItem(
            Icons.history_rounded, Icons.history_rounded, 'Audit Logs', AppRoutes.adminAuditLogs),
        _ShellNavItem(
            Icons.person_outline_rounded, Icons.person_rounded, 'Profile', AppRoutes.adminProfile),
      ],
    };

Widget _withFloatingThemeToggle(BuildContext context, Widget child) {
  return Stack(
    children: [
      child,
      const Positioned(
        top: 8,
        left: 14,
        child: ExecutionTraceButton(floating: true),
      ),
      const Positioned(
        top: 8,
        right: 14,
        child: ThemeToggleButton(floating: true),
      ),
    ],
  );
}

int _selectedIndex(String location, List<_ShellNavItem> items) {
  final index = items.lastIndexWhere((item) => location.startsWith(item.path));
  return index < 0 ? 0 : index;
}

class _DesktopSidebar extends StatelessWidget {
  const _DesktopSidebar({
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<_ShellNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: 260,
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDarkAlt : Colors.white,
        border: Border(
          right: BorderSide(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
            width: 1,
          ),
        ),
        boxShadow: isDark
            ? []
            : const [
                BoxShadow(
                  color: Color(0x080F172A),
                  blurRadius: 20,
                  offset: Offset(4, 0),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Logo & Branding Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.cardDark : AppColors.surfaceLightAlt,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? AppColors.borderDark : AppColors.borderLight,
                    ),
                  ),
                  child: Image.asset(
                    'assets/images/logo_full.png',
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: 'Grad',
                              style: GoogleFonts.poppins(
                                color: isDark ? Colors.white : AppColors.primaryNavy,
                              ),
                            ),
                            const TextSpan(
                              text: 'Track',
                              style: TextStyle(color: AppColors.goldDark),
                            ),
                          ],
                        ),
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'BISU ALUMNI PORTAL',
                        style: GoogleFonts.poppins(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.teal,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // Menu Section Label
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              'NAVIGATION',
              style: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                letterSpacing: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Navigation List
          Expanded(
            child: ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 4),
              itemBuilder: (context, index) {
                final item = items[index];
                final selected = selectedIndex == index;

                return _SidebarMenuItem(
                  icon: selected ? item.activeIcon : item.icon,
                  label: item.label,
                  selected: selected,
                  onTap: () => onSelected(index),
                );
              },
            ),
          ),

          // Integrated Secure Portal Footer Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? AppColors.cardDark : AppColors.primarySoft,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? AppColors.borderDark : AppColors.borderLight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.gold.withValues(alpha: 0.20),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.verified_user_rounded,
                        color: AppColors.goldDark,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'BISU Alumni Network',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : AppColors.primaryNavy,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Official & Encrypted Portal for BISU Graduates.',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'System Online',
                      style: GoogleFonts.poppins(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarMenuItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SidebarMenuItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_SidebarMenuItem> createState() => _SidebarMenuItemState();
}

class _SidebarMenuItemState extends State<_SidebarMenuItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color backgroundColor;
    if (widget.selected) {
      backgroundColor = AppColors.primaryBlue;
    } else {
      backgroundColor = _isHovered
          ? (isDark ? AppColors.cardDark : AppColors.surfaceLightAlt)
          : Colors.transparent;
    }

    final textColor = widget.selected
        ? Colors.white
        : (_isHovered
            ? (isDark ? Colors.white : AppColors.primaryNavy)
            : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)));

    final iconColor = widget.selected
        ? Colors.white
        : (_isHovered ? AppColors.primaryBlue : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)));

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: widget.selected
                  ? AppColors.primaryBlue
                  : (_isHovered
                      ? (isDark ? AppColors.borderDark : AppColors.borderLight)
                      : Colors.transparent),
            ),
            boxShadow: widget.selected
                ? [
                    BoxShadow(
                      color: AppColors.primaryBlue.withValues(alpha: 0.30),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [],
          ),
          child: Row(
            children: [
              Icon(widget.icon, color: iconColor, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.label,
                  style: GoogleFonts.poppins(
                    color: textColor,
                    fontSize: 13,
                    fontWeight:
                        widget.selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
              if (widget.selected)
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: AppColors.gold,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DesktopTopBar extends ConsumerWidget {
  const _DesktopTopBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProfileProvider).valueOrNull;
    final initials = _desktopInitials(user?.fullName ?? 'User');
    final photo = user?.photoUrl;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Breadcrumb / Context Title
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Graduate Tracking System',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : AppColors.primaryNavy,
                ),
              ),
              const SizedBox(height: 1),
              Row(
                children: [
                  Text(
                    'Bohol Island State University',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppColors.teal.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Main Campus',
                      style: GoogleFonts.poppins(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.teal,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Spacer(),

          // Execution Trace
          const ExecutionTraceButton(),
          const SizedBox(width: 6),

          // Theme Toggle
          const ThemeToggleButton(),
          const SizedBox(width: 14),

          // Notification Bell
          if (user != null) NotificationBell(userId: user.uid),
          const SizedBox(width: 14),

          // User Avatar & Profile Dropdown
          if (user != null)
            ProfileMenu(
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.cardDark : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark ? AppColors.borderDark : AppColors.borderLight,
                    ),
                    boxShadow: isDark
                        ? []
                        : [
                            const BoxShadow(
                              color: Color(0x0A0F172A),
                              blurRadius: 10,
                              offset: Offset(0, 2),
                            ),
                          ],
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: AppColors.primaryBlue,
                        backgroundImage: photo != null ? avatarProvider(photo) : null,
                        child: photo == null
                            ? Text(
                                initials,
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            user.fullName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : AppColors.primaryNavy,
                            ),
                          ),
                          Text(
                            user.role.label,
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              color: AppColors.teal,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

String _desktopInitials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.length > 1) {
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
  return name.isEmpty ? 'U' : name[0].toUpperCase();
}

class DashboardHomeTab extends ConsumerWidget {
  const DashboardHomeTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentUserProfileProvider);
    return profileAsync.when(
      data: (user) {
        if (user == null) {
          return const EmptyStateWidget(
            icon: Icons.person_off_rounded,
            title: 'No Profile Found',
            message: 'Complete registration to access your alumni dashboard.',
          );
        }
        return _DashboardBody(user: user);
      },
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.primaryBlue),
      ),
      error: (e, _) => _buildErrorState(e),
    );
  }
}

Widget _buildErrorState(Object error) {
  final msg = error.toString();
  final isFirestore = msg.contains('Firestore') || msg.contains('firestore');
  return EmptyStateWidget(
    icon: Icons.cloud_off_rounded,
    title: 'Could Not Load Profile',
    message: isFirestore
        ? 'Firestore connection is currently blocked. Please check your connection or ad blocker settings and reload.'
        : msg,
  );
}

class DashboardAlumniTab extends ConsumerWidget {
  const DashboardAlumniTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentUserProfileProvider);
    return profileAsync.when(
      data: (user) {
        if (user == null) {
          return const EmptyStateWidget(
            icon: Icons.person_off_rounded,
            title: 'No Profile Found',
            message: 'Complete registration to view the alumni directory.',
          );
        }
        return _AlumniTab(user: user);
      },
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.primaryBlue),
      ),
      error: (e, _) => _buildErrorState(e),
    );
  }
}

class DashboardJobsTab extends ConsumerWidget {
  const DashboardJobsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentUserProfileProvider);
    return profileAsync.when(
      data: (user) {
        if (user == null) {
          return const EmptyStateWidget(
            icon: Icons.person_off_rounded,
            title: 'No Profile Found',
            message: 'Complete registration to view employment records.',
          );
        }
        return _JobsTab(user: user);
      },
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.primaryBlue),
      ),
      error: (e, _) => _buildErrorState(e),
    );
  }
}

class DashboardDocumentsTab extends ConsumerWidget {
  const DashboardDocumentsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentUserProfileProvider);
    return profileAsync.when(
      data: (user) {
        if (user == null) {
          return const EmptyStateWidget(
            icon: Icons.person_off_rounded,
            title: 'No Profile Found',
            message: 'Complete registration to access your documents vault.',
          );
        }
        return _DocumentsTab(user: user);
      },
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.primaryBlue),
      ),
      error: (e, _) => _buildErrorState(e),
    );
  }
}

class _AnimatedEntrance extends StatefulWidget {
  final Widget child;
  final int delayMs;

  const _AnimatedEntrance({required this.child, this.delayMs = 0});

  @override
  State<_AnimatedEntrance> createState() => _AnimatedEntranceState();
}

class _AnimatedEntranceState extends State<_AnimatedEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<double> _scale;
  late final Animation<Offset> _offset;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _opacity = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _scale = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    ).drive(Tween<double>(begin: 0.97, end: 1.0));
    _offset = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    Future.delayed(Duration(milliseconds: widget.delayMs), () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _offset.value.dy * 20),
          child: Transform.scale(
            scale: _scale.value,
            child: Opacity(
              opacity: _opacity.value,
              child: widget.child,
            ),
          ),
        );
      },
    );
  }
}

class _DashboardBody extends ConsumerWidget {
  final UserModel user;
  const _DashboardBody({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final completion = UserModel.computeCompletion(user);
    final unreadCount = ref.watch(unreadCountProvider(user.uid));
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good Morning'
        : hour < 18
            ? 'Good Afternoon'
            : 'Good Evening';

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 1000;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Welcome Greeting Banner
              _AnimatedEntrance(
                delayMs: 40,
                child: _buildWelcomeBanner(context, greeting),
              ),
              const SizedBox(height: 20),

              // 2. Overview KPI Cards Grid
              _AnimatedEntrance(
                delayMs: 100,
                child: LayoutBuilder(
                  builder: (context, cardConstraints) {
                    final width = cardConstraints.maxWidth;
                    final crossAxisCount = width >= 1100
                        ? 4
                        : width >= 650
                            ? 2
                            : 1;

                    final aspectRatio = crossAxisCount == 4
                        ? 1.55
                        : crossAxisCount == 2
                            ? 1.65
                            : 2.2;

                    return GridView.count(
                      crossAxisCount: crossAxisCount,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: aspectRatio,
                      children: [
                        DashboardStatCard(
                          title: 'Employment Status',
                          value: user.employmentStatus.label,
                          icon: Icons.work_rounded,
                          color: user.employmentStatus == EmploymentStatus.employed
                              ? AppColors.success
                              : AppColors.warning,
                          badgeLabel: user.employmentStatus == EmploymentStatus.employed
                              ? 'Active'
                              : 'Needs Update',
                          badgeColor: user.employmentStatus == EmploymentStatus.employed
                              ? AppColors.success
                              : AppColors.warning,
                          actionLabel: 'Update',
                          onTap: () => context.push(AppRoutes.employment),
                        ),
                        DashboardStatCard(
                          title: 'Tracer Survey Progress',
                          value: '2 / 3 Completed',
                          icon: Icons.fact_check_rounded,
                          color: AppColors.teal,
                          progressValue: 0.66,
                          badgeLabel: '1 Pending',
                          badgeColor: AppColors.goldDark,
                          actionLabel: 'Take Survey',
                          onTap: () => showAppSnackBar(
                            context,
                            'Tracer survey form loaded',
                            duration: const Duration(seconds: 2),
                          ),
                        ),
                        const DashboardStatCard(
                          title: 'Upcoming Alumni Events',
                          value: '3 Events',
                          icon: Icons.event_available_rounded,
                          color: AppColors.goldDark,
                          subtitle: 'Next: Grand Homecoming 2026',
                          badgeLabel: '2 Scheduled',
                          badgeColor: AppColors.goldDark,
                        ),
                        DashboardStatCard(
                          title: 'Notifications & Alerts',
                          value: unreadCount == 0 ? 'All Read' : '$unreadCount New',
                          icon: Icons.notifications_active_rounded,
                          color: unreadCount == 0 ? AppColors.success : AppColors.primaryBlue,
                          subtitle: 'System announcements & updates',
                          badgeLabel: 'Live Feed',
                          badgeColor: AppColors.primaryBlue,
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),

              // 3. Profile Completion & Next Steps Checklist
              _AnimatedEntrance(
                delayMs: 180,
                child: _buildProfileCompletionChecklist(context, completion),
              ),
              const SizedBox(height: 24),

              // 4. Quick Actions Row
              _AnimatedEntrance(
                delayMs: 240,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Quick Actions',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : AppColors.primaryNavy,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Shortcuts to update records, upload documents, and manage your account.',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 104,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        children: [
                          _QuickActionCard(
                            icon: Icons.add_business_rounded,
                            label: 'Log Employment',
                            color: AppColors.primaryBlue,
                            onTap: () => context.push(AppRoutes.addEmployment),
                          ),
                          const SizedBox(width: 12),
                          _QuickActionCard(
                            icon: Icons.upload_file_rounded,
                            label: 'Upload Resume',
                            color: AppColors.teal,
                            onTap: () => context.push(AppRoutes.resume),
                          ),
                          const SizedBox(width: 12),
                          _QuickActionCard(
                            icon: Icons.workspace_premium_rounded,
                            label: 'Add Certificate',
                            color: AppColors.goldDark,
                            onTap: () => context.push(AppRoutes.certificates),
                          ),
                          const SizedBox(width: 12),
                          _QuickActionCard(
                            icon: Icons.assignment_turned_in_rounded,
                            label: 'Tracer Survey',
                            color: AppColors.secondaryBlue,
                            onTap: () => showAppSnackBar(
                              context,
                              'Graduate Tracer Survey is active',
                              duration: const Duration(seconds: 2),
                            ),
                          ),
                          const SizedBox(width: 12),
                          _QuickActionCard(
                            icon: Icons.edit_rounded,
                            label: 'Edit Profile',
                            color: const Color(0xFFA855F7),
                            onTap: () => context.push(AppRoutes.editProfile),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // 5. Main Split Section (Announcements + Alumni Quick Summary)
              _AnimatedEntrance(
                delayMs: 300,
                child: isWide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 3,
                            child: _buildAnnouncementsSection(context),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            flex: 2,
                            child: _buildAlumniSummaryCard(context),
                          ),
                        ],
                      )
                    : Column(
                        children: [
                          _buildAnnouncementsSection(context),
                          const SizedBox(height: 24),
                          _buildAlumniSummaryCard(context),
                        ],
                      ),
              ),
              const SizedBox(height: 48),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWelcomeBanner(BuildContext context, String greeting) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
        boxShadow: isDark
            ? []
            : const [
                BoxShadow(
                  color: Color(0x0C0F172A),
                  blurRadius: 18,
                  offset: Offset(0, 6),
                ),
              ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -10,
            bottom: -20,
            child: Opacity(
              opacity: isDark ? 0.08 : 0.05,
              child: Image.asset(
                'assets/images/bisu.png',
                width: 180,
                height: 180,
                fit: BoxFit.contain,
              ),
            ),
          ),
          Row(
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: AppColors.primaryBlue.withValues(alpha: 0.15),
                backgroundImage: user.photoUrl != null
                    ? avatarProvider(user.photoUrl)
                    : null,
                child: user.photoUrl == null
                    ? Text(
                        user.fullName.isNotEmpty
                            ? user.fullName[0].toUpperCase()
                            : '?',
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryBlue,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '$greeting, ',
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.w500,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            user.fullName,
                            style: GoogleFonts.poppins(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : AppColors.primaryNavy,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Welcome to your BISU Alumni Portal. Keep your career information up to date.',
                      style: GoogleFonts.poppins(
                        fontSize: 12.5,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _tagBadge(
                          Icons.verified_rounded,
                          'Verified Graduate',
                          AppColors.goldDark,
                        ),
                        if (user.course != null && user.course!.isNotEmpty)
                          _tagBadge(
                            Icons.school_rounded,
                            user.course!,
                            AppColors.teal,
                          ),
                        if (user.graduationYear != null)
                          _tagBadge(
                            Icons.calendar_today_rounded,
                            'Class of ${user.graduationYear}',
                            AppColors.primaryBlue,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tagBadge(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCompletionChecklist(BuildContext context, double completion) {
    final compRound = completion.round();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
        boxShadow: isDark
            ? []
            : const [
                BoxShadow(
                  color: Color(0x0C0F172A),
                  blurRadius: 18,
                  offset: Offset(0, 6),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Profile Completion Rate',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : AppColors.primaryNavy,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: compRound >= 80
                                ? AppColors.success.withValues(alpha: 0.15)
                                : AppColors.gold.withValues(alpha: 0.20),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: compRound >= 80
                                  ? AppColors.success
                                  : AppColors.goldDark,
                            ),
                          ),
                          child: Text(
                            '$compRound%',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: compRound >= 80
                                  ? AppColors.success
                                  : AppColors.goldDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Complete missing graduate information to help BISU accreditations and tracer statistics.',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: () => context.push(AppRoutes.editProfile),
                icon: const Icon(Icons.edit_rounded, size: 16),
                label: const Text('Complete Now'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: completion / 100,
              minHeight: 8,
              backgroundColor: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : AppColors.primaryBlue.withValues(alpha: 0.12),
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.goldDark),
            ),
          ),
          const SizedBox(height: 18),

          // Checklist Breakdown Grid
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 600;
              return GridView.count(
                crossAxisCount: isWide ? 2 : 1,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 12,
                childAspectRatio: isWide ? 4.2 : 5.5,
                children: [
                  _ChecklistItem(
                    title: 'Basic Alumni Profile',
                    subtitle: user.fullName.isNotEmpty ? 'Name & Email Provided' : 'Missing Info',
                    isDone: true,
                    onTap: () => context.push(AppRoutes.editProfile),
                  ),
                  _ChecklistItem(
                    title: 'Current Employment Record',
                    subtitle: user.employmentStatus == EmploymentStatus.employed
                        ? 'Record Logged'
                        : 'Action Needed: Update Work Status',
                    isDone: user.employmentStatus == EmploymentStatus.employed,
                    onTap: () => context.push(AppRoutes.employment),
                  ),
                  _ChecklistItem(
                    title: 'Resume & CV Vault',
                    subtitle: 'Upload latest PDF resume',
                    isDone: false,
                    onTap: () => context.push(AppRoutes.resume),
                  ),
                  _ChecklistItem(
                    title: 'Graduate Tracer Survey',
                    subtitle: '2/3 Surveys completed',
                    isDone: false,
                    onTap: () => showAppSnackBar(
                      context,
                      'Graduate Tracer Survey is active',
                      duration: const Duration(seconds: 2),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAnnouncementsSection(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
        boxShadow: isDark
            ? []
            : const [
                BoxShadow(
                  color: Color(0x0C0F172A),
                  blurRadius: 18,
                  offset: Offset(0, 6),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Latest Announcements',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : AppColors.primaryNavy,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {},
                child: Text(
                  'View All',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppColors.primaryBlue,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const _AnnouncementCard(
            title: 'BISU Grand Alumni Homecoming 2026 Registration Open',
            date: '2 hours ago',
            category: 'Event',
            categoryColor: AppColors.goldDark,
            description: 'All graduates are invited to join the annual homecoming assembly at the BISU Main Campus Gymnasium.',
          ),
          const SizedBox(height: 10),
          const _AnnouncementCard(
            title: 'Annual Graduate Tracer Survey Submission Deadline',
            date: '1 day ago',
            category: 'Survey',
            categoryColor: AppColors.teal,
            description: 'Please submit your career updates before the end of the month for CHED national reporting.',
          ),
        ],
      ),
    );
  }

  Widget _buildAlumniSummaryCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
        boxShadow: isDark
            ? []
            : const [
                BoxShadow(
                  color: Color(0x0C0F172A),
                  blurRadius: 18,
                  offset: Offset(0, 6),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Alumni Quick Record',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : AppColors.primaryNavy,
            ),
          ),
          const SizedBox(height: 14),
          _infoRow(context, 'Student No.', user.studentNumber ?? 'N/A'),
          _infoRow(context, 'Course', user.course ?? 'BS Computer Science'),
          _infoRow(context, 'Graduation Year', user.graduationYear?.toString() ?? '2024'),
          _infoRow(context, 'Phone', user.phoneNumber ?? 'Not provided'),
          _infoRow(context, 'Status', user.employmentStatus.label),
          const Divider(height: 24),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => context.push(AppRoutes.profile),
              icon: const Icon(Icons.badge_rounded, size: 16),
              label: const Text('View Full Credentials'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(BuildContext context, String label, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : AppColors.primaryNavy,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChecklistItem extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isDone;
  final VoidCallback onTap;

  const _ChecklistItem({
    required this.title,
    required this.subtitle,
    required this.isDone,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDarkAlt : AppColors.surfaceLightAlt,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDone
                  ? AppColors.success.withValues(alpha: 0.3)
                  : AppColors.warning.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Icon(
                isDone ? Icons.check_circle_rounded : Icons.pending_actions_rounded,
                color: isDone ? AppColors.success : AppColors.warning,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : AppColors.primaryNavy,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.poppins(
                        fontSize: 10.5,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: isDark ? AppColors.cardDark : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 110,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? AppColors.borderDark : AppColors.borderLight,
            ),
            boxShadow: isDark
                ? []
                : const [
                    BoxShadow(
                      color: Color(0x080F172A),
                      blurRadius: 10,
                      offset: Offset(0, 2),
                    ),
                  ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: isDark ? 0.16 : 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : AppColors.primaryNavy,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  final String title;
  final String date;
  final String category;
  final Color categoryColor;
  final String description;

  const _AnnouncementCard({
    required this.title,
    required this.date,
    required this.category,
    required this.categoryColor,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDarkAlt : AppColors.surfaceLightAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: categoryColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  category,
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: categoryColor,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                date,
                style: GoogleFonts.poppins(
                  fontSize: 10.5,
                  color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : AppColors.primaryNavy,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: GoogleFonts.poppins(
              fontSize: 11.5,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _DocumentsTab extends StatelessWidget {
  final UserModel user;
  const _DocumentsTab({required this.user});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'Documents Vault',
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : AppColors.primaryNavy,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Store and manage your verified resume and professional certificates.',
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 24),
        _DocumentOptionCard(
          icon: Icons.upload_file_rounded,
          title: 'Resume / CV',
          subtitle: 'Keep your employment profile ready for recruiters and university opportunities.',
          buttonLabel: 'Manage Resume',
          onTap: () => context.push(AppRoutes.resume),
        ),
        const SizedBox(height: 16),
        _DocumentOptionCard(
          icon: Icons.workspace_premium_rounded,
          title: 'Certificates Gallery',
          subtitle: 'Upload and organize your verified awards, licenses, and course certificates.',
          buttonLabel: 'View Certificates',
          onTap: () => context.push(AppRoutes.certificates),
        ),
      ],
    );
  }
}

class _DocumentOptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String buttonLabel;
  final VoidCallback onTap;

  const _DocumentOptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
        boxShadow: isDark
            ? []
            : const [
                BoxShadow(
                  color: Color(0x0C0F172A),
                  blurRadius: 18,
                  offset: Offset(0, 6),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withValues(alpha: isDark ? 0.16 : 0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: AppColors.primaryBlue, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppColors.primaryNavy,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            subtitle,
            style: GoogleFonts.poppins(
              fontSize: 12.5,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              foregroundColor: Colors.white,
            ),
            child: Text(buttonLabel),
          ),
        ],
      ),
    );
  }
}

class _JobsTab extends StatelessWidget {
  final UserModel user;
  const _JobsTab({required this.user});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'Employment & Career Records',
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : AppColors.primaryNavy,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Log your employment history, promotions, and work setup to update tracer metrics.',
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardDark : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? AppColors.borderDark : AppColors.borderLight,
            ),
            boxShadow: isDark
                ? []
                : const [
                    BoxShadow(
                      color: Color(0x0C0F172A),
                      blurRadius: 18,
                      offset: Offset(0, 6),
                    ),
                  ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Work Tracker Status',
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppColors.primaryNavy,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    'Current Status: ',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                  Text(
                    user.employmentStatus.label,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: user.employmentStatus == EmploymentStatus.employed
                          ? AppColors.success
                          : AppColors.goldDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => context.push(AppRoutes.employment),
                icon: const Icon(Icons.work_history_rounded, size: 18),
                label: const Text('Open Employment History'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AlumniTab extends StatelessWidget {
  final UserModel user;
  const _AlumniTab({required this.user});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'Alumni Community',
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : AppColors.primaryNavy,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Connect with fellow BISU graduates and access alumni network resources.',
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardDark : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? AppColors.borderDark : AppColors.borderLight,
            ),
            boxShadow: isDark
                ? []
                : const [
                    BoxShadow(
                      color: Color(0x0C0F172A),
                      blurRadius: 18,
                      offset: Offset(0, 6),
                    ),
                  ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your Registered Alumni Credentials',
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppColors.primaryNavy,
                ),
              ),
              const SizedBox(height: 12),
              _itemLine(context, 'Full Name', user.fullName),
              _itemLine(context, 'Course Program', user.course ?? 'BS Computer Science'),
              _itemLine(context, 'Graduation Batch', user.graduationYear?.toString() ?? '2024'),
              _itemLine(context, 'Status', user.employmentStatus.label),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.push(AppRoutes.editProfile),
                child: const Text('Update Profile Info'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _itemLine(BuildContext context, String k, String v) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            k,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
          Text(
            v,
            style: GoogleFonts.poppins(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : AppColors.primaryNavy,
            ),
          ),
        ],
      ),
    );
  }
}