import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../constants/app_constants.dart';
import '../../models/user_model.dart';
import '../../providers/auth_providers.dart';
import '../../providers/execution_trace_provider.dart';
import '../../providers/messaging_providers.dart';
import '../../routes/app_router.dart';
import '../../utils/avatar_utils.dart';
import '../../widgets/bisu_brand_logo.dart';
import '../../widgets/notification_bell.dart';
import '../../widgets/profile_menu.dart';

/// Desktop web-style shell for admins: sidebar + top bar, regardless of
/// viewport width. Admin-only; the alumni shell lives in
/// `dashboards/alumni/alumni_shell.dart`.
class AdminShell extends ConsumerWidget {
  final Widget child;
  const AdminShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const items = _adminNavItems;
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final compactSidebar = constraints.maxWidth < 700;
        final showAyBadge = constraints.maxWidth >= 1200;

        return Scaffold(
          backgroundColor:
              isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
          body: SafeArea(
            child: Row(
              children: [
                _AdminSidebar(
                  items: items,
                  selectedIndex: selected,
                  onSelected: navigate,
                  isCompact: compactSidebar,
                ),
                Expanded(
                  child: Column(
                    children: [
                      _AdminTopBar(
                        compact: compactSidebar,
                        showAyBadge: showAyBadge,
                      ),
                      Expanded(
                        child: ColoredBox(
                          color: isDark
                              ? AppColors.surfaceDark
                              : AppColors.surfaceLight,
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
      },
    );
  }
}

class _AdminShellNavItem {
  const _AdminShellNavItem(
      this.icon, this.activeIcon, this.label, this.path, this.color);

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String path;
  final Color color;
}

const _adminNavItems = [
  _AdminShellNavItem(Icons.shield_outlined, Icons.shield_rounded, 'Home',
      AppRoutes.adminDashboard, AppColors.primaryBlue),
  _AdminShellNavItem(Icons.school_outlined, Icons.school_rounded,
      'Alumni', AppRoutes.adminAlumni, Color(0xFFD97706)),
  _AdminShellNavItem(Icons.people_outline_rounded, Icons.people_rounded,
      'Users', AppRoutes.adminUsers, Color(0xFF0D9488)),
  _AdminShellNavItem(Icons.fact_check_outlined, Icons.fact_check_rounded,
      'Survey', AppRoutes.adminSurveys, Color(0xFF0369A1)),
  _AdminShellNavItem(Icons.campaign_outlined, Icons.campaign_rounded,
      'Announcements & Events', AppRoutes.adminAnnouncementsEvents, Color(0xFFEA580C)),
  _AdminShellNavItem(Icons.mail_outline_rounded, Icons.mail_rounded,
      'Messages', AppRoutes.adminMessages, Color(0xFFF43F5E)),
  _AdminShellNavItem(Icons.work_history_outlined, Icons.work_history_rounded,
      'Employment History', AppRoutes.adminEmploymentHistory, Color(0xFF047857)),
  _AdminShellNavItem(Icons.history_rounded, Icons.history_rounded,
      'Audit Logs', AppRoutes.adminAuditLogs, Color(0xFFA855F7)),
  _AdminShellNavItem(Icons.assessment_outlined, Icons.assessment_rounded,
      'Reports & Analytics', AppRoutes.adminReportsAnalytics, Color(0xFF4F46E5)),
  _AdminShellNavItem(Icons.settings_outlined, Icons.settings_rounded,
      'Settings', AppRoutes.adminSettings, Color(0xFF06B6D4)),
];

int _selectedIndex(String location, List<_AdminShellNavItem> items) {
  final index = items.lastIndexWhere((item) => location.startsWith(item.path));
  return index < 0 ? 0 : index;
}

class _AdminSidebar extends ConsumerWidget {
  const _AdminSidebar({
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
    this.isCompact = false,
  });

  final List<_AdminShellNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final bool isCompact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final unreadMessages = ref.watch(unreadAdminMessagesCountProvider);

    return Container(
      width: isCompact ? 76 : 260,
      padding: EdgeInsets.fromLTRB(isCompact ? 8 : 18, 22, isCompact ? 8 : 18, 20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDarkAlt : Colors.white,
        border: Border(
          right: BorderSide(
            color: isDark ? AppColors.borderDark : AppColors.outlineCard,
            width: 1.5,
          ),
        ),
        boxShadow: isDark
            ? []
            : const [
                BoxShadow(
                  color: Color(0x060052CC),
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
            child: isCompact
                ? const Center(
                    child: BisuBrandLogo(compact: true, size: 34),
                  )
                : const BisuBrandLogo(compact: false, size: 36),
          ),
          const SizedBox(height: 20),

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
                  activeColor: item.color,
                  onTap: () => onSelected(index),
                  isCompact: isCompact,
                  badgeCount: item.path == AppRoutes.adminMessages
                      ? unreadMessages
                      : null,
                );
              },
            ),
          ),

          // Integrated Stronger Connections Promo Card
          if (!isCompact)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.bisuBlue900 : AppColors.primaryBlue,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: Colors.white.withOpacity(0.20),
                  width: 1.5,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x38003DA5),
                    blurRadius: 20,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.20),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.verified_user_rounded,
                      color: Colors.white,
                      size: 17,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Stronger Connections,\nStronger Community.',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Together, we grow with BISU alumni worldwide.',
                    style: GoogleFonts.poppins(
                      fontSize: 10.5,
                      color: const Color(0xFFDBEAFE),
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 10),
                  InkWell(
                    onTap: () => context.push(AppRoutes.adminAnalytics),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'Explore Portal',
                        style: GoogleFonts.poppins(
                          color: AppColors.primaryBlue,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
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
  final Color activeColor;
  final VoidCallback onTap;
  final bool isCompact;
  final int? badgeCount;

  const _SidebarMenuItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.activeColor,
    required this.onTap,
    this.isCompact = false,
    this.badgeCount,
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
    Color textColor;
    Color iconColor;
    BorderSide borderSide;

    if (widget.selected) {
      backgroundColor = isDark
          ? AppColors.bisuBlue800.withOpacity(0.35)
          : AppColors.primarySoft;
      borderSide = BorderSide(
        color: isDark
            ? AppColors.primaryLightSkyCyan.withOpacity(0.45)
            : AppColors.outlineCardActive,
        width: 1.5,
      );
      textColor = isDark ? Colors.white : AppColors.primaryBlue;
      iconColor = isDark ? const Color(0xFF60A5FA) : AppColors.primaryBlue;
    } else {
      backgroundColor = _isHovered
          ? (isDark ? AppColors.cardDark : AppColors.surfaceLightAlt)
          : Colors.transparent;
      borderSide = BorderSide(
        color: _isHovered
            ? (isDark ? AppColors.borderDark : AppColors.outlineCard)
            : Colors.transparent,
        width: 1.5,
      );
      textColor = isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary;
      iconColor = isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary;
    }

    final hasBadge = widget.badgeCount != null && widget.badgeCount! > 0;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: EdgeInsets.symmetric(
              horizontal: widget.isCompact ? 10 : 14, vertical: 11),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.fromBorderSide(borderSide),
          ),
          child: widget.isCompact
              ? Tooltip(
                  message: widget.label,
                  child: Center(
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Icon(widget.icon, color: iconColor, size: 22),
                        if (hasBadge)
                          Positioned(
                            right: -6,
                            top: -4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: AppColors.error,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              constraints: const BoxConstraints(
                                  minWidth: 14, minHeight: 14),
                              child: Text(
                                widget.badgeCount! > 99
                                    ? '99+'
                                    : '${widget.badgeCount}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                )
              : Row(
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
                    if (hasBadge) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.error,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          widget.badgeCount! > 99
                              ? '99+'
                              : '${widget.badgeCount}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
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

class _AdminTopBar extends ConsumerWidget {
  const _AdminTopBar({this.compact = false, this.showAyBadge = false});

  final bool compact;
  final bool showAyBadge;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProfileProvider).valueOrNull;
    final initials = _adminInitials(user?.fullName ?? 'User');
    final photo = user?.photoUrl;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 70,
      padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 28),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppColors.borderDark : AppColors.outlineCard,
            width: 1.5,
          ),
        ),
      ),
      child: Row(
        children: [
          // Breadcrumb / Context Title
          if (!compact)
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Graduate Tracking System',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : AppColors.bisuOfficialPrimary,
                    ),
                  ),
                  const SizedBox(height: 1),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Bohol Island State University',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.primarySoft,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: AppColors.outlineBadge,
                              width: 1,
                            ),
                          ),
                          child: Text(
                            'Bilar Campus',
                            style: GoogleFonts.poppins(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryBlue,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else
            const Spacer(),

          // AY Badge
          if (!compact && showAyBadge) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isDark ? AppColors.cardDark : AppColors.surfaceLightAlt,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? AppColors.borderDark : AppColors.outlineCard,
                  width: 1,
                ),
              ),
              child: Text(
                'AY 2026–2027 · Bohol Island State University',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],

          // Messages / Chat Button
          if (user != null) ...[
            _AdminChatButton(user: user),
            const SizedBox(width: 8),
          ],

          // Notification Bell
          if (user != null)
            NotificationBell(
              userId: user.uid,
              isAdmin: user.role == UserRole.admin,
            ),
          if (!compact) const SizedBox(width: 12),

          // User Avatar & Profile Dropdown
          if (user != null)
            ProfileMenu(
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: compact ? 4 : 10, vertical: compact ? 4 : 6),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.cardDark : AppColors.surfaceLightAlt,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark ? AppColors.borderDark : AppColors.outlineCard,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: AppColors.primaryBlue,
                        backgroundImage:
                            photo != null ? avatarProvider(photo) : null,
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
                      if (!compact) ...[
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
                                color: isDark
                                    ? AppColors.tealLight
                                    : AppColors.tealDeep,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
                          size: 18,
                        ),
                      ],
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

String _adminInitials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.length > 1) {
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
  return name.isEmpty ? 'U' : name[0].toUpperCase();
}

class _AdminChatButton extends ConsumerWidget {
  final UserModel user;

  const _AdminChatButton({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCount = ref.watch(unreadAdminMessagesCountProvider);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: const Icon(Icons.chat_bubble_outline_rounded),
          tooltip: 'Alumni Inquiries',
          onPressed: () {
            context.push(AppRoutes.adminMessages);
          },
        ),
        if (unreadCount > 0)
          Positioned(
            right: 4,
            top: 4,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: AppColors.error,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              child: Text(
                unreadCount > 99 ? '99+' : unreadCount.toString(),
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}

// ignore: unused_element, kept for future mobile admin nav
class _AdminBottomNavigation extends ConsumerWidget {
  const _AdminBottomNavigation({
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<_AdminShellNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inactiveColor =
        isDark ? Colors.white.withOpacity(.68) : const Color(0xFF667085);
    final unreadMessages = ref.watch(unreadAdminMessagesCountProvider);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(.40)
                : const Color(0xFF0B1F3A).withOpacity(.12),
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
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF131720).withOpacity(.96)
                  : Colors.white.withOpacity(.96),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(.08)
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
                        splashColor: activeColor.withOpacity(.14),
                        highlightColor: activeColor.withOpacity(.06),
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
                                      horizontal: selected ? 10 : 3,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: selected
                                          ? activeColor.withOpacity(isDark ? .22 : .12,
                                            )
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Icon(
                                      selected ? item.activeIcon : item.icon,
                                      size: 20,
                                      color: selected
                                          ? activeColor
                                          : inactiveColor,
                                    ),
                                  ),
                                  if (item.path == AppRoutes.adminMessages && unreadMessages > 0)
                                    Positioned(
                                      right: selected ? 2 : -4,
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
                                          unreadMessages > 99
                                              ? '99+'
                                              : '$unreadMessages',
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
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  item.label,
                                  maxLines: 1,
                                  style: TextStyle(
                                    color: selected
                                        ? (isDark ? Colors.white : activeColor)
                                        : inactiveColor,
                                    fontSize: 9,
                                    fontWeight: selected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                  ),
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
