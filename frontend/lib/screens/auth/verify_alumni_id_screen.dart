import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_constants.dart';
import '../../providers/auth_providers.dart';
import '../../repositories/user_repository.dart';
import '../../routes/app_router.dart';
import '../../services/auth_service.dart';
import '../../utils/app_snack_bar.dart';
import '../../widgets/glass_auth_scaffold.dart';

/// Step 1 of alumni registration: verifies an office-issued Alumni ID exists
/// in the registry and is still Pending (not yet activated, not disabled).
/// Only then is the registration form unlocked.
class VerifyAlumniIdScreen extends ConsumerStatefulWidget {
  const VerifyAlumniIdScreen({super.key});

  @override
  ConsumerState<VerifyAlumniIdScreen> createState() =>
      _VerifyAlumniIdScreenState();
}

class _VerifyAlumniIdScreenState extends ConsumerState<VerifyAlumniIdScreen> {
  final _formKey = GlobalKey<FormState>();
  final _alumniIdController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _alumniIdController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final alumniId = _alumniIdController.text.trim();
    setState(() => _loading = true);
    try {
      final entry = await ref
          .read(userRepositoryProvider)
          .fetchRegistryEntry(alumniId);

      if (!mounted) return;

      if (entry == null) {
        await _showResult(
          title: 'Alumni ID Not Found',
          message:
              'We could not find "$alumniId" in the registry.\n\n'
              'Alumni ID not found. Please contact the Tracer Study '
              'Administrator.',
          actionLabel: 'OK',
        );
        return;
      }

      switch (entry.status) {
        case AlumniAccountStatus.active:
          final goToLogin = await _showResult(
            title: 'Already Registered',
            message:
                'This Alumni ID is already registered. Please sign in.',
            actionLabel: 'Sign In',
            goToLogin: true,
          );
          if (!mounted) return;
          if (goToLogin) context.go(AppRoutes.login);
          return;
        case AlumniAccountStatus.disabled:
          await _showResult(
            title: 'Account Disabled',
            message:
                'This Alumni ID has been disabled. Please contact the '
                'Tracer Study Administrator.',
            actionLabel: 'OK',
          );
          return;
        case AlumniAccountStatus.pending:
          context.go(AppRoutes.registerWith(entry.alumniId));
          return;
      }
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, AuthService.friendlyError(e),
            backgroundColor: AppColors.error);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Shows the case dialogs and returns true when the user pressed the
  /// primary (highlighted) action, false when merely dismissed.
  Future<bool> _showResult({
    required String title,
    required String message,
    required String actionLabel,
    bool goToLogin = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Icon(
              title == 'Alumni ID Not Found'
                  ? Icons.person_search_outlined
                  : Icons.error_outline,
              color: AppColors.gold,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: GoogleFonts.poppins(fontSize: 13.5, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(goToLogin),
            style: TextButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: Text(actionLabel,
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return GlassAuthScaffold(
      title: 'Verify Alumni ID',
      subtitle: 'Enter your official BISU Alumni ID to begin creating your '
          'account. Only IDs added by the Tracer Study office can register.',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 64,
              height: 64,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFF2563EB), Color(0xFF38BDF8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.35),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Icon(Icons.school_rounded,
                  color: Colors.white, size: 32),
            ),
            const SizedBox(height: 22),
            TextFormField(
              controller: _alumniIdController,
              autocorrect: false,
              autofocus: true,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
              decoration: const InputDecoration(
                hintText: 'Enter your official BISU Alumni ID',
                prefixIcon: Icon(Icons.badge_outlined),
                helperText: 'Example: 2023-0001',
              ),
              textInputAction: TextInputAction.done,
              validator: (v) {
                final val = v?.trim() ?? '';
                if (val.isEmpty) return 'Enter your Alumni ID';
                if (val.contains(' ')) {
                  return 'Alumni ID must not contain spaces';
                }
                if (!AppStrings.alumniIdPattern.hasMatch(val)) {
                  return 'Letters, numbers, hyphens and underscores only';
                }
                return null;
              },
              onFieldSubmitted: (_) => _verify(),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loading ? null : _verify,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text('Verify',
                      style:
                          GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _loading ? null : () => context.go(AppRoutes.login),
              child: Text('Back to Sign In', style: GoogleFonts.poppins()),
            ),
          ],
        ),
      ),
    );
  }
}