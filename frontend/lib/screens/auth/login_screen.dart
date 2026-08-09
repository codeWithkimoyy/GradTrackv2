import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../constants/app_constants.dart';
import '../../providers/auth_providers.dart';
import '../../routes/app_router.dart';
import '../../services/auth_service.dart';
import '../../utils/app_snack_bar.dart';
import '../../widgets/glass_auth_scaffold.dart';
import '../../widgets/google_logo.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _secureStorage = const FlutterSecureStorage();

  bool _obscure = true;
  bool _rememberMe = true;
  bool _loading = false;

  static const _primaryText = Colors.white;
  static const _secondaryText = Color(0xFFCEE7FF);
  static const _placeholderText = Color(0xFFDBECFF);
  static const _borderColor = Color(0x66FFFFFF);
  static const _accentBlue = Color(0xFFFFC21A);
  static const _buttonBlue = Color(0xFF05BFFF);
  static const _buttonPressedBlue = Color(0xFF2457F5);

  @override
  void initState() {
    super.initState();
    _loadRememberedEmail();
  }

  Future<void> _loadRememberedEmail() async {
    final savedEmail = await _secureStorage.read(key: 'remembered_email');
    if (savedEmail != null) {
      _emailController.text = savedEmail;
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      await ref.read(authServiceProvider).signInWithEmail(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );

      if (_rememberMe) {
        await _secureStorage.write(
            key: 'remembered_email', value: _emailController.text.trim());
      } else {
        await _secureStorage.delete(key: 'remembered_email');
      }

      if (mounted) context.go(AppRoutes.dashboard);
    } catch (e) {
      _showError(AuthService.friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _loading = true);
    try {
      final result = await ref.read(authServiceProvider).signInWithGoogle();
      if (result != null && mounted) context.go(AppRoutes.dashboard);
    } catch (e) {
      _showError(AuthService.friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    showAppSnackBar(context, message,
        backgroundColor: AppColors.error, duration: const Duration(seconds: 5));
  }

  @override
  Widget build(BuildContext context) {
    return GlassAuthScaffold(
      title: 'Welcome to GradTrack',
      subtitle:
          'Graduate Tracking System\nBohol Island State University - Bilar Campus',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 310;

          return Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: _bodyStyle(),
                  cursorColor: _accentBlue,
                  decoration: _inputDecoration(
                    hintText: 'Email Address',
                    prefixIcon: Icons.email_outlined,
                  ),
                  validator: (v) => (v == null || !v.contains('@'))
                      ? 'Enter a valid email'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscure,
                  style: _bodyStyle(),
                  cursorColor: _accentBlue,
                  decoration: _inputDecoration(
                    hintText: 'Password',
                    prefixIcon: Icons.lock_outline,
                    suffixIcon: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      transitionBuilder: (child, animation) => ScaleTransition(
                        scale: animation,
                        child: FadeTransition(opacity: animation, child: child),
                      ),
                      child: IconButton(
                        key: ValueKey(_obscure),
                        tooltip: _obscure ? 'Show password' : 'Hide password',
                        icon: Icon(
                          _obscure
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: _secondaryText,
                          size: 22,
                        ),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                  ),
                  validator: (v) => (v == null || v.length < 6)
                      ? 'Minimum 6 characters'
                      : null,
                ),
                const SizedBox(height: 16),
                _AccountActionsRow(
                  rememberMe: _rememberMe,
                  isCompact: isCompact,
                  onRememberChanged: (value) =>
                      setState(() => _rememberMe = value),
                  onForgotPassword: () =>
                      context.push(AppRoutes.forgotPassword),
                ),
                const SizedBox(height: 24),
                _GradientButton(
                  loading: _loading,
                  onPressed: _loading ? null : _submit,
                  label: 'Sign In',
                ),
                const SizedBox(height: 14),
                OutlinedButton(
                  onPressed:
                      _loading ? null : () => context.push(AppRoutes.register),
                  style: OutlinedButton.styleFrom(
                    fixedSize: const Size.fromHeight(56),
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFF78CDFF)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                    textStyle: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: const Text('Create Account'),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    const Expanded(child: Divider(color: Color(0x66FFFFFF))),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'OR',
                        style: GoogleFonts.poppins(
                          color: _secondaryText,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const Expanded(child: Divider(color: Color(0x66FFFFFF))),
                  ],
                ),
                const SizedBox(height: 20),
                _PressableScale(
                  onTap: _loading ? null : _signInWithGoogle,
                  child: OutlinedButton.icon(
                    onPressed: _loading ? null : _signInWithGoogle,
                    icon: const GoogleLogo(size: 22),
                    label: const Text('Continue with Google'),
                    style: OutlinedButton.styleFrom(
                      fixedSize: const Size.fromHeight(56),
                      foregroundColor: const Color(0xFF102556),
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: _borderColor),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      textStyle: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  TextStyle _bodyStyle() {
    return GoogleFonts.poppins(
      color: _primaryText,
      fontSize: 15,
      fontWeight: FontWeight.w400,
    );
  }

  InputDecoration _inputDecoration({
    required String hintText,
    required IconData prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: GoogleFonts.poppins(
        color: _placeholderText,
        fontSize: 15,
        fontWeight: FontWeight.w400,
      ),
      prefixIcon: Icon(prefixIcon, color: _secondaryText, size: 22),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white.withValues(alpha: .10),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      enabledBorder: _fieldBorder(_borderColor, 1),
      focusedBorder: _fieldBorder(_accentBlue, 1.6),
      errorBorder: _fieldBorder(AppColors.error, 1),
      focusedErrorBorder: _fieldBorder(AppColors.error, 1.4),
    );
  }

  OutlineInputBorder _fieldBorder(Color color, double width) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}

class _AccountActionsRow extends StatelessWidget {
  const _AccountActionsRow({
    required this.rememberMe,
    required this.isCompact,
    required this.onRememberChanged,
    required this.onForgotPassword,
  });

  final bool rememberMe;
  final bool isCompact;
  final ValueChanged<bool> onRememberChanged;
  final VoidCallback onForgotPassword;

  @override
  Widget build(BuildContext context) {
    final fontSize = isCompact ? 13.0 : 15.0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Flexible(
          fit: FlexFit.loose,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => onRememberChanged(!rememberMe),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    value: rememberMe,
                    activeColor: _LoginScreenState._accentBlue,
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    side: const BorderSide(
                      color: _LoginScreenState._borderColor,
                      width: 1.4,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    onChanged: (v) => onRememberChanged(v ?? true),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Remember Me',
                      maxLines: 1,
                      softWrap: false,
                      style: GoogleFonts.poppins(
                        color: _LoginScreenState._primaryText,
                        fontSize: fontSize,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          fit: FlexFit.tight,
          child: Align(
            alignment: Alignment.centerRight,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onForgotPassword,
                style: TextButton.styleFrom(
                  minimumSize: Size.zero,
                  padding: EdgeInsets.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  foregroundColor: _LoginScreenState._accentBlue,
                  textStyle: GoogleFonts.poppins(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                child: const Text(
                  'Forgot Password?',
                  maxLines: 1,
                  softWrap: false,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _GradientButton extends StatelessWidget {
  const _GradientButton({
    required this.loading,
    required this.onPressed,
    required this.label,
  });

  final bool loading;
  final VoidCallback? onPressed;
  final String label;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;

    return _PressableScale(
      onTap: onPressed,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(28),
        child: Ink(
          height: 56,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: enabled
                  ? const [
                      _LoginScreenState._buttonBlue,
                      _LoginScreenState._buttonPressedBlue,
                    ]
                  : const [
                      Color(0xFF93A4C7),
                      Color(0xFF93A4C7),
                    ],
            ),
            borderRadius: BorderRadius.circular(28),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color:
                          _LoginScreenState._buttonBlue.withValues(alpha: 0.28),
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                    ),
                  ]
                : null,
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(28),
            splashColor: Colors.white.withValues(alpha: 0.18),
            highlightColor: Colors.white.withValues(alpha: 0.08),
            onTap: onPressed,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      children: [
                        const SizedBox(width: 38),
                        Expanded(
                          child: Text(
                            label,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: .82),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.arrow_forward_ios_rounded,
                            color: Color(0xFF2457F5),
                            size: 18,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PressableScale extends StatefulWidget {
  const _PressableScale({
    required this.child,
    required this.onTap,
  });

  final Widget child;
  final VoidCallback? onTap;

  @override
  State<_PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<_PressableScale> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (widget.onTap == null || _pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _setPressed(true),
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
