import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/app_constants.dart';
import '../models/user_model.dart';
import '../providers/auth_providers.dart';
import '../providers/theme_provider.dart';
import '../routes/app_router.dart';
import '../services/auth_service.dart';
import '../utils/app_snack_bar.dart';

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
      case 'settings':
        context.push(AppRoutes.editProfile);
        break;
      case 'change_password':
        _showChangePasswordDialog(context, ref);
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
        _showHelpDialog(context);
        break;
      case 'logout':
        _confirmLogout(context, ref);
        break;
    }
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Help & Support'),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _HelpItem(
                Icons.person_outline,
                'Manage your account',
                'Use "Edit Profile" to update your personal details, '
                    'and "Change Password" to update your login.',
              ),
              SizedBox(height: 12),
              _HelpItem(
                Icons.workspace_premium_outlined,
                'Upload documents',
                'Attach your resume and certificates from the Documents '
                    'section so the university can verify your credentials.',
              ),
              SizedBox(height: 12),
              _HelpItem(
                Icons.fact_check_outlined,
                'Tracer survey',
                'Complete the graduate tracer survey to help BISU track '
                    'alumni outcomes.',
              ),
              SizedBox(height: 12),
              _HelpItem(
                Icons.support_agent_outlined,
                'Contact support',
                'For further help, contact your department coordinator or '
                    'alumni office at support@bisu.edu.ph.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _confirmLogout(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await ref.read(authServiceProvider).signOut();
              if (context.mounted) context.go(AppRoutes.login);
            },
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog(BuildContext context, WidgetRef ref) {
    final currentPwdCtrl = TextEditingController();
    final newPwdCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Change Password'),
        content: Form(
          key: formKey,
          child: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: currentPwdCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Current Password',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: newPwdCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'New Password',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      v == null || v.length < 6 ? 'Minimum 6 characters' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: confirmCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Confirm Password',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      v != newPwdCtrl.text ? 'Passwords do not match' : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (!(formKey.currentState?.validate() ?? false)) return;
              Navigator.of(ctx).pop();
              try {
                await _changePassword(
                  currentPassword: currentPwdCtrl.text,
                  newPassword: newPwdCtrl.text,
                );
                if (context.mounted) {
                  showSuccess(context, 'Password changed successfully');
                }
              } catch (e) {
                if (context.mounted) {
                  showAppSnackBar(
                    context,
                    AuthService.friendlyError(e),
                    backgroundColor: AppColors.error,
                  );
                }
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  Future<void> _changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final auth = FirebaseAuth.instance;
    final user = auth.currentUser;
    if (user == null || user.email == null) {
      throw StateError('You must be signed in to change your password.');
    }
    final credential = EmailAuthProvider.credential(
      email: user.email!,
      password: currentPassword,
    );
    await user.reauthenticateWithCredential(credential);
    await user.updatePassword(newPassword);
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

class _HelpItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _HelpItem(this.icon, this.title, this.description);

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 22, color: AppColors.primaryBlue),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: GoogleFonts.poppins(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
