import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../constants/app_constants.dart';
import '../../models/user_model.dart';
import '../../providers/auth_providers.dart';
import '../../providers/theme_provider.dart';
import '../../utils/avatar_utils.dart';
import '../../widgets/account_dialogs.dart';
import '../../widgets/empty_state_widget.dart';

/// Admin-only account settings (replaces the generic Profile page for admins).
/// The alumni portal keeps the regular Profile tab; admins get account,
/// security and appearance settings here.
class AdminSettingsScreen extends ConsumerWidget {
  const AdminSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentUserProfileProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        elevation: 0,
        title: Text(
          'Settings',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : AppColors.primaryNavy,
          ),
        ),
      ),
      body: profileAsync.when(
        data: (user) {
          if (user == null) {
            return const EmptyStateWidget(
              icon: Icons.person_off_rounded,
              title: 'No Profile Found',
              message: 'Your user profile could not be loaded.',
            );
          }
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              _buildAccountCard(context, ref, user, isDark),
              const SizedBox(height: AppSpacing.md),
              const _SectionLabel('ACCOUNT'),
              const SizedBox(height: 10),
              _SettingsTile(
                icon: Icons.lock_outline,
                title: 'Change Password',
                subtitle: 'Secure your account with a new password',
                onTap: () => showChangePasswordDialog(context, ref),
              ),
              const SizedBox(height: AppSpacing.md),
              const _SectionLabel('PREFERENCES'),
              const SizedBox(height: 10),
              _buildThemeTile(context, ref, isDark),
              const SizedBox(height: AppSpacing.md),
              const _SectionLabel('ABOUT'),
              const SizedBox(height: 10),
              _SettingsTile(
                icon: Icons.help_outline,
                title: 'Help & Support',
                subtitle: 'FAQ, guides and contact information',
                onTap: () => showHelpDialog(context),
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () => confirmSignOut(context, ref),
                icon: const Icon(Icons.logout_rounded, color: AppColors.error),
                label: Text(
                  'Sign Out',
                  style: GoogleFonts.poppins(
                    color: AppColors.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.error),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primaryBlue),
        ),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildAccountCard(
    BuildContext context,
    WidgetRef ref,
    UserModel user,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.outlineCard,
          width: 1.5,
        ),
        boxShadow: isDark
            ? []
            : const [
                BoxShadow(
                  color: Color(0x0A0052CC),
                  blurRadius: 16,
                  offset: Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: AppColors.primaryBlue.withValues(alpha: 0.15),
            backgroundImage:
                user.photoUrl != null ? avatarProvider(user.photoUrl) : null,
            child: user.photoUrl == null
                ? Text(
                    user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : '?',
                    style: GoogleFonts.poppins(
                      fontSize: 28,
                      color: AppColors.primaryBlue,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 12),
          Text(
            user.fullName,
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : AppColors.primaryNavy,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            user.role.label,
            style: GoogleFonts.poppins(
              fontSize: 12.5,
              color: isDark ? AppColors.tealLight : AppColors.tealDeep,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            user.email,
            style: GoogleFonts.poppins(
              fontSize: 12.5,
              color:
                  isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeTile(
      BuildContext context, WidgetRef ref, bool isDark) {
    return _SettingsTile(
      icon: isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
      title: 'Appearance',
      subtitle: isDark ? 'Currently using Dark Mode' : 'Currently using Light Mode',
      trailing: Switch(
        value: isDark,
        activeTrackColor: AppColors.secondaryBlue,
        onChanged: (enabled) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          ref.read(themeModeProvider.notifier).setTheme(
                isDark ? AppThemeMode.light : AppThemeMode.dark,
              );
        },
      ),
      onTap: () {
        ref.read(themeModeProvider.notifier).setTheme(
              isDark ? AppThemeMode.light : AppThemeMode.dark,
            );
      },
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;

  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.3,
          color: Theme.of(context).brightness == Brightness.dark
              ? AppColors.tealLight
              : AppColors.tealDeep,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(
                color: isDark ? AppColors.borderDark : AppColors.outlineCard,
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color:
                        AppColors.primaryBlue.withValues(alpha: isDark ? 0.16 : 0.10),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(icon, color: AppColors.primaryBlue, size: 21),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : AppColors.primaryNavy,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: GoogleFonts.poppins(
                          fontSize: 11.5,
                          color: isDark
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 8),
                  trailing!,
                ] else
                  Icon(
                    Icons.chevron_right_rounded,
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF64748B),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}