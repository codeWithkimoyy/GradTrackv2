import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/app_constants.dart';
import '../models/user_model.dart';
import '../providers/auth_providers.dart';
import '../providers/theme_provider.dart';
import '../routes/app_router.dart';
import 'account_dialogs.dart';

class ProfileMenu extends ConsumerWidget {
  final Widget child;

  const ProfileMenu({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentUserProfileProvider);

    return PopupMenuButton<String>(
      offset: const Offset(0, 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 8,
      color: Theme.of(context).colorScheme.surface,
      onSelected: (value) => _handleAction(context, ref, value),
      itemBuilder: (context) =>
          _buildMenuItems(context, ref, profile.valueOrNull),
      child: child,
    );
  }

  void _handleAction(BuildContext context, WidgetRef ref, String value) {
    switch (value) {
      case 'profile':
        context.push(AppRoutes.profile);
        break;
      case 'edit_profile':
        context.push(AppRoutes.editProfile);
        break;
      case 'settings': {
        final role = ref.read(currentUserProfileProvider).valueOrNull?.role;
        context.push(
          role == UserRole.admin ? AppRoutes.adminSettings : AppRoutes.editProfile,
        );
        break;
      }
      case 'change_password':
        showChangePasswordDialog(context, ref);
        break;
      case 'theme':
        final isDark = Theme.of(context).brightness == Brightness.dark;
        ref.read(themeModeProvider.notifier).setTheme(
              isDark ? AppThemeMode.light : AppThemeMode.dark,
            );
        break;
      case 'notifications':
        context.push(AppRoutes.alumniNotifications);
        break;
      case 'help':
        showHelpDialog(context);
        break;
      case 'logout':
        confirmSignOut(context, ref);
        break;
    }
  }

  List<PopupMenuEntry<String>> _buildMenuItems(
      BuildContext context, WidgetRef ref, UserModel? user) {
    final theme = Theme.of(context);
    return [
      PopupMenuItem<String>(
        enabled: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppColors.primaryBlue,
                  child: Text(
                    _initials(user?.fullName ?? 'U'),
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.fullName ?? 'User',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        user?.role.label ?? 'Alumni',
                        style: GoogleFonts.poppins(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.6),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
          ],
        ),
      ),
      PopupMenuItem(
        value: 'profile',
        child: _menuItem(Icons.person_outline, 'View Profile'),
      ),
      PopupMenuItem(
        value: 'edit_profile',
        child: _menuItem(Icons.edit_outlined, 'Edit Profile'),
      ),
      const PopupMenuDivider(),
      PopupMenuItem(
        value: 'change_password',
        child: _menuItem(Icons.lock_outline, 'Change Password'),
      ),
      PopupMenuItem(
        value: 'theme',
        child: _menuItem(
          theme.brightness == Brightness.dark
              ? Icons.light_mode_outlined
              : Icons.dark_mode_outlined,
          theme.brightness == Brightness.dark ? 'Light Mode' : 'Dark Mode',
        ),
      ),
      PopupMenuItem(
        value: 'settings',
        child: _menuItem(Icons.settings_outlined, 'Account Settings'),
      ),
      const PopupMenuDivider(),
      PopupMenuItem(
        value: 'help',
        child: _menuItem(Icons.help_outline, 'Help & Support'),
      ),
      const PopupMenuDivider(),
      PopupMenuItem(
        value: 'logout',
        child: Row(
          children: [
            const Icon(Icons.logout, size: 20, color: AppColors.error),
            const SizedBox(width: 12),
            Text(
              'Sign Out',
              style: GoogleFonts.poppins(color: AppColors.error),
            ),
          ],
        ),
      ),
    ];
  }

  Widget _menuItem(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 12),
        Text(label, style: GoogleFonts.poppins()),
      ],
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : 'U';
  }
}
