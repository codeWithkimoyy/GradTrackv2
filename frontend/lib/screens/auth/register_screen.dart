import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../constants/app_constants.dart';
import '../../providers/auth_providers.dart';
import '../../routes/app_router.dart';
import '../../services/auth_service.dart';
import '../../utils/app_snack_bar.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _courseController = TextEditingController(text: 'BS Computer Science');
  int _graduationYear = DateTime.now().year;

  bool _obscure = true;
  bool _acceptedTerms = false;
  bool _loading = false;

  late final AnimationController _entranceController;
  late final Animation<double> _fade;

  static const _primaryText = Colors.white;
  static const _secondaryText = Color(0xFFCEE7FF);
  static const _focusCyan = Color(0xFF5DDCFF);
  static const _fieldBorderColor = Color(0x33FFFFFF);
  static const _goldHighlight = Color(0xFFF59E0B);

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    )..forward();
    _fade = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      await ref.read(authServiceProvider).registerWithEmail(
            email: _emailController.text.trim(),
            password: _passwordController.text,
            fullName:
                '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}'
                    .trim(),
            graduationYear: _graduationYear,
            course: _courseController.text.trim(),
          );

      if (mounted) {
        showAppSnackBar(context, 'Account created! Please verify your email.',
            backgroundColor: AppColors.success);
        context.go(AppRoutes.dashboard);
      }
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, AuthService.friendlyError(e),
          backgroundColor: AppColors.error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final years = List.generate(15, (i) => DateTime.now().year - i);

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
              color: Color(0xDE003DA8),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final cardWidth =
                    (constraints.maxWidth * 0.90).clamp(0.0, 480.0);

                return Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                    physics: const ClampingScrollPhysics(),
                    child: FadeTransition(
                      opacity: _fade,
                      child: _buildGlassCard(
                        cardWidth: cardWidth,
                        maxHeight: double.infinity,
                        years: years,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassCard({
    required double cardWidth,
    required double maxHeight,
    required List<int> years,
  }) {
    final cardContentWidth = cardWidth - 48;

    return ConstrainedBox(
      constraints: maxHeight.isFinite
          ? BoxConstraints(maxWidth: cardWidth, maxHeight: maxHeight)
          : BoxConstraints(maxWidth: cardWidth),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              color: const Color(0xDD0A2B5E),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.40),
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
                      color: Colors.white.withValues(alpha: 0.35),
                    ),
                  ),
                ),
                Form(
                  key: _formKey,
                  child: SizedBox(
                    width: cardContentWidth,
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const _AuthLogo(),
                          const SizedBox(height: 10),
                          const _AuthTitle(),
                          const SizedBox(height: 6),
                          const _AuthSubtitle(),
                          const SizedBox(height: 16),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _glassField(
                                  TextFormField(
                                    controller: _firstNameController,
                                    style: _bodyStyle(),
                                    cursorColor: _focusCyan,
                                    decoration: _inputDecoration(
                                      hintText: 'First Name',
                                      prefixWidget: const Icon(
                                          Icons.person_outline,
                                          size: 20),
                                    ),
                                    validator: (v) => (v == null ||
                                            v.trim().isEmpty)
                                        ? 'Required'
                                        : null,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _glassField(
                                  TextFormField(
                                    controller: _lastNameController,
                                    style: _bodyStyle(),
                                    cursorColor: _focusCyan,
                                    decoration: _inputDecoration(
                                      hintText: 'Last Name',
                                      prefixWidget: const Icon(
                                          Icons.person_outline,
                                          size: 20),
                                    ),
                                    validator: (v) => (v == null ||
                                            v.trim().isEmpty)
                                        ? 'Required'
                                        : null,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _glassField(
                            TextFormField(
                              controller: _courseController,
                              style: _bodyStyle(),
                              cursorColor: _focusCyan,
                              decoration: _inputDecoration(
                                hintText: 'Course',
                                prefixWidget:
                                    const Icon(Icons.menu_book_outlined,
                                        size: 20),
                              ),
                              validator: (v) =>
                                  (v == null || v.isEmpty) ? 'Required' : null,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _glassField(
                            DropdownButtonFormField<int>(
                              initialValue: _graduationYear,
                              dropdownColor: const Color(0xFF0A3978),
                              isExpanded: true,
                              style: _bodyStyle(),
                              icon: const Icon(Icons.arrow_drop_down,
                                  color: Colors.white),
                              decoration: _inputDecoration(
                                hintText: 'Graduation Year',
                                prefixWidget: const Icon(
                                    Icons.calendar_month_outlined,
                                    size: 20),
                              ),
                              items: years
                                  .map((y) => DropdownMenuItem(
                                      value: y,
                                      child: Text(y.toString(),
                                          style: GoogleFonts.poppins(
                                            color: Colors.white,
                                            fontSize: 14,
                                          ))))
                                  .toList(),
                              onChanged: (v) => setState(
                                  () => _graduationYear = v ?? _graduationYear),
                            ),
                          ),
                          const SizedBox(height: 8),
                          _glassField(
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              style: _bodyStyle(),
                              cursorColor: _focusCyan,
                              decoration: _inputDecoration(
                                hintText: 'Email Address',
                                prefixWidget:
                                    const Icon(Icons.email_outlined, size: 20),
                              ),
                              validator: (v) => (v == null || !v.contains('@'))
                                  ? 'Enter a valid email'
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _glassField(
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscure,
                              style: _bodyStyle(),
                              cursorColor: _focusCyan,
                              decoration: _inputDecoration(
                                hintText: 'Password',
                                prefixWidget:
                                    const Icon(Icons.lock_outline, size: 20),
                                suffixWidget: IconButton(
                                  tooltip: _obscure
                                      ? 'Show password'
                                      : 'Hide password',
                                  icon: Icon(
                                    _obscure
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                    color: _secondaryText,
                                    size: 20,
                                  ),
                                  onPressed: () =>
                                      setState(() => _obscure = !_obscure),
                                ),
                              ),
                              validator: (v) => (v == null || v.length < 6)
                                  ? 'Minimum 6 characters'
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _glassField(
                            TextFormField(
                              controller: _confirmController,
                              obscureText: _obscure,
                              style: _bodyStyle(),
                              cursorColor: _focusCyan,
                              decoration: _inputDecoration(
                                hintText: 'Confirm Password',
                                prefixWidget:
                                    const Icon(Icons.lock_outline, size: 20),
                                suffixWidget: IconButton(
                                  tooltip: _obscure
                                      ? 'Show password'
                                      : 'Hide password',
                                  icon: Icon(
                                    _obscure
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                    color: _secondaryText,
                                    size: 20,
                                  ),
                                  onPressed: () =>
                                      setState(() => _obscure = !_obscure),
                                ),
                              ),
                              validator: (v) => v != _passwordController.text
                                  ? 'Passwords do not match'
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildTermsField(),
                          const SizedBox(height: 14),
                          _PrimaryButton(
                            loading: _loading,
                            onPressed: _loading ? null : _submit,
                            label: 'Create Account',
                          ),
                          const SizedBox(height: 10),
                          _PressableScale(
                            onTap: _loading ? null : _goBackToLogin,
                            child: OutlinedButton(
                              onPressed:
                                  _loading ? null : _goBackToLogin,
                              style: OutlinedButton.styleFrom(
                                fixedSize: const Size.fromHeight(50),
                                foregroundColor: Colors.white,
                                backgroundColor:
                                    Colors.white.withValues(alpha: 0.08),
                                overlayColor:
                                    Colors.white.withValues(alpha: 0.15),
                                side: const BorderSide(
                                  color: Color(0xFF5DDCFF),
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
                              child: const Text('Back to Login'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _goBackToLogin() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.login);
    }
  }

  Widget _buildTermsField() {
    return FormField<bool>(
      initialValue: _acceptedTerms,
      validator: (_) =>
          _acceptedTerms ? null : 'Please accept the terms to continue',
      builder: (field) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () {
              setState(() => _acceptedTerms = !_acceptedTerms);
              field.didChange(_acceptedTerms);
            },
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: Checkbox(
                      value: _acceptedTerms,
                      activeColor: const Color(0xFF159BFF),
                      checkColor: Colors.white,
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      side: const BorderSide(color: Color(0x99FFFFFF)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5),
                      ),
                      onChanged: (value) {
                        setState(() => _acceptedTerms = value ?? false);
                        field.didChange(_acceptedTerms);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text.rich(
                      const TextSpan(
                        children: [
                          TextSpan(text: 'I agree to the '),
                          TextSpan(
                            text: 'Terms of Service',
                            style: TextStyle(color: Color(0xFFFFC21A)),
                          ),
                          TextSpan(text: ' and '),
                          TextSpan(
                            text: 'Privacy Policy',
                            style: TextStyle(color: Color(0xFFFFC21A)),
                          ),
                        ],
                      ),
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 11,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (field.hasError)
            const Padding(
              padding: EdgeInsets.only(left: 12, top: 2),
              child: Text(
                'Please accept the terms to continue',
                style: TextStyle(color: Color(0xFFFFC4C4), fontSize: 11),
              ),
            ),
        ],
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
      fontSize: 14,
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
        fontSize: 14,
        fontWeight: FontWeight.w400,
      ),
      prefixIcon: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: prefixWidget,
      ),
      suffixIcon: suffixWidget,
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.12),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
    _entranceController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _courseController.dispose();
    super.dispose();
  }
}

class _AuthLogo extends StatelessWidget {
  const _AuthLogo();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 48,
        height: 48,
        child: Image.asset('assets/images/logo_full.png', fit: BoxFit.contain),
      ),
    );
  }
}

class _AuthTitle extends StatelessWidget {
  const _AuthTitle();

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      const TextSpan(
        children: [
          TextSpan(text: 'Create '),
          TextSpan(
            text: 'Account',
            style: TextStyle(color: _RegisterScreenState._goldHighlight),
          ),
        ],
      ),
      textAlign: TextAlign.center,
      style: GoogleFonts.poppins(
        color: Colors.white,
        fontSize: 28,
        height: 1.0,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _AuthSubtitle extends StatelessWidget {
  const _AuthSubtitle();

  @override
  Widget build(BuildContext context) {
    return Text(
      'Join the BISU Graduate Community',
      textAlign: TextAlign.center,
      style: GoogleFonts.poppins(
        color: Colors.white.withValues(alpha: 0.85),
        fontSize: 13,
        height: 1.3,
        fontWeight: FontWeight.w400,
        shadows: const [
          Shadow(color: Colors.black26, blurRadius: 10),
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
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
            color: enabled ? AppColors.primaryBlue : const Color(0xFF64748B),
            borderRadius: BorderRadius.circular(25),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: AppColors.primaryBlue.withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
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