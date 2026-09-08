import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_constants.dart';
import '../../providers/auth_providers.dart';
import '../../routes/app_router.dart';
import '../../utils/app_snack_bar.dart';

/// Shown to students whose account has not yet been approved by an
/// administrator/coordinator. They cannot reach alumni content until approved.
/// Watches the live profile so it automatically grants access the moment the
/// account is approved.
class PendingApprovalScreen extends ConsumerWidget {
  const PendingApprovalScreen({super.key});

  Future<void> _checkApproval(BuildContext context, WidgetRef ref) async {
    final profile = ref.read(currentUserProfileProvider).valueOrNull;
    final uid = profile?.uid;
    if (uid == null) {
      showAppSnackBar(
        context,
        'Your profile is not available yet. Please sign out and try again.',
      );
      return;
    }

    try {
      final fresh = await ref
          .read(authServiceProvider)
          .fetchUserProfile(uid);
      if (!context.mounted) return;

      if (fresh == null) {
        showAppSnackBar(
          context,
          'Profile record not found. Please sign out and sign in again.',
        );
        return;
      }

      if (fresh.approved) {
        showAppSnackBar(
          context,
          'Your account has been approved. Welcome to GradTrack!',
          backgroundColor: AppColors.success,
        );
        context.go(dashboardForRole(fresh.role));
        return;
      }

      showAppSnackBar(
        context,
        'Your account is still pending approval.',
        backgroundColor: AppColors.warning,
      );
    } catch (e) {
      if (context.mounted) {
        showAppSnackBar(
          context,
          'Could not check approval: $e',
          backgroundColor: AppColors.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentUserProfileProvider);
    final profile = profileAsync.valueOrNull;

    if (profile != null && profile.approved) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) _checkApproval(context, ref);
      });
    }

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.hourglass_top_rounded,
                    size: 72, color: AppColors.warning),
                const SizedBox(height: 18),
                Text(
                  'Account pending approval',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your registration has been received and is awaiting '
                  'approval from a GradTrack administrator. You will gain '
                  'access as soon as your account is approved.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(color: Colors.grey[600]),
                ),
                const SizedBox(height: 24),
                if (profile != null)
                  FilledButton.icon(
                    onPressed: () => _checkApproval(context, ref),
                    icon: const Icon(Icons.verified_user_rounded),
                    label: const Text('Check Approval Status'),
                  ),
                const SizedBox(height: 10),
                TextButton.icon(
                  onPressed: () async {
                    await ref.read(authServiceProvider).signOut();
                    if (context.mounted) context.go(AppRoutes.login);
                  },
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Sign Out'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
