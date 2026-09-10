import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_constants.dart';
import '../../providers/auth_providers.dart';
import '../../routes/app_router.dart';
import '../../services/password_reset_service.dart';
import '../../utils/app_snack_bar.dart';
import '../../widgets/glass_auth_scaffold.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  static const _codeTtlMinutes = 10;

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _loading = false;
  int _step = 0; // 0 = email, 1 = code, 2 = password
  String _email = '';

  PasswordResetService get _service => PasswordResetService();

  Future<void> _sendCode() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _loading = true);
    try {
      final identifier = _emailController.text.trim();

      // Alumni IDs (no "@") don't use email codes — password resets for
      // alumni go through the Tracer Study Administrator.
      if (!identifier.contains('@')) {
        if (!mounted) return;
        await _handleAlumniId(identifier);
        return;
      }

      await _service.sendResetCode(identifier);
      if (!mounted) return;
      setState(() {
        _email = identifier;
        _step = 1;
        _codeController.clear();
      });
      showAppSnackBar(
        context,
        'A 6-digit verification code was sent to $_email',
        backgroundColor: AppColors.success,
      );
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, e.toString(),
            backgroundColor: AppColors.error);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleAlumniId(String alumniId) async {
    final entry = await ref
        .read(userRepositoryProvider)
        .fetchRegistryEntry(alumniId.trim());
    if (!mounted) return;

    if (entry == null) {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text('Alumni ID Not Found'),
          content: const Text(
              'We could not find this Alumni ID in the registry.\n\n'
              'Please contact the Tracer Study Administrator.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Password Reset'),
        content: Text(
          'Alumni password resets are handled by the Tracer Study office.\n\n'
          'Please contact the Tracer Study Administrator and ask them to '
          'reset the password for Alumni ID "$alumniId".\n\n'
          '(Administrators can reset any alumni password from the Alumni '
          'Management module.)',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _verifyCode() async {
    if (_codeController.text.trim().length != 6) {
      showAppSnackBar(context, 'Enter the 6-digit code we emailed you.',
          backgroundColor: AppColors.warning);
      return;
    }
    setState(() => _loading = true);
    try {
      await _service.verifyCode(
        email: _email,
        code: _codeController.text.trim(),
      );
      if (!mounted) return;
      showAppSnackBar(
        context,
        'Code verified. Choose your new password.',
        backgroundColor: AppColors.success,
      );
      setState(() => _step = 2);
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, e.toString(),
            backgroundColor: AppColors.error);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resetPassword() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _loading = true);
    try {
      await _service.resetPassword(
        email: _email,
        code: _codeController.text.trim(),
        newPassword: _newPasswordController.text,
      );
      if (!mounted) return;
      showAppSnackBar(
        context,
        'Password updated. You can now sign in.',
        backgroundColor: AppColors.success,
      );
      context.go(AppRoutes.login);
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, e.toString(),
            backgroundColor: AppColors.error);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassAuthScaffold(
      title: 'Reset Password',
      subtitle: switch (_step) {
        0 => 'Alumni: enter your Alumni ID. Administrators: enter your email '
            'to receive a verification code',
        1 => 'Enter the 6-digit code sent to $_email',
        _ => 'Choose a new password for your account',
      },
      child: switch (_step) {
        0 => _buildEmailStep(),
        1 => _buildCodeStep(),
        _ => _buildPasswordStep(),
      },
    );
  }

  Widget _buildEmailStep() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _emailController,
            autocorrect: false,
            style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
            decoration: const InputDecoration(
              hintText: 'Alumni ID or Email',
              prefixIcon: Icon(Icons.badge_outlined),
            ),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'Enter your Alumni ID or email'
                : null,
          ),
          const SizedBox(height: 6),
          Text(
            'Alumni IDs are verified against the registry; password resets '
            'are processed by the administrator.',
            style: GoogleFonts.poppins(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 11,
                height: 1.4),
          ),
          const SizedBox(height: 14),
          ElevatedButton(
            onPressed: _loading ? null : _sendCode,
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
                : Text('Continue',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: _loading ? null : () => context.go(AppRoutes.login),
            child: Text('Back to Sign In', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );
  }

  Widget _buildCodeStep() {
    return Form(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _codeController,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: 6,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 24,
              letterSpacing: 8,
              fontWeight: FontWeight.w700,
            ),
            decoration: const InputDecoration(
              hintText: '••••••',
              counterText: '',
              prefixIcon: Icon(Icons.password_rounded),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'The code expires in $_codeTtlMinutes minutes. '
            'Didn\'t get it? Tap below to resend.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
                color: const Color(0xFF94A3B8), fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _loading ? null : _verifyCode,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text('Verify Code',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: _loading ? null : _sendCode,
            child: Text('Resend Code', style: GoogleFonts.poppins()),
          ),
          TextButton(
            onPressed: _loading
                ? null
                : () => setState(() => _step = 0),
            child: Text('Use a different email',
                style: GoogleFonts.poppins(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordStep() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _newPasswordController,
            obscureText: true,
            style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
            decoration: const InputDecoration(
              hintText: 'New Password',
              prefixIcon: Icon(Icons.lock_outline),
            ),
            validator: (v) =>
                v == null || v.length < 6 ? 'Minimum 6 characters' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _confirmController,
            obscureText: true,
            style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
            decoration: const InputDecoration(
              hintText: 'Confirm New Password',
              prefixIcon: Icon(Icons.lock_rounded),
            ),
            validator: (v) =>
                v != _newPasswordController.text ? 'Passwords do not match' : null,
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _loading ? null : _resetPassword,
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
                : Text('Reset Password',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: _loading ? null : () => setState(() => _step = 1),
            child: Text('Back', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _newPasswordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }
}