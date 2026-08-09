import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../routes/app_router.dart';

const _deepNavy = Color(0xFF081B33);
const _accentGold = Color(0xFFF59E0B);

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
        'Stay connected with Bohol Island State University beyond graduation. Manage your graduate profile, employment records, certifications, and alumni engagement - all in one secure platform.',
    features: [
      _Feature(Icons.person_outline_rounded, 'Graduate Profile'),
      _Feature(Icons.work_outline_rounded, 'Employment Records'),
      _Feature(Icons.workspace_premium_outlined, 'Certificates'),
      _Feature(Icons.cloud_done_outlined, 'Cloud Sync'),
    ],
  ),
  _PageData(
    image: 'assets/images/Splash2.jpeg',
    titlePrefix: 'Track Your',
    titleHighlight: 'Career Journey',
    subtitle:
        'Monitor your employment status, upload certifications, showcase achievements, and build your professional portfolio throughout your career.',
    features: [
      _Feature(Icons.person_rounded, 'Employed'),
      _Feature(Icons.trending_up_rounded, 'Career Growth'),
      _Feature(Icons.emoji_events_rounded, 'Promotion'),
      _Feature(Icons.business_center_outlined, 'Experience'),
      _Feature(Icons.verified_outlined, 'Certifications'),
      _Feature(Icons.star_rounded, 'Skills'),
    ],
  ),
  _PageData(
    image: 'assets/images/Splash3.jpeg',
    titlePrefix: 'Join the BISU',
    titleHighlight: 'Alumni Community',
    subtitle:
        'Receive university announcements, answer graduate tracer surveys, discover career opportunities, reconnect with classmates, and stay engaged with the BISU alumni network.',
    features: [
      _Feature(Icons.event_outlined, 'Upcoming Events'),
      _Feature(Icons.campaign_outlined, 'Announcements'),
      _Feature(Icons.work_outline_rounded, 'Job Opportunities'),
      _Feature(Icons.fact_check_outlined, 'Tracer Survey'),
      _Feature(Icons.groups_outlined, 'Alumni Activities'),
      _Feature(Icons.groups_outlined, 'Community'),
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
            color: const Color(0xFF1670D8),
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
          decoration: BoxDecoration(color: Color(0x26030C1C)),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [0, .30, .48, .72, 1],
              colors: [
                Color(0x08071A35),
                Color(0x180A66FF),
                Color(0xB70A4EBA),
                Color(0xEC1262D6),
                Color(0xFF69A4EE),
              ],
            ),
          ),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: .95,
              colors: [Colors.transparent, Color(0x78020A17)],
              stops: [.48, 1],
            ),
          ),
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
              final titleSize = compact ? 34.0 : 40.0;
              final isWelcome = pageIndex == 0;
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
                            style: const TextStyle(color: _accentGold),
                          ),
                        ],
                      ),
                      maxLines: 2,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: titleSize,
                        height: .98,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                        shadows: const [
                          Shadow(color: Color(0x73000000), blurRadius: 18),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: compact ? 14 : 18),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    child: Text(
                      page.subtitle,
                      key: ValueKey(page.subtitle),
                      maxLines: 5,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .92),
                        fontSize: compact ? 12 : 13.5,
                        height: 1.5,
                        fontWeight: FontWeight.w500,
                        shadows: const [
                          Shadow(color: Color(0x55000000), blurRadius: 8),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: compact ? 20 : 28),
                  SizedBox(
                    height: isWelcome
                        ? (compact ? 112 : 132)
                        : (compact ? 210 : 242),
                    child: _MorphingFeatureGrid(
                      features: page.features,
                      pageIndex: pageIndex,
                    ),
                  ),
                  SizedBox(height: compact ? 10 : 14),
                  SizedBox(
                    height: 48,
                    child: Row(
                      children: [
                        Expanded(
                          child: _PageIndicator(
                            index: pageIndex,
                            onSelected: onPageSelected,
                          ),
                        ),
                        const SizedBox(width: 18),
                        _NextButton(
                          isLast: pageIndex == _pages.length - 1,
                          onPressed: onNext,
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
    return Container(
      width: 126,
      height: 54,
      decoration: const BoxDecoration(
        boxShadow: [
          BoxShadow(color: Color(0x520A66FF), blurRadius: 22, spreadRadius: 1),
        ],
      ),
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
        foregroundColor: Colors.white,
        backgroundColor: _deepNavy.withValues(alpha: .28),
        minimumSize: const Size(64, 42),
        padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: Colors.white.withValues(alpha: .25)),
        ),
      ),
      child: const Text(
        'Skip',
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _MorphingFeatureGrid extends StatelessWidget {
  const _MorphingFeatureGrid({
    required this.features,
    required this.pageIndex,
  });

  final List<_Feature> features;
  final int pageIndex;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 10.0;
        final columns = pageIndex == 0 ? 4 : 3;
        final rows = pageIndex == 0 ? 1 : 2;
        final cardWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        final cardHeight =
            (constraints.maxHeight - spacing * (rows - 1)) / rows;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: List.generate(features.length, (slot) {
            final feature = features[slot];
            return SizedBox(
              width: cardWidth,
              height: cardHeight,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                switchInCurve: Curves.easeInOutCubic,
                switchOutCurve: Curves.easeInOutCubic,
                child: _FeatureCard(
                  key: ValueKey('feature-$slot'),
                  feature: feature,
                  darkLabel: pageIndex == 0,
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    super.key,
    required this.feature,
    required this.darkLabel,
  });

  final _Feature feature;
  final bool darkLabel;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: .28),
                Colors.white.withValues(alpha: .12),
              ],
            ),
            border: Border.all(color: Colors.white.withValues(alpha: .24)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x3A001D52),
                blurRadius: 22,
                offset: Offset(0, 9),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 43,
                height: 43,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: .11),
                  boxShadow: const [
                    BoxShadow(color: Color(0x402563EB), blurRadius: 12),
                  ],
                ),
                child: Icon(feature.icon, color: Colors.white, size: 27),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 380),
                  child: Text(
                    feature.title,
                    key: ValueKey(feature.title),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: darkLabel ? _deepNavy : Colors.white,
                      fontSize: 10,
                      height: 1.2,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
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
      children: List.generate(
        _pages.length,
        (i) => Expanded(
          child: GestureDetector(
            onTap: () => onSelected(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOutCubic,
              height: 4,
              margin: EdgeInsets.only(right: i == _pages.length - 1 ? 0 : 7),
              decoration: BoxDecoration(
                color: i <= index
                    ? _accentGold
                    : Colors.white.withValues(alpha: .23),
                borderRadius: BorderRadius.circular(3),
                boxShadow: i == index
                    ? const [BoxShadow(color: _accentGold, blurRadius: 10)]
                    : null,
              ),
            ),
          ),
        ),
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
        backgroundColor: _accentGold,
        foregroundColor: _deepNavy,
        minimumSize: Size(isLast ? 132 : 58, 54),
        padding: EdgeInsets.symmetric(horizontal: isLast ? 20 : 16),
        elevation: 10,
        shadowColor: _accentGold.withValues(alpha: .32),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(27)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isLast) ...[
            const Text(
              'Get started',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(width: 8),
          ],
          const Icon(Icons.arrow_forward_rounded, size: 22),
        ],
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
      final color = gold ? _accentGold : const Color(0xFF9CCBFF);
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
