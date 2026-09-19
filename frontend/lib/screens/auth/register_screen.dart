import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../constants/app_constants.dart';
import '../../providers/auth_providers.dart';
import '../../repositories/user_repository.dart';
import '../../routes/app_router.dart';
import '../../services/auth_service.dart';
import '../../utils/app_snack_bar.dart';
import '../../widgets/glass_auth_scaffold.dart';

/// Step 2 of alumni registration: only reachable after the Alumni ID was
/// verified on [VerifyAlumniIdScreen]. The office pre-registers bare IDs, so
/// the alumnus supplies their identity here (name, contact, birthdate) and it
/// lands on their record — the name appears on the ID once they sign up.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key, required this.alumniId});

  final String alumniId;

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

enum _RegisterGate { loading, notFound, pending, active, disabled }

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _birthdateController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  DateTime? _birthdate;
  bool _obscure = true;
  bool _loading = false;

  _RegisterGate _gate = _RegisterGate.loading;
  AlumniRegistryEntry? _entry;

  static final _emailPattern =
      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
  static final _phonePattern = RegExp(r'^[+\d][\d\s\-()]{5,19}$');

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
    try {
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
    } catch (e) {
      if (!mounted) return;
      setState(() => _gate = _RegisterGate.notFound);
      showAppSnackBar(context, AuthService.friendlyError(e),
          backgroundColor: AppColors.error);
    }
  }

  String? _validateName(String? value) {
    final val = (value ?? '').trim();
    if (val.isEmpty) return 'Enter your full name';
    final parts = val.split(',');
    if (parts.length < 2 ||
        parts[0].trim().isEmpty ||
        parts.sublist(1).join(',').trim().isEmpty) {
      return 'Use the format: Lastname, Firstname';
    }
    return null;
  }

  Future<void> _pickBirthdate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate:
          _birthdate ?? DateTime(now.year - 22, now.month, now.day),
      firstDate: DateTime(1950, 1, 1),
      lastDate: DateTime(now.year, now.month, now.day),
      helpText: 'Select your date of birth',
    );
    if (picked != null && mounted) {
      setState(() {
        _birthdate = picked;
        _birthdateController.text =
            DateFormat('MMMM d, yyyy').format(picked);
      });
    }
  }

  String? _birthdateText() {
    final birthdate = _birthdate;
    if (birthdate == null) return null;
    return DateFormat('yyyy-MM-dd').format(birthdate);
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    if (email.isEmpty && phone.isEmpty) {
      showAppSnackBar(
        context,
        'Provide an email address or a phone number.',
        backgroundColor: AppColors.error,
      );
      return;
    }
    if (_birthdate == null) {
      showAppSnackBar(context, 'Select your date of birth.',
          backgroundColor: AppColors.error);
      return;
    }
    setState(() => _loading = true);

    try {
      await ref.read(authServiceProvider).registerWithAlumniId(
            alumniId: widget.alumniId,
            password: _passwordController.text,
            fullName: _nameController.text,
            contactEmail: email.isEmpty ? null : email,
            phoneNumber: phone.isEmpty ? null : phone,
            birthdate: _birthdateText(),
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
                color: AppColors.primaryBlue,
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
        return 'Welcome, ${entry.fullName.trim()}! Fill in your details to '
            'activate your account.';
      }
      return 'Your Alumni ID is verified. Fill in your details to activate '
          'your account.';
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
        Icon(icon, size: 52, color: AppColors.primaryBlue),
        const SizedBox(height: 16),
        Text(
          message,
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            color: AppColors.textSecondary,
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

  InputDecoration _fieldDecoration({
    required String label,
    String? hint,
    String? helper,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      helperText: helper,
      prefixIcon: Icon(icon),
      suffixIcon: suffix,
    );
  }

  TextStyle _fieldStyle() {
    return GoogleFonts.poppins(
      color: AppColors.textPrimary,
      fontSize: 14,
      fontWeight: FontWeight.w500,
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
              color: AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
            decoration: _fieldDecoration(
              label: 'Verified Alumni ID',
              icon: Icons.badge_outlined,
              suffix: const Icon(Icons.lock_outline, size: 18),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            autocorrect: false,
            style: _fieldStyle(),
            decoration: _fieldDecoration(
              label: 'Full Name',
              hint: 'Lastname, Firstname',
              helper: 'Surname first, separated by a comma.',
              icon: Icons.person_outline_rounded,
            ),
            validator: _validateName,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            style: _fieldStyle(),
            decoration: _fieldDecoration(
              label: 'Email (optional if phone given)',
              hint: 'you@example.com',
              icon: Icons.email_outlined,
            ),
            validator: (v) {
              final val = (v ?? '').trim();
              if (val.isEmpty) return null;
              if (!_emailPattern.hasMatch(val)) {
                return 'Enter a valid email address';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            autocorrect: false,
            style: _fieldStyle(),
            decoration: _fieldDecoration(
              label: 'Phone Number (optional if email given)',
              hint: '+639171234567',
              icon: Icons.phone_outlined,
            ),
            validator: (v) {
              final val = (v ?? '').trim();
              if (val.isEmpty) return null;
              if (!_phonePattern.hasMatch(val)) {
                return 'Enter a valid phone number';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            readOnly: true,
            controller: _birthdateController,
            onTap: _loading ? null : _pickBirthdate,
            style: _fieldStyle(),
            decoration: _fieldDecoration(
              label: 'Date of Birth',
              icon: Icons.cake_outlined,
              suffix: const Icon(Icons.calendar_month_outlined),
            ),
            validator: (_) =>
                _birthdate == null ? 'Select your date of birth' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscure,
            style: _fieldStyle(),
            decoration: _fieldDecoration(
              label: 'Create Password',
              icon: Icons.lock_outline,
              suffix: IconButton(
                tooltip: _obscure ? 'Show password' : 'Hide password',
                icon: Icon(
                  _obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
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
            style: _fieldStyle(),
            decoration: _fieldDecoration(
              label: 'Confirm Password',
              icon: Icons.lock_rounded,
            ),
            validator: (v) => v != _passwordController.text
                ? 'Passwords do not match'
                : null,
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
            child: Text(
              'Back to Sign In',
              style: GoogleFonts.poppins(color: AppColors.primaryBlue),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _birthdateController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }
}
