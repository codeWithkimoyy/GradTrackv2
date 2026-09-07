import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../constants/app_constants.dart';
import '../../routes/app_router.dart';

const _deepNavy = Color(0xFF071E4A);

class _Feature {
  const _Feature(this.icon, this.title);

  final IconData icon;
  final String title;
}

class _PageData {
  const _PageData({
    required this.image,
    required this.titlePrefix,
    required this.titleHighlight,
    required this.subtitle,
    required this.features,
  });

  final String image;
  final String titlePrefix;
  final String titleHighlight;
  final String subtitle;
  final List<_Feature> features;
}

const _pages = [
  _PageData(
    image: 'assets/images/Splash1.png',
    titlePrefix: 'Welcome to',
    titleHighlight: 'GradTrack',
    subtitle:
        'Official alumni portal of Bohol Island State University. Verify your graduate identity and stay connected with your alma mater.',
    features: [
      _Feature(Icons.verified_user_rounded, 'Verified Alumni'),
      _Feature(Icons.school_rounded, 'Graduate Identity'),
      _Feature(Icons.cloud_done_rounded, 'University Sync'),
      _Feature(Icons.groups_rounded, 'Campus Network'),
    ],
  ),
  _PageData(
    image: 'assets/images/Splash2.jpeg',
    titlePrefix: 'Track Your',
    titleHighlight: 'Career Path',
    subtitle:
        'Record your employment timeline, archive verified certificates, and showcase career progression in one place.',
    features: [
      _Feature(Icons.work_rounded, 'Employment Timeline'),
      _Feature(Icons.workspace_premium_rounded, 'Certifications'),
      _Feature(Icons.trending_up_rounded, 'Career Milestones'),
      _Feature(Icons.stars_rounded, 'Skill Portfolios'),
    ],
  ),
  _PageData(
    image: 'assets/images/Splash3.jpeg',
    titlePrefix: 'Empower Future',
    titleHighlight: 'Graduates',
    subtitle:
        'Participate in institutional tracer surveys, unlock job opportunities, and engage with campus alumni initiatives.',
    features: [
      _Feature(Icons.fact_check_rounded, 'Tracer Survey'),
      _Feature(Icons.business_center_rounded, 'Career Hub'),
      _Feature(Icons.campaign_rounded, 'Announcements'),
      _Feature(Icons.event_rounded, 'Alumni Events'),
    ],
  ),
];

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ambientController;
  int _index = 0;
  double _dragDistance = 0;

  @override
  void initState() {
    super.initState();
    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
  }

  @override
  void dispose() {
    _ambientController.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_seen', true);
    if (mounted) context.go(AppRoutes.login);
  }

  void _showPage(int index) {
    if (index < 0 || index >= _pages.length || index == _index) return;
    setState(() => _index = index);
  }

  void _next() {
    if (_index == _pages.length - 1) {
      _finish();
    } else {
      _showPage(_index + 1);
    }
  }

  void _onDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    final shouldMove = _dragDistance.abs() > 45 || velocity.abs() > 450;
    if (shouldMove) {
      _showPage(_index + (_dragDistance < 0 || velocity < 0 ? 1 : -1));
    }
    _dragDistance = 0;
  }

  @override
  Widget build(BuildContext context) {
    final page = _pages[_index];
    return Scaffold(
      backgroundColor: _deepNavy,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragUpdate: (details) => _dragDistance += details.delta.dx,
        onHorizontalDragEnd: _onDragEnd,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _CrossfadeBackground(page: page, pageIndex: _index),
            AnimatedBuilder(
              animation: _ambientController,
              builder: (context, _) => CustomPaint(
                painter: _OnboardingAtmospherePainter(
                  progress: _ambientController.value,
                ),
              ),
            ),
            _FixedOnboardingLayout(
              page: page,
              pageIndex: _index,
              onSkip: _finish,
              onNext: _next,
              onPageSelected: _showPage,
            ),
          ],
        ),
      ),
    );
  }
}

