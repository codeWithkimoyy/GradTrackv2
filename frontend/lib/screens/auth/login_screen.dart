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
import '../../widgets/bisu_brand_logo.dart';

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
      final identifier = _emailController.text.trim();
      await ref.read(authServiceProvider).signInWithEmail(
            email: AuthService.resolveIdentifier(identifier),
            password: _passwordController.text,
          );

      if (_rememberMe) {
        await _secureStorage.write(key: 'remembered_email', value: identifier);
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

  void _showError(String message) {
    if (!mounted) return;
    showAppSnackBar(context, message,
        backgroundColor: AppColors.error, duration: const Duration(seconds: 5));
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authStateProvider, (_, next) {
      if (next.valueOrNull != null && mounted) {
        context.go(AppRoutes.dashboard);
      }
    });
    return Scaffold(
      backgroundColor: AppColors.logoNavyDark,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Authentic Campus Background
          Image.asset(
            'assets/images/landing.jpg',
            fit: BoxFit.cover,
            alignment: Alignment.center,
            filterQuality: FilterQuality.high,
            errorBuilder: (context, error, stackTrace) => Image.asset(
              'assets/images/Splash.jpg',
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
            ),
          ),
          // Deep Navy Photo Veil Overlay
          Container(
            color: AppColors.overlayNavyPhotoVeil,
          ),
          // Content Layout
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 840;
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

  Widget _buildTopInstitutionalHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xCC031A48),
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.14),
            width: 1.5,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const BisuBrandLogo(inverted: true, size: 34),
          if (MediaQuery.sizeOf(context).width >= 700)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xD9071E4A),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.gold.withValues(alpha: 0.4),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: AppColors.gold,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Bohol Island State University Portal · AY 2026–2027',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout(BoxConstraints constraints) {
    final isCompact = constraints.maxWidth < 370;
    final cardWidth = (constraints.maxWidth * 0.92).clamp(260.0, 440.0);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        physics: const ClampingScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const BisuBrandLogo(inverted: true, size: 32),
            const SizedBox(height: 8),
            Text(
              'BOHOL ISLAND STATE UNIVERSITY',
              style: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Graduate Tracking System · AY 2026–2027',
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: const Color(0xFFDBEAFE),
              ),
            ),
            const SizedBox(height: 14),
            _buildWhiteLoginCard(
              cardWidth: cardWidth,
              isCompact: isCompact,
              showLogoInForm: false,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWideLayout(BoxConstraints constraints) {
    final isCompact = constraints.maxWidth < 1050;
    final shortScreen = constraints.maxHeight < 780;
    final cardWidth = (constraints.maxWidth * 0.40).clamp(380.0, 450.0);

    return Column(
      children: [
        _buildTopInstitutionalHeader(context),
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1320),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      flex: 12,
                      child: _buildBrandPanel(constraints, isCompact,
                          hideExtras: shortScreen),
                    ),
                    const SizedBox(width: 36),
                    Expanded(
                      flex: 10,
                      child: Center(
                        child: _buildWhiteLoginCard(
                          cardWidth: cardWidth,
                          isCompact: isCompact,
                          showLogoInForm: false,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBrandPanel(BoxConstraints constraints, bool isCompact,
      {bool hideExtras = false}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Eyebrow Tag
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0x8C003DA5),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: AppColors.primaryLightSkyCyan,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.auto_awesome_rounded,
                    size: 13, color: AppColors.logoGoldBright),
                const SizedBox(width: 7),
                Text(
                  'BOHOL ISLAND STATE UNIVERSITY · GRADUATES TRACKING SYSTEM',
                  style: GoogleFonts.poppins(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Main Inspiring Headline
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: 'From commencement to career —\n'),
                TextSpan(
                  text: "every BISU graduate's story matters.",
                  style: GoogleFonts.poppins(
                    color: AppColors.gold,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: isCompact ? 26 : 30,
              height: 1.15,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.8,
            ),
          ),
        ),
        const SizedBox(height: 12),

        Text(
          'GradTrack is the official university portal for tracking Bohol Island State University graduates. It records alumni career progress, monitors employment outcomes across batches, automates institutional tracer studies for CHED accreditation, and keeps alumni tightly connected.',
          style: GoogleFonts.poppins(
            color: const Color(0xFFDBEAFE),
            fontSize: 13.5,
            height: 1.45,
          ),
        ),
        if (!hideExtras) ...[
          const SizedBox(height: 18),

          // 4 Key Metrics Cards
          const Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _StatPill(
                value: '1,250',
                label: 'Graduates Tracked',
                desc: 'All academic programs',
              ),
              _StatPill(
                value: '73.6%',
                label: 'Employment Rate',
                desc: 'Verified career outcomes',
              ),
              _StatPill(
                value: '6',
                label: 'Graduation Batches',
                desc: 'Cohorts 2021 to 2026',
              ),
              _StatPill(
                value: '5',
                label: 'Campuses & Colleges',
                desc: 'Unified tracer database',
              ),
            ],
          ),
          const SizedBox(height: 18),

          // 3 Core Pillars
          const _PillarRow(
            icon: Icons.people_outline_rounded,
            title: 'Graduate Cohort Registry',
            desc:
                'Maintains official student dossiers, degree conferments, and verified contact profiles.',
          ),
          const SizedBox(height: 8),
          const _PillarRow(
            icon: Icons.work_outline_rounded,
            title: 'Employment & Career Tracing',
            desc:
                'Tracks company placements, job roles, industries, and entrepreneurship post-graduation.',
          ),
          const SizedBox(height: 8),
          const _PillarRow(
            icon: Icons.analytics_outlined,
            title: 'Institutional Tracer Analytics',
            desc:
                'Generates real-time accreditation-ready metrics and longitudinal cohort reports.',
          ),
          const SizedBox(height: 14),

          Text(
            '© 2026 Bohol Island State University · GradTrack System · Alumni Relations Office',
            style: GoogleFonts.poppins(
              fontSize: 10.5,
              color: const Color(0xFF93C5FD),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildWhiteLoginCard({
    required double cardWidth,
    required bool isCompact,
    bool showLogoInForm = false,
  }) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: cardWidth),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(isCompact ? 20 : 26),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: AppColors.outlineCard,
            width: 1.5,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x40001F5B),
              blurRadius: 36,
              offset: Offset(0, 16),
            ),
          ],
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showLogoInForm) ...[
                const Center(child: BisuBrandLogo(size: 34)),
                const SizedBox(height: 12),
              ],

              // Eyebrow
              Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: AppColors.primaryBlue,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'PORTAL ACCESS',
                    style: GoogleFonts.poppins(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                      color: AppColors.bisuOfficialPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),

              Text(
                'Sign In to Portal',
                style: GoogleFonts.poppins(
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 3),

              Text(
                'Enter your university credentials to continue.',
                style: GoogleFonts.poppins(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 18),

              // Alumni ID or Email
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.text,
                autocorrect: false,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
                cursorColor: AppColors.primaryBlue,
                decoration: _fieldDecoration(
                  hintText: 'Alumni ID or Email',
                  prefixIcon: Icons.badge_outlined,
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Enter your Alumni ID or email'
                    : null,
              ),
              const Padding(
                padding: EdgeInsets.only(left: 4, top: 4),
                child: Text(
                  'Alumni sign in with your Alumni ID. Administrators use email.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10.5,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Password
              TextFormField(
                controller: _passwordController,
                obscureText: _obscure,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
                cursorColor: AppColors.primaryBlue,
                decoration: _fieldDecoration(
                  hintText: 'Password',
                  prefixIcon: Icons.lock_outline_rounded,
                  suffixWidget: IconButton(
                    tooltip: _obscure ? 'Show password' : 'Hide password',
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: AppColors.textSecondary,
                      size: 19,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                validator: (v) => (v == null || v.length < 6)
                    ? 'Minimum 6 characters'
                    : null,
              ),
              const SizedBox(height: 10),

              // Remember Me & Forgot Password
              _AccountActionsRow(
                rememberMe: _rememberMe,
                onRememberChanged: (v) => setState(() => _rememberMe = v),
                onForgotPassword: () => context.push(AppRoutes.forgotPassword),
              ),
              const SizedBox(height: 16),

              // Sign In Primary Button
              _PrimarySignInButton(
                loading: _loading,
                onPressed: _loading ? null : _submit,
              ),
              const SizedBox(height: 16),

              // Create Account Link
              Center(
                child: Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      "Don't have an account? ",
                      style: GoogleFonts.poppins(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    InkWell(
                      onTap: _loading
                          ? null
                          : () => context.push(AppRoutes.verifyAlumniId),
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 2, vertical: 4),
                        child: Text(
                          'Create Account',
                          style: GoogleFonts.poppins(
                            color: AppColors.primaryBlue,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            decoration: TextDecoration.underline,
                            decorationColor: AppColors.primaryBlue,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              Center(
                child: Text(
                  '${AppStrings.appName} · Bohol Island State University',
                  style: GoogleFonts.poppins(
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration({
    required String hintText,
    required IconData prefixIcon,
    Widget? suffixWidget,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: GoogleFonts.poppins(
        color: AppColors.textSecondary,
        fontSize: 13.5,
        fontWeight: FontWeight.w400,
      ),
      prefixIcon: Icon(prefixIcon, size: 19, color: AppColors.textSecondary),
      suffixIcon: suffixWidget,
      filled: true,
      fillColor: AppColors.surfaceLightAlt,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      isDense: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.outlineCard, width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.outlineCard, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primaryBlue, width: 1.8),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.error, width: 1.5),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}

class _StatPill extends StatelessWidget {
  final String value;
  final String label;
  final String desc;

  const _StatPill({
    required this.value,
    required this.label,
    required this.desc,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 145,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outlineCard, width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 3,
                height: 18,
                color: AppColors.primaryBlue,
              ),
              const SizedBox(width: 6),
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.bisuOfficialPrimary,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          Text(
            desc,
            style: GoogleFonts.poppins(
              fontSize: 9,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _PillarRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String desc;

  const _PillarRow({
    required this.icon,
    required this.title,
    required this.desc,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xB3071E4A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0x593B82F6),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.primaryBlue,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                Text(
                  desc,
                  style: GoogleFonts.poppins(
                    fontSize: 10.5,
                    color: const Color(0xFFBFDBFE),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountActionsRow extends StatelessWidget {
  final bool rememberMe;
  final ValueChanged<bool> onRememberChanged;
  final VoidCallback onForgotPassword;

  const _AccountActionsRow({
    required this.rememberMe,
    required this.onRememberChanged,
    required this.onForgotPassword,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 4,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => onRememberChanged(!rememberMe),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: Checkbox(
                  value: rememberMe,
                  activeColor: AppColors.primaryBlue,
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  side: const BorderSide(
                    color: AppColors.outlineCard,
                    width: 1.5,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                  onChanged: (v) => onRememberChanged(v ?? true),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Remember Me',
                style: GoogleFonts.poppins(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: onForgotPassword,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            foregroundColor: AppColors.primaryBlue,
          ),
          child: Text(
            'Forgot Password?',
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryBlue,
            ),
          ),
        ),
      ],
    );
  }
}

class _PrimarySignInButton extends StatelessWidget {
  final bool loading;
  final VoidCallback? onPressed;

  const _PrimarySignInButton({
    required this.loading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: Ink(
        height: 48,
        decoration: BoxDecoration(
          color: onPressed != null ? AppColors.primaryBlue : const Color(0xFF94A3B8),
          borderRadius: BorderRadius.circular(12),
          boxShadow: onPressed != null
              ? const [
                  BoxShadow(
                    color: Color(0x33003DA5),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: loading
                ? const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Sign In',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
