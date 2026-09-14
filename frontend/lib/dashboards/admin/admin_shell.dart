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
                      _AdminTopBar(compact: compactSidebar),
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
  const _AdminShellNavItem(this.icon, this.activeIcon, this.label, this.path,
      this.color, {this.sticker = ''});

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String path;
  final Color color;

  /// Optional emoji "sticker" shown above the selected nav item.
  final String sticker;
}

const _adminNavItems = [
  _AdminShellNavItem(Icons.shield_outlined, Icons.shield_rounded, 'Home',
      AppRoutes.adminDashboard, Color(0xFF2563EB),
      sticker: '\u{1F6E1}\u{FE0F}'),
  _AdminShellNavItem(Icons.school_outlined, Icons.school_rounded,
      'Alumni', AppRoutes.adminAlumni, Color(0xFFD97706),
      sticker: '\u{1F393}'),
  _AdminShellNavItem(Icons.people_outline_rounded, Icons.people_rounded,
      'Users', AppRoutes.adminUsers, Color(0xFF0D9488),
      sticker: '\u{1F465}'),
  _AdminShellNavItem(Icons.analytics_outlined, Icons.analytics_rounded,
      'Analytics', AppRoutes.adminAnalytics, Color(0xFFD97706),
      sticker: '\u{1F4CA}'),
  _AdminShellNavItem(Icons.history_rounded, Icons.history_rounded,
      'Audit Logs', AppRoutes.adminAuditLogs, Color(0xFFA855F7),
      sticker: '\u{1F4DC}'),
  _AdminShellNavItem(Icons.mail_outline_rounded, Icons.mail_rounded,
      'Messages', AppRoutes.adminMessages, Color(0xFFF43F5E),
      sticker: '\u{1F4E9}'),
  _AdminShellNavItem(Icons.settings_outlined, Icons.settings_rounded,
      'Settings', AppRoutes.adminSettings, Color(0xFF06B6D4),
      sticker: '\u{2699}\u{FE0F}'),
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
              mainAxisAlignment:
                  isCompact ? MainAxisAlignment.center : MainAxisAlignment.start,
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
                if (!isCompact) ...[
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
            ],
          ),
          ),
          if (!isCompact) ...[
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
          ] else
            const SizedBox(height: 18),

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

          // Integrated Secure Portal Footer Card
          if (!isCompact)
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
    if (widget.selected) {
      backgroundColor = widget.activeColor;
    } else {
      backgroundColor = _isHovered ? AppColors.cardDark : Colors.transparent;
    }

    final textColor = widget.selected
        ? Colors.white
        : (_isHovered
            ? (isDark ? Colors.white : AppColors.primaryNavy)
            : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)));

    final iconColor = widget.selected
        ? Colors.white
        : (_isHovered
            ? widget.activeColor
            : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)));

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
              horizontal: widget.isCompact ? 10 : 14, vertical: 12),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: widget.selected
                  ? widget.activeColor
                  : (_isHovered
                      ? (isDark ? AppColors.borderDark : AppColors.borderLight)
                      : Colors.transparent),
            ),
            boxShadow: widget.selected
                ? [
                    BoxShadow(
                      color: widget.activeColor.withValues(alpha: 0.30),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [],
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
  const _AdminTopBar({this.compact = false});

  final bool compact;

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
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Breadcrumb / Context Title
          if (!compact)
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
                      padding:
                          const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.teal.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Bilar Campus',
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
          if (!compact) const SizedBox(width: 14),

          // User Avatar & Profile Dropdown
          if (user != null)
            ProfileMenu(
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: compact ? 4 : 10, vertical: compact ? 4 : 6),
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