class _CrossfadeBackground extends StatelessWidget {
  const _CrossfadeBackground({required this.page, required this.pageIndex});

  final _PageData page;
  final int pageIndex;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 420),
          switchInCurve: Curves.easeInOutCubic,
          switchOutCurve: Curves.easeInOutCubic,
          layoutBuilder: (currentChild, previousChildren) => Stack(
            fit: StackFit.expand,
            children: [
              ...previousChildren,
              if (currentChild != null) currentChild
            ],
          ),
          child: ColoredBox(
            key: ValueKey(page.image),
            color: _deepNavy,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 1.035, end: 1),
              duration: const Duration(milliseconds: 420),
              curve: Curves.easeInOutCubic,
              builder: (context, scale, child) => Transform.scale(
                scale: scale,
                alignment: Alignment.topCenter,
                child: child,
              ),
              child: pageIndex == 0
                  ? Image.asset(
                      page.image,
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                      filterQuality: FilterQuality.high,
                    )
                  : Align(
                      alignment: Alignment.topCenter,
                      child: FractionallySizedBox(
                        widthFactor: 1,
                        heightFactor: .58,
                        child: Image.asset(
                          page.image,
                          fit: BoxFit.fill,
                          filterQuality: FilterQuality.high,
                        ),
                      ),
                    ),
            ),
          ),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(color: Color(0xCC071E4A)),
        ),
      ],
    );
  }
}

class _FixedOnboardingLayout extends StatelessWidget {
  const _FixedOnboardingLayout({
    required this.page,
    required this.pageIndex,
    required this.onSkip,
    required this.onNext,
    required this.onPageSelected,
  });

  final _PageData page;
  final int pageIndex;
  final VoidCallback onSkip;
  final VoidCallback onNext;
  final ValueChanged<int> onPageSelected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(28, 18, 28, 12),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxHeight < 700;
              final titleSize = compact ? 32.0 : 38.0;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const _GradTrackLogo(),
                      const Spacer(),
                      _SkipButton(onPressed: onSkip),
                    ],
                  ),
                  const Spacer(),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(.04, 0),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    ),
                    child: Text.rich(
                      key: ValueKey(
                          '${page.titlePrefix}-${page.titleHighlight}'),
                      TextSpan(
                        children: [
                          TextSpan(text: '${page.titlePrefix}\n'),
                          TextSpan(
                            text: page.titleHighlight,
                            style: TextStyle(
                              color: AppColors.gold,
                              fontFamily: GoogleFonts.poppins().fontFamily,
                            ),
                          ),
                        ],
                      ),
                      maxLines: 2,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: titleSize,
                        height: 1.02,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  SizedBox(height: compact ? 20 : 36),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    child: Text(
                      page.subtitle,
                      key: ValueKey(page.subtitle),
                      maxLines: compact ? 4 : 5,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        color: Colors.white.withValues(alpha: .90),
                        fontSize: compact ? 13.0 : 14.5,
                        height: 1.45,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                  Flexible(
                    flex: 5,
                    fit: FlexFit.loose,
                    child: Padding(
                      padding: EdgeInsets.only(
                        top: compact ? 16 : 24,
                        bottom: compact ? 10 : 14,
                      ),
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight: compact ? 112 : 132,
                          ),
                          child: _MorphingFeatureGrid(
                            features: page.features,
                            compact: compact,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 48,
                    child: Row(
                      children: [
                        _PageIndicator(
                          index: pageIndex,
                          onSelected: onPageSelected,
                        ),
                        const Spacer(),
                        Flexible(
                          child: _NextButton(
                            isLast: pageIndex == _pages.length - 1,
                            onPressed: onNext,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _GradTrackLogo extends StatelessWidget {
  const _GradTrackLogo();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 126,
      height: 54,
      child: Image.asset(
        'assets/images/logo_full.png',
        fit: BoxFit.contain,
        alignment: Alignment.centerLeft,
      ),
    );
  }
}

class _SkipButton extends StatelessWidget {
  const _SkipButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: Colors.white70,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      ),
      child: Text(
        'Skip',
        style: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.white70,
        ),
      ),
    );
  }
}

class _MorphingFeatureGrid extends StatelessWidget {
  const _MorphingFeatureGrid({
    required this.features,
    this.compact = false,
  });

  final List<_Feature> features;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final spacing = compact ? 6.0 : 8.0;
    return Row(
      children: List.generate(features.length, (slot) {
        final feature = features[slot];
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: slot == features.length - 1 ? 0 : spacing,
            ),
            child: SizedBox(
              height: double.infinity,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                switchInCurve: Curves.easeInOutCubic,
                switchOutCurve: Curves.easeInOutCubic,
                child: _FeatureCard(
                  key: ValueKey('feature-$slot-${feature.title}'),
                  feature: feature,
                  compact: compact,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    super.key,
    required this.feature,
    this.compact = false,
  });

  final _Feature feature;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 4 : 6,
        vertical: compact ? 8 : 10,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.white.withValues(alpha: 0.14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            fit: FlexFit.loose,
            child: Container(
              width: compact ? 36 : 40,
              height: compact ? 36 : 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primaryBlue.withValues(alpha: 0.20),
              ),
              child: Icon(
                feature.icon,
                color: Colors.white,
                size: compact ? 20 : 24,
              ),
            ),
          ),
          SizedBox(height: compact ? 6 : 8),
          Expanded(
            child: Center(
              child: Text(
                feature.title,
                key: ValueKey(feature.title),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: compact ? 10.0 : 11.0,
                  height: 1.2,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PageIndicator extends StatelessWidget {
  const _PageIndicator({required this.index, required this.onSelected});

  final int index;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        _pages.length,
        (i) {
          final isActive = i == index;
          return GestureDetector(
            onTap: () => onSelected(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOutCubic,
              width: isActive ? 28 : 8,
              height: 7,
              margin: EdgeInsets.only(right: i == _pages.length - 1 ? 0 : 6),
              decoration: BoxDecoration(
                color: isActive ? AppColors.primaryBlue : Colors.white24,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _NextButton extends StatelessWidget {
  const _NextButton({required this.isLast, required this.onPressed});

  final bool isLast;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isLast ? 'Get Started' : 'Continue',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.20),
              ),
              child: const Icon(
                Icons.arrow_forward_rounded,
                size: 15,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingAtmospherePainter extends CustomPainter {
  _OnboardingAtmospherePainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < 14; i++) {
      final x = ((i * 79 + progress * 43) % (size.width + 30)) - 15;
      final y =
          ((i * 113 - progress * 38) % size.height + size.height) % size.height;
      final gold = i % 6 == 0;
      final color = gold ? AppColors.gold : const Color(0xFF9CCBFF);
      canvas.drawCircle(
        Offset(x, y),
        gold ? 2.2 : 1.4,
        Paint()
          ..color = color.withValues(alpha: gold ? .42 : .28)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
    }

    for (var i = 0; i < 3; i++) {
      final wave = Path()
        ..moveTo(-20, size.height * (.72 + i * .055))
        ..cubicTo(
          size.width * .25,
          size.height * (.66 + i * .045),
          size.width * .62,
          size.height * (.82 + i * .025),
          size.width + 25,
          size.height * (.72 + i * .045),
        );
      canvas.drawPath(
        wave,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = i == 0 ? 1.1 : .7
          ..color = Colors.white.withValues(alpha: .11 - i * .025),
      );
    }

    final pulse = .95 + math.sin(progress * math.pi * 2) * .04;
    canvas.drawCircle(
      Offset(size.width * .9, size.height * .3),
      size.width * .16 * pulse,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = .8
        ..color = Colors.white.withValues(alpha: .06),
    );
  }

  @override
  bool shouldRepaint(covariant _OnboardingAtmospherePainter oldDelegate) =>
      oldDelegate.progress != progress;
}
