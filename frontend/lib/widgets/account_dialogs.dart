import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/app_constants.dart';
import '../providers/auth_providers.dart';
import '../routes/app_router.dart';
import '../services/auth_service.dart';
import '../utils/app_snack_bar.dart';

/// Help & support dialog shared by the profile menu and admin settings.
void showHelpDialog(BuildContext context) {
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
              'For further help, contact the GradTrack administrators or '
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

/// Sign-out confirmation dialog shared by the profile menu and admin settings.
void confirmSignOut(BuildContext context, WidgetRef ref) {
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

/// Change-Password dialog shared by the profile menu and admin settings.
void showChangePasswordDialog(BuildContext context, WidgetRef ref) {
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
                validator: (v) =>
                    v == null || v.isEmpty ? 'Required' : null,
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
                ref,
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

Future<void> _changePassword(
  WidgetRef ref, {
  required String currentPassword,
  required String newPassword,
}) async {
  final session = ref.read(authStateProvider).valueOrNull;
  if (session == null) {
    throw StateError('You must be signed in to change your password.');
  }
  await ref.read(userRepositoryProvider).changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
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