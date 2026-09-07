import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_constants.dart';
import '../../models/user_model.dart';
import '../../providers/auth_providers.dart';
import '../../routes/app_router.dart';
import '../../utils/app_snack_bar.dart';

/// Shown to signed-in users whose account has not yet been approved by an
/// administrator/coordinator. They cannot reach any app content until approved.
/// Watches the live profile so it automatically grants access the moment the
/// account is approved.
class PendingApprovalScreen extends ConsumerWidget {
  const PendingApprovalScreen({super.key});

  void _openAccount(BuildContext context, WidgetRef ref, UserModel? profile) {
    if (profile != null && profile.approved) {
      final home = dashboardForRole(profile.role);
      showAppSnackBar(
        context,
        'Your account has been approved! Welcome to GradTrack.',
        backgroundColor: AppColors.success,
      );
      context.go(home);
    } else {
      showAppSnackBar(
        context,
        'Your account is still pending administrator approval.',
        backgroundColor: AppColors.warning,
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<AsyncValue<UserModel?>>(currentUserProfileProvider, (previous, next) {
      final user = next.valueOrNull;
      if (user != null && user.approved) {
        showAppSnackBar(
          context,
          'Your account has been approved! Welcome to GradTrack.',
          backgroundColor: AppColors.success,
        );
        context.go(dashboardForRole(user.role));
      }
    });

    final profileAsync = ref.watch(currentUserProfileProvider);
    final profile = profileAsync.valueOrNull;

    if (profile != null && profile.approved) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) _openAccount(context, ref, profile);
      });
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.cardDark : Colors.white,
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  border: Border.all(
                    color: isDark ? AppColors.borderDark : AppColors.borderLight,
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.24 : 0.04),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.14),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.hourglass_top_rounded,
                        size: 44,
                        color: AppColors.warning,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Account Pending Approval',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : AppColors.textPrimary,
                          ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Your registration has been received and is awaiting '
                      'approval from a GradTrack administrator. You will gain '
                      'access as soon as your account is approved.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        height: 1.5,
                        color: isDark ? AppColors.textMuted : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primaryBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.button),
                          ),
                        ),
                        onPressed: () async {
                          try {
                            await ref.read(authServiceProvider).reloadUser();
                          } catch (_) {}
                          ref.invalidate(currentUserProfileProvider);
                          if (context.mounted) {
                            _openAccount(context, ref, profile);
                          }
                        },
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text(
                          'Check Approval Status',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.error,
                      ),
                      onPressed: () async {
                        await ref.read(authServiceProvider).signOut();
                        if (context.mounted) context.go(AppRoutes.login);
                      },
                      icon: const Icon(Icons.logout_rounded, size: 18),
                      label: const Text(
                        'Sign Out',
                        style: TextStyle(fontWeight: FontWeight.w600),
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
  }
}
