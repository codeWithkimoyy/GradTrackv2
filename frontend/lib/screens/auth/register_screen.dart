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

/// Step 2 of alumni registration: only reachable after the Alumni ID was
/// verified on [VerifyAlumniIdScreen]. The ID is read-only; the alumni simply
/// chooses a password, which activates the account (Pending → Active).
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key, required this.alumniId});

  final String alumniId;

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

enum _RegisterGate { loading, notFound, pending, active, disabled }

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _obscure = true;
  bool _loading = false;

  _RegisterGate _gate = _RegisterGate.loading;
  AlumniRegistryEntry? _entry;

  @override
  void initState() {
    super.initState();
    _loadRegistry();
  }

  Future<void> _loadRegistry() async {
    final repo = ref.read(userRepositoryProvider);
    if (widget.alumniId.trim().isEmpty) {
      setState(() => _gate = _RegisterGate.notFound);
      return;
    }
    final entry = await repo.fetchRegistryEntry(widget.alumniId.trim());
    if (!mounted) return;
    setState(() {
      _entry = entry;
      _gate = entry == null
          ? _RegisterGate.notFound
          : switch (entry.status) {
              AlumniAccountStatus.pending => _RegisterGate.pending,
              AlumniAccountStatus.active => _RegisterGate.active,
              AlumniAccountStatus.disabled => _RegisterGate.disabled,
            };
    });
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _loading = true);

    try {
      await ref.read(authServiceProvider).registerWithAlumniId(
            alumniId: widget.alumniId,
            password: _passwordController.text,
          );

      if (mounted) {
        showAppSnackBar(
          context,
          'Account activated! Sign in with your Alumni ID.',
          backgroundColor: AppColors.success,
        );
        context.go(AppRoutes.login);
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

  @override
  Widget build(BuildContext context) {
    return GlassAuthScaffold(
      title: 'Create Account',
      subtitle: _subtitleText(),
      child: switch (_gate) {
        _RegisterGate.loading => const SizedBox(
            height: 120,
            child: Center(
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Color(0xFF5DDCFF),
              ),
            ),
          ),
        _RegisterGate.notFound => _buildNotAllowed(
            icon: Icons.person_search_outlined,
            message:
                'This Alumni ID is not in the registry. Please go back and '
                'verify your Alumni ID, or contact the Tracer Study '
                'Administrator.',
          ),
        _RegisterGate.active => _buildNotAllowed(
            icon: Icons.check_circle_outline,
            message:
                'This Alumni ID is already registered. Please sign in with '
                'your Alumni ID and password.',
            actionLabel: 'Sign In',
            onAction: () => context.go(AppRoutes.login),
          ),
        _RegisterGate.disabled => _buildNotAllowed(
            icon: Icons.block,
            message:
                'This Alumni ID has been disabled. Please contact the '
                'Tracer Study Administrator.',
          ),
        _RegisterGate.pending => _buildForm(),
      },
    );
  }

  String _subtitleText() {
    final entry = _entry;
    if (_gate == _RegisterGate.pending && entry != null) {
      if (entry.fullName.trim().isNotEmpty) {
        return 'Welcome, ${entry.fullName.trim()}! Choose a password to '
            'activate your account.';
      }
      return 'Choose a password to activate your account.';
    }
    return 'Complete your registration to activate your Alumni ID.';
  }

  Widget _buildNotAllowed({
    required IconData icon,
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        Icon(icon,
            size: 52, color: const Color(0xFFFFC21A).withValues(alpha: 0.9)),
        const SizedBox(height: 16),
        Text(
          message,
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            color: Colors.white.withValues(alpha: 0.88),
            fontSize: 13.5,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 22),
        ElevatedButton(
          onPressed: actionLabel != null
              ? onAction
              : () => context.go(AppRoutes.verifyAlumniId),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryBlue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: Text(actionLabel ?? 'Verify Alumni ID',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            initialValue: widget.alumniId,
            enabled: false,
            readOnly: true,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
            decoration: const InputDecoration(
              labelText: 'Verified Alumni ID',
              prefixIcon: Icon(Icons.badge_outlined),
              suffixIcon: Icon(Icons.lock_outline, size: 18),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscure,
            style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Create Password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                tooltip: _obscure ? 'Show password' : 'Hide password',
                icon: Icon(
                  _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  size: 20,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            validator: (v) =>
                (v == null || v.length < 6) ? 'Minimum 6 characters' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _confirmController,
            obscureText: _obscure,
            style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
            decoration: const InputDecoration(
              hintText: 'Confirm Password',
              prefixIcon: Icon(Icons.lock_rounded),
            ),
            validator: (v) =>
                v != _passwordController.text ? 'Passwords do not match' : null,
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _loading ? null : _submit,
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
                : Text('Create Account',
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

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }
}