import 'dart:ui';

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
  static const _borderColor = Color(0x66FFFFFF);
  static const _accentBlue = Color(0xFFFFC21A);
  static const _fieldBorderColor = Color(0x33FFFFFF);
  static const _focusCyan = Color(0xFF5DDCFF);

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
    return Scaffold(
      backgroundColor: const Color(0xFF031A48),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/Splash.jpg',
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            filterQuality: FilterQuality.high,
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0, .28, .58, 1],
                colors: [
                  Color(0x66000000),
                  Color(0x33000000),
                  Color(0xCC003DA8),
                  Color(0xFF003DA8),
                ],
              ),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 820;
                return isWide
                    ? _buildWideLayout(constraints)
                    : _buildMobileLayout(constraints);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout(BoxConstraints constraints) {
    final isCompact = constraints.maxWidth < 370;
    final maxCardHeight = constraints.maxHeight * 0.82;
    final cardWidth = (constraints.maxWidth * 0.88).clamp(0.0, 460.0);

    return Column(
      children: [
        const Expanded(child: SizedBox.shrink()),
        FractionallySizedBox(
          widthFactor: 0.88,
          child: _buildGlassCard(
            cardWidth: cardWidth,
            maxHeight: maxCardHeight,
            isCompact: isCompact,
          ),
        ),
        const Expanded(child: SizedBox.shrink()),
      ],
    );
  }

  Widget _buildWideLayout(BoxConstraints constraints) {
    final isCompact = constraints.maxWidth < 1000;
    final maxCardHeight = constraints.maxHeight * 0.86;
    final cardWidth = (constraints.maxWidth * 0.38).clamp(380.0, 440.0);

    return Row(
      children: [
        Expanded(
          child: _buildBrandPanel(constraints, isCompact),
        ),
        Expanded(
          child: Center(
            child: _buildGlassCard(
              cardWidth: cardWidth,
              maxHeight: maxCardHeight,
              isCompact: isCompact,
              showLogoInForm: false,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBrandPanel(BoxConstraints constraints, bool isCompact) {
    final fontSize = isCompact ? 34.0 : 42.0;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 56,
                    height: 56,
                    child: Image.asset(
                      'assets/images/logo_full.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Text(
                'Welcome to\nGradTrack',
                textAlign: TextAlign.left,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: fontSize,
                  height: 1.05,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Graduate Tracking System',
                style: GoogleFonts.poppins(
                  color: Colors.white.withValues(alpha: 0.95),
                  fontSize: isCompact ? 16 : 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Bohol Island State University - Bilar Campus',
                style: GoogleFonts.poppins(
                  color: Colors.white.withValues(alpha: 0.80),
                  fontSize: isCompact ? 13 : 15,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 26),
              const _FeatureLine(
                icon: Icons.verified_user_outlined,
                text: 'Track your graduate journey',
              ),
              const SizedBox(height: 14),
              const _FeatureLine(
                icon: Icons.handshake_outlined,
                text: 'Connect with your alumni community',
              ),
              const SizedBox(height: 14),
              const _FeatureLine(
                icon: Icons.insights_outlined,
                text: 'Shape the university\u2019s future outcomes',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGlassCard({
    required double cardWidth,
    required double maxHeight,
    required bool isCompact,
    bool showLogoInForm = true,
  }) {
    final cardContentWidth = cardWidth - 48;

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: cardWidth, maxHeight: maxHeight),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              color: Colors.white.withValues(alpha: 0.12),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.25),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.20),
                  blurRadius: 30,
                  offset: const Offset(0, 18),
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned(
                  top: 0,
                  left: 16,
                  right: 16,
                  child: Container(
                    height: 1.5,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Colors.white.withValues(alpha: 0),
                          Colors.white.withValues(alpha: 0.55),
                          Colors.white.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
                _buildFormContent(
                  cardContentWidth: cardContentWidth,
                  maxHeight: maxHeight - 44,
                  isCompact: isCompact,
                  showLogoInForm: showLogoInForm,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormContent({
    required double cardContentWidth,
    required double maxHeight,
    required bool isCompact,
    required bool showLogoInForm,
  }) {
    return Form(
      key: _formKey,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: cardContentWidth,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 18),
              if (showLogoInForm) _AuthLogo(),
              if (showLogoInForm) const SizedBox(height: 12),
              _AuthTitle(isCompact: isCompact),
              const SizedBox(height: 8),
              _AuthSubtitle(isCompact: isCompact),
              const SizedBox(height: 18),
              _glassField(
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: _bodyStyle(),
                  cursorColor: _focusCyan,
                  decoration: _inputDecoration(
                    hintText: 'Email Address',
                    prefixWidget: const Icon(Icons.email_outlined, size: 20),
                  ),
                  validator: (v) =>
                      (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
                ),
              ),
              const SizedBox(height: 10),
              _glassField(
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscure,
                  style: _bodyStyle(),
                  cursorColor: _focusCyan,
                  decoration: _inputDecoration(
                    hintText: 'Password',
                    prefixWidget: const Icon(Icons.lock_outline, size: 20),
                    suffixWidget: AnimatedSwitcher(
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
                          size: 20,
                        ),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                  ),
                  validator: (v) => (v == null || v.length < 6)
                      ? 'Minimum 6 characters'
                      : null,
                ),
              ),
              const SizedBox(height: 12),
              _AccountActionsRow(
                rememberMe: _rememberMe,
                isCompact: isCompact,
                onRememberChanged: (value) => setState(() => _rememberMe = value),
                onForgotPassword: () => context.push(AppRoutes.forgotPassword),
              ),
              const SizedBox(height: 16),
              _GradientButton(
                loading: _loading,
                onPressed: _loading ? null : _submit,
                label: 'Sign In',
              ),
              const SizedBox(height: 10),
              _PressableScale(
                onTap: _loading ? null : () => context.push(AppRoutes.register),
                child: OutlinedButton(
                  onPressed:
                      _loading ? null : () => context.push(AppRoutes.register),
                  style: OutlinedButton.styleFrom(
                    fixedSize: const Size.fromHeight(46),
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.white.withValues(alpha: 0.06),
                    overlayColor: Colors.white.withValues(alpha: 0.15),
                    side: BorderSide(
                      color: const Color(0xFF5DDCFF).withValues(alpha: 0.9),
                      width: 1.3,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(23),
                    ),
                    textStyle: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: const Text('Create Account'),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Expanded(child: Divider(color: Color(0x66FFFFFF))),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'OR',
                      style: GoogleFonts.poppins(
                        color: _secondaryText,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const Expanded(child: Divider(color: Color(0x66FFFFFF))),
                ],
              ),
              const SizedBox(height: 14),
              _PressableScale(
                onTap: _loading ? null : _signInWithGoogle,
                child: OutlinedButton.icon(
                  onPressed: _loading ? null : _signInWithGoogle,
                  icon: const GoogleLogo(size: 20),
                  label: const Text('Continue with Google'),
                  style: OutlinedButton.styleFrom(
                    fixedSize: const Size.fromHeight(48),
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.white.withValues(alpha: 0.22),
                    side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.30)),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    textStyle: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _glassField(Widget field) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: field,
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
    required Widget prefixWidget,
    Widget? suffixWidget,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: GoogleFonts.poppins(
        color: Colors.white.withValues(alpha: 0.70),
        fontSize: 15,
        fontWeight: FontWeight.w400,
      ),
      prefixIcon: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: prefixWidget,
      ),
      suffixIcon: suffixWidget,
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.10),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      isDense: true,
      enabledBorder: _fieldBorder(_fieldBorderColor, 1),
      focusedBorder: _fieldBorder(_focusCyan, 1.6),
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

class _AuthLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 56,
        height: 56,
        child: Image.asset('assets/images/logo_full.png', fit: BoxFit.contain),
      ),
    );
  }
}

class _AuthTitle extends StatelessWidget {
  const _AuthTitle({required this.isCompact});

  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    final fontSize = isCompact ? 28.0 : 32.0;
    return Text.rich(
      const TextSpan(
        children: [
          TextSpan(text: 'Welcome to '),
          TextSpan(
            text: 'GradTrack',
            style: TextStyle(color: Color(0xFFF59E0B)),
          ),
        ],
      ),
      textAlign: TextAlign.center,
      style: GoogleFonts.poppins(
        color: Colors.white,
        fontSize: fontSize,
        height: 1.0,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _AuthSubtitle extends StatelessWidget {
  const _AuthSubtitle({required this.isCompact});

  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    return Text(
      'Graduate Tracking System\nBohol Island State University - Bilar Campus',
      textAlign: TextAlign.center,
      style: GoogleFonts.poppins(
        color: Colors.white.withValues(alpha: 0.85),
        fontSize: isCompact ? 12.5 : 14,
        height: 1.3,
        fontWeight: FontWeight.w400,
        shadows: const [
          Shadow(
            color: Colors.black26,
            blurRadius: 10,
          ),
        ],
      ),
    );
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => onRememberChanged(!rememberMe),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
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
                      borderRadius: BorderRadius.circular(5),
                    ),
                    onChanged: (v) => onRememberChanged(v ?? true),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Remember Me',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      color: _LoginScreenState._primaryText,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        TextButton(
          onPressed: onForgotPassword,
          style: TextButton.styleFrom(
            minimumSize: Size.zero,
            padding: EdgeInsets.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            foregroundColor: _LoginScreenState._accentBlue,
            textStyle: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          child: const Text('Forgot Password?'),
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
        borderRadius: BorderRadius.circular(25),
        child: Ink(
          height: 50,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: enabled
                  ? const [
                      Color(0xFF19C2FF),
                      Color(0xFF2D7DFF),
                      Color(0xFF4C5DFF),
                    ]
                  : const [
                      Color(0xFF93A4C7),
                      Color(0xFF93A4C7),
                    ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(25),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: const Color(0xFF19C2FF).withValues(alpha: 0.35),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(25),
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
                        const SizedBox(width: 36),
                        Expanded(
                          child: Text(
                            label,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Container(
                          width: 36,
                          height: 36,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.arrow_forward_ios_rounded,
                            color: Color(0xFF2457F5),
                            size: 16,
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

class _FeatureLine extends StatelessWidget {
  const _FeatureLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
          ),
          child: Icon(icon, color: const Color(0xFF5DDCFF), size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.poppins(
              color: Colors.white.withValues(alpha: 0.92),
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
