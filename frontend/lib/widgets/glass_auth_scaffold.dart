import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_constants.dart';
import 'bisu_brand_logo.dart';

class GlassAuthScaffold extends StatefulWidget {
  const GlassAuthScaffold({
    super.key,
    required this.child,
    required this.title,
    this.subtitle,
  });

  final Widget child;
  final String title;
  final String? subtitle;

  @override
  State<GlassAuthScaffold> createState() => _GlassAuthScaffoldState();
}

class _GlassAuthScaffoldState extends State<GlassAuthScaffold>
    with TickerProviderStateMixin {
  late final AnimationController _entranceController;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    )..forward();
    _fade = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOutCubic,
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, .045),
      end: Offset.zero,
    ).animate(_fade);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.logoNavyDark,
      body: Stack(
        fit: StackFit.expand,
        children: [
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
          Container(
            color: AppColors.overlayNavyPhotoVeil,
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 370;
                final horizontal = compact ? 16.0 : 24.0;
                return SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                      horizontal, compact ? 20 : 32, horizontal, 28),
                  physics: const ClampingScrollPhysics(),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 480),
                      child: FadeTransition(
                        opacity: _fade,
                        child: SlideTransition(
                          position: _slide,
                          child: Column(
                            children: [
                              Container(
                                width: double.infinity,
                                padding: EdgeInsets.fromLTRB(
                                  compact ? 20 : 26,
                                  24,
                                  compact ? 20 : 26,
                                  28,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(22),
                                  color: Colors.white,
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
                                child: Theme(
                                  data: _glassTheme(context),
                                  child: Column(
                                    children: [
                                      const Center(
                                        child: BisuBrandLogo(size: 34),
                                      ),
                                      const SizedBox(height: 16),
                                      _AuthTitle(title: widget.title),
                                      if (widget.subtitle != null) ...[
                                        const SizedBox(height: 6),
                                        Text(
                                          widget.subtitle!,
                                          textAlign: TextAlign.center,
                                          style: GoogleFonts.poppins(
                                            color: AppColors.textSecondary,
                                            fontSize: compact ? 12 : 13,
                                            height: 1.4,
                                          ),
                                        ),
                                      ],
                                      const SizedBox(height: 20),
                                      widget.child,
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              const _SecurityFooter(),
                            ],
                          ),
                        ),
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

  ThemeData _glassTheme(BuildContext context) {
    final base = Theme.of(context);
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.outlineCard, width: 1.5),
    );
    return base.copyWith(
      textTheme: GoogleFonts.poppinsTextTheme(base.textTheme).apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceLightAlt,
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        hintStyle: const TextStyle(color: AppColors.textSecondary),
        prefixIconColor: AppColors.textSecondary,
        suffixIconColor: AppColors.textSecondary,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: const BorderSide(color: AppColors.primaryBlue, width: 1.8),
        ),
        errorBorder: border.copyWith(
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
        focusedErrorBorder: border.copyWith(
          borderSide: const BorderSide(color: AppColors.error, width: 1.8),
        ),
        errorStyle: const TextStyle(color: AppColors.error),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      dropdownMenuTheme: const DropdownMenuThemeData(),
    );
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }
}

class _AuthTitle extends StatelessWidget {
  const _AuthTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    if (title.contains('GradTrack')) {
      final prefix = title.replaceFirst('GradTrack', '').trimRight();
      return Text.rich(
        TextSpan(
          children: [
            if (prefix.isNotEmpty) TextSpan(text: '$prefix\n'),
            const TextSpan(text: 'Grad'),
            const TextSpan(
              text: 'Track',
              style: TextStyle(color: AppColors.primaryBlue),
            ),
          ],
        ),
        textAlign: TextAlign.center,
        style: GoogleFonts.poppins(
          color: AppColors.textPrimary,
          fontSize: 24,
          height: 1.15,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.6,
        ),
      );
    }
    final split = title.lastIndexOf(' ');
    final prefix = split > 0 ? title.substring(0, split + 1) : '';
    final highlight = split > 0 ? title.substring(split + 1) : title;
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: prefix),
          TextSpan(
            text: highlight,
            style: const TextStyle(color: AppColors.primaryBlue),
          ),
        ],
      ),
      textAlign: TextAlign.center,
      style: GoogleFonts.poppins(
        color: AppColors.textPrimary,
        fontSize: 23,
        height: 1.15,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.6,
      ),
    );
  }
}

class _SecurityFooter extends StatelessWidget {
  const _SecurityFooter();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.verified_user_outlined,
                color: Color(0xFFFFC21A), size: 21),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'Secure. Trusted. Connected.',
                style: GoogleFonts.poppins(color: Colors.white, fontSize: 12),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        Text(
          'Powered by BISU Bilar Campus',
          style: GoogleFonts.poppins(
            color: Colors.white.withOpacity(.76),
            fontSize: 11.5,
          ),
        ),
      ],
    );
  }
}
