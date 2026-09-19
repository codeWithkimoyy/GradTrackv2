import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../routes/app_router.dart';
import '../../widgets/bisu_brand_logo.dart';

const kLandingNavy = Color(0xFF031A48);
const kLandingOverlay = Color(0xD1071E4A);
const kLandingGold = Color(0xFFF5B041);
const kLandingBlue = Color(0xFF003DA5);
const kLandingBlueDark = Color(0xFF002D7A);
const kLandingSky = Color(0xFFE0F2FE);

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  final _scrollController = ScrollController();
  final _homeKey = GlobalKey();
  final _featuresKey = GlobalKey();
  final _aboutKey = GlobalKey();
  final _contactKey = GlobalKey();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollTo(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx == null) return;
    final box =
        (ctx.findRenderObject() as RenderBox).localToGlobal(Offset.zero);
    _scrollController.animateTo(
      _scrollController.offset + box.dy,
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kLandingNavy,
      body: SingleChildScrollView(
        controller: _scrollController,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _LandingNavBar(
              onHome: () => _scrollTo(_homeKey),
              onAbout: () => _scrollTo(_aboutKey),
              onFeatures: () => _scrollTo(_featuresKey),
              onContact: () => _scrollTo(_contactKey),
            ),
            _LandingHero(
                pageKey: _homeKey, onLearnMore: () => _scrollTo(_featuresKey)),
            _LandingFeatures(sectionKey: _featuresKey),
            _LandingStats(sectionKey: _aboutKey),
            _LandingHowItWorks(),
            const _LandingCTA(),
            _LandingFooter(sectionKey: _contactKey),
          ],
        ),
      ),
    );
  }
}

class _LandingNavBar extends StatelessWidget {
  final VoidCallback onHome;
  final VoidCallback onAbout;
  final VoidCallback onFeatures;
  final VoidCallback onContact;

  const _LandingNavBar({
    required this.onHome,
    required this.onAbout,
    required this.onFeatures,
    required this.onContact,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: kLandingNavy,
      child: SafeArea(
        bottom: false,
        child: Container(
          height: 72,
          padding: const EdgeInsets.symmetric(horizontal: 48),
          decoration: BoxDecoration(
            color: kLandingNavy.withOpacity(0.94),
            border: Border(
              bottom: BorderSide(
                color: Colors.white.withOpacity(0.1),
              ),
            ),
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Row(
                children: [
                  const _LandingLogo(),
                  const Spacer(),
                  _NavLink(label: 'Home', onTap: onHome),
                  const SizedBox(width: 8),
                  _NavLink(label: 'About', onTap: onAbout),
                  const SizedBox(width: 8),
                  _NavLink(label: 'Features', onTap: onFeatures),
                  const SizedBox(width: 8),
                  _NavLink(label: 'Contact', onTap: onContact),
                  const SizedBox(width: 24),
                  SizedBox(
                    height: 40,
                    child: OutlinedButton(
                      onPressed: () => context.go(AppRoutes.verifyAlumniId),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: Colors.white.withOpacity(0.66),
                        ),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        'Register',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    height: 40,
                    child: FilledButton(
                      onPressed: () => context.go(AppRoutes.login),
                      style: FilledButton.styleFrom(
                        backgroundColor: kLandingBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        'Login',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
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

class _LandingLogo extends StatelessWidget {
  const _LandingLogo();

  @override
  Widget build(BuildContext context) {
    return const BisuBrandLogo(inverted: true, size: 36);
  }
}

class _NavLink extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _NavLink({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        overlayColor: kLandingGold.withOpacity(0.12),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500),
      ),
    );
  }
}

class _LandingHero extends StatelessWidget {
  final GlobalKey pageKey;
  final VoidCallback onLearnMore;

  const _LandingHero({required this.pageKey, required this.onLearnMore});

  @override
  Widget build(BuildContext context) {
    final content = Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 1000;
            if (isWide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: _HeroIntro(onLearnMore: onLearnMore)),
                  const SizedBox(width: 64),
                  const Expanded(child: _HeroMockupCard()),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _HeroIntro(onLearnMore: onLearnMore),
                const SizedBox(height: 56),
                const _HeroMockupCard(),
              ],
            );
          },
        ),
      ),
    );
    return Container(
      key: pageKey,
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/landing.jpg',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Image.asset(
                'assets/images/Splash3.jpeg',
                fit: BoxFit.cover,
              ),
            ),
          ),
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(color: kLandingOverlay),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 80),
            child: content,
          ),
        ],
      ),
    );
  }
}

class _HeroIntro extends StatelessWidget {
  final VoidCallback onLearnMore;

  const _HeroIntro({required this.onLearnMore});

  @override
  Widget build(BuildContext context) {
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: kLandingGold.withOpacity(0.15),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: kLandingGold.withOpacity(0.35)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.school_rounded, size: 14, color: kLandingGold),
              const SizedBox(width: 6),
              Text(
                'BOHOL ISLAND STATE UNIVERSITY',
                style: GoogleFonts.poppins(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                  color: kLandingGold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text.rich(
          const TextSpan(
            children: [
              TextSpan(text: 'Grad'),
              TextSpan(
                text: 'Track',
                style: TextStyle(color: kLandingGold),
              ),
            ],
          ),
          style: GoogleFonts.poppins(
            fontSize: 52,
            height: 1.1,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'A Computer Science Alumni Tracking System for BISU Bilar Campus.',
          style: GoogleFonts.poppins(
            fontSize: 20,
            height: 1.4,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'GradTrack keeps alumni connected with the department: participate in '
          'tracer studies, receive announcements, discover career opportunities, '
          'and reunite with classmates - all in one place.',
          style: GoogleFonts.poppins(
            fontSize: 15,
            height: 1.6,
            color: Colors.white.withOpacity(0.82),
          ),
        ),
        const SizedBox(height: 32),
        Row(
          children: [
            FilledButton(
              onPressed: () => context.go(AppRoutes.verifyAlumniId),
              style: FilledButton.styleFrom(
                backgroundColor: kLandingBlue,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Get Started',
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 14),
            OutlinedButton(
              onPressed: onLearnMore,
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.white.withOpacity(0.66)),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Learn More',
                style: GoogleFonts.poppins(
                    fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ],
    );
    return body;
  }
}

class _HeroMockupCard extends StatelessWidget {
  const _HeroMockupCard();

  @override
  Widget build(BuildContext context) {
    final body = Stack(
      alignment: Alignment.center,
      children: [
        Positioned(
          top: 0,
          right: 0,
          child: Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              gradient: const RadialGradient(
                colors: [Color(0x66FFC21A), Color(0x00FFC21A)],
              ),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
        Positioned(
          bottom: 8,
          left: 8,
          child: Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  kLandingBlue.withOpacity(0.4),
                  const Color(0x002563EB),
                ],
              ),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 22, sigmaY: 22),
            child: Container(
              width: 460,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xF207162C),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.white.withOpacity(0.16),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.45),
                    blurRadius: 36,
                    offset: const Offset(0, 18),
                  ),
                ],
              ),
              child: const _MockDashboard(),
            ),
          ),
        ),
      ],
    );
    return body;
  }
}

class _MockDashboard extends StatelessWidget {
  const _MockDashboard();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: kLandingGold.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.school, color: kLandingGold, size: 20),
            ),
            const SizedBox(width: 10),
            Text(
              'Alumni Dashboard',
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const Spacer(),
            const _MockAvatar(),
          ],
        ),
        const SizedBox(height: 20),
        const Row(
          children: [
            _MiniStat(value: '68%', label: 'Tracer Response'),
            _MiniStat(value: '24', label: 'Active Jobs'),
            _MiniStat(value: '1', label: 'Upcoming Event'),
          ],
        ),
        const SizedBox(height: 20),
        Container(
          height: 96,
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const _MockBars(),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  color: kLandingGold,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.celebration,
                    size: 15, color: Color(0xFF031A48)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Homecoming 2026 \u2013 RSVP now',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 18,
                color: kLandingGold.withOpacity(0.8),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MockAvatar extends StatelessWidget {
  const _MockAvatar();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: kLandingGold.withOpacity(0.18),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.notifications_none,
              color: kLandingGold, size: 19),
        ),
        const SizedBox(width: 8),
        Container(
          width: 36,
          height: 36,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [kLandingGold, Color(0xFFD97706)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.person, color: Color(0xFF031A48), size: 20),
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String value;
  final String label;

  const _MiniStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: kLandingGold,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 10,
                color: Colors.white.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MockBars extends StatelessWidget {
  const _MockBars();

  static const _heights = [
    34.0,
    52.0,
    40.0,
    66.0,
    48.0,
    78.0,
    60.0,
    88.0,
    70.0
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (var i = 0; i < _heights.length; i++)
          Container(
            width: 24,
            height: _heights[i],
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  if (i % 3 == 0) ...[
                    kLandingGold.withOpacity(0.55),
                    kLandingGold.withOpacity(0.95),
                  ] else ...[
                    kLandingBlue.withOpacity(0.55),
                    kLandingBlue.withOpacity(0.95),
                  ],
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(6),
            ),
          ),
      ],
    );
  }
}

class _LandingFeatures extends StatelessWidget {
  final GlobalKey sectionKey;

  const _LandingFeatures({required this.sectionKey});

  static const _cards = [
    (
      icon: Icons.how_to_reg,
      title: 'Alumni Tracking',
      description:
          'Maintain an up-to-date directory of every graduate and follow '
          'their path after leaving the campus.',
    ),
    (
      icon: Icons.work_outline,
      title: 'Job Announcements',
      description:
          'Discover career openings shared by the department, alumni and '
          'partner companies.',
    ),
    (
      icon: Icons.event_available,
      title: 'Reunions & Events',
      description:
          'Stay informed about homecomings, reunions and campus events '
          'and RSVP in one tap.',
    ),
    (
      icon: Icons.assignment_outlined,
      title: 'Tracer Surveys',
      description:
          'Share your employment status through official tracer studies '
          'that shape the department\u2019s programs.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      key: sectionKey,
      color: Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 80),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            children: [
              const _SectionHeading(
                eyebrow: 'Features',
                title: 'Everything alumni need, in one place',
                subtitle: 'Tools built for the Computer Science department of '
                    'BISU Bilar Campus.',
              ),
              const SizedBox(height: 48),
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 1100
                      ? 4
                      : constraints.maxWidth >= 720
                          ? 2
                          : 1;
                  const rowHeight = 260.0;
                  final cardWidth =
                      (constraints.maxWidth - (columns - 1) * 24) / columns;
                  return Wrap(
                    spacing: 24,
                    runSpacing: 24,
                    children: [
                      for (final card in _cards)
                        SizedBox(
                          width: cardWidth,
                          height: rowHeight,
                          child: _FeatureCard(
                            icon: card.icon,
                            title: card.title,
                            description: card.description,
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String subtitle;

  const _SectionHeading({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          eyebrow,
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
            color: kLandingGold,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          title,
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Text(
            subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 15,
              height: 1.6,
              color: Colors.white.withOpacity(0.72),
            ),
          ),
        ),
      ],
    );
  }
}

class _FeatureCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String description;

  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  State<_FeatureCard> createState() => _FeatureCardState();
}

class _FeatureCardState extends State<_FeatureCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        transform: _hovered
            ? (Matrix4.identity()..translateByDouble(0.0, -6.0, 0.0, 1.0))
            : Matrix4.identity(),
        decoration: BoxDecoration(
          color: const Color(0xF20D1F3F),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: _hovered
                ? kLandingGold.withOpacity(0.45)
                : Colors.white.withOpacity(0.16),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: _hovered
                  ? kLandingGold.withOpacity(0.18)
                  : Colors.black.withOpacity(0.3),
              blurRadius: _hovered ? 28 : 16,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: kLandingGold.withOpacity(0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(widget.icon, color: kLandingGold, size: 26),
            ),
            const SizedBox(height: 18),
            Text(
              widget.title,
              style: GoogleFonts.poppins(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Text(
                widget.description,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  height: 1.55,
                  color: kLandingSky.withOpacity(0.9),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LandingStats extends StatelessWidget {
  final GlobalKey sectionKey;

  const _LandingStats({required this.sectionKey});

  static const _stats = [
    (value: 1284, label: 'Registered Alumni', icon: Icons.groups_rounded),
    (value: 876, label: 'Active Users', icon: Icons.rocket_launch_rounded),
    (value: 2431, label: 'Surveys Completed', icon: Icons.fact_check_outlined),
    (value: 318, label: 'Announcements Posted', icon: Icons.campaign_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      key: sectionKey,
      color: Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 80),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            children: [
              const _SectionHeading(
                eyebrow: 'Impact',
                title: 'GradTrack by the numbers',
                subtitle: 'The growing community of Computer Science graduates '
                    'connected through the BISU Bilar campus.',
              ),
              const SizedBox(height: 48),
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 1000
                      ? 4
                      : constraints.maxWidth >= 650
                          ? 2
                          : 1;
                  final cardWidth =
                      (constraints.maxWidth - (columns - 1) * 24) / columns;
                  return Wrap(
                    spacing: 24,
                    runSpacing: 24,
                    children: [
                      for (final stat in _stats)
                        SizedBox(
                          width: cardWidth,
                          child: _StatCard(
                            target: stat.value,
                            label: stat.label,
                            icon: stat.icon,
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatefulWidget {
  final int target;
  final String label;
  final IconData icon;

  const _StatCard({
    required this.target,
    required this.label,
    required this.icon,
  });

  @override
  State<_StatCard> createState() => _StatCardState();
}

class _StatCardState extends State<_StatCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final baseDecoration = BoxDecoration(
      color: const Color(0xF20D1F3F),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(
        color: _hovered ? kLandingGold : Colors.white.withOpacity(0.16),
        width: 1.2,
      ),
      boxShadow: [
        BoxShadow(
          color: _hovered
              ? kLandingGold.withOpacity(0.22)
              : Colors.black.withOpacity(0.3),
          blurRadius: _hovered ? 26 : 14,
          offset: const Offset(0, 8),
        ),
      ],
    );
    final goldDecoration = BoxDecoration(
      gradient: const LinearGradient(
        colors: [kLandingGold, Color(0xFFD97706)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(24),
      boxShadow: [
        BoxShadow(
          color: kLandingGold.withOpacity(0.3),
          blurRadius: 26,
          offset: const Offset(0, 8),
        ),
      ],
    );
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        decoration: _hovered ? goldDecoration : baseDecoration,
        padding: const EdgeInsets.all(28),
        child: Column(
          children: [
            Icon(
              widget.icon,
              size: 30,
              color: _hovered ? const Color(0xFF031A48) : kLandingGold,
            ),
            const SizedBox(height: 14),
            TweenAnimationBuilder<int>(
              tween: IntTween(begin: 0, end: widget.target),
              duration: const Duration(milliseconds: 1300),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => Text(
                _formatNumber(value),
                style: GoogleFonts.poppins(
                  fontSize: 34,
                  fontWeight: FontWeight.w700,
                  color: _hovered ? const Color(0xFF031A48) : Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              widget.label,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: _hovered
                    ? const Color(0xFF031A48)
                    : Colors.white.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatNumber(int value) {
    var result = value.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < result.length; i++) {
      buffer.write(result[i]);
      final remaining = result.length - i - 1;
      if (remaining > 0 && remaining % 3 == 0) buffer.write(',');
    }
    return buffer.toString();
  }
}

class _LandingHowItWorks extends StatelessWidget {
  static const _steps = [
    (
      number: '01',
      icon: Icons.badge_outlined,
      title: 'Admin registers Alumni ID',
      description: 'The department adds each alumnus to the official registry '
          'with a unique Alumni ID.',
    ),
    (
      number: '02',
      icon: Icons.person_add_alt_1,
      title: 'Alumni creates an account',
      description:
          'Graduates sign up online using the Alumni ID issued to them.',
    ),
    (
      number: '03',
      icon: Icons.rocket_launch_outlined,
      title: 'Alumni logs in and stays connected',
      description: 'Access announcements, surveys and events from any device.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 80),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            children: [
              const _SectionHeading(
                eyebrow: 'How it works',
                title: 'Get started in three simple steps',
                subtitle: 'From enrollment to connection - designed for the '
                    'department and its graduates.',
              ),
              const SizedBox(height: 56),
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 900;
                  if (isWide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _StepCard(
                            icon: _steps[0].icon,
                            number: _steps[0].number,
                            title: _steps[0].title,
                            description: _steps[0].description,
                          ),
                        ),
                        const SizedBox(width: 24),
                        const _StepConnector(),
                        const SizedBox(width: 24),
                        Expanded(
                          child: _StepCard(
                            icon: _steps[1].icon,
                            number: _steps[1].number,
                            title: _steps[1].title,
                            description: _steps[1].description,
                          ),
                        ),
                        const SizedBox(width: 24),
                        const _StepConnector(),
                        const SizedBox(width: 24),
                        Expanded(
                          child: _StepCard(
                            icon: _steps[2].icon,
                            number: _steps[2].number,
                            title: _steps[2].title,
                            description: _steps[2].description,
                          ),
                        ),
                      ],
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _StepCard(
                        icon: _steps[0].icon,
                        number: _steps[0].number,
                        title: _steps[0].title,
                        description: _steps[0].description,
                      ),
                      const SizedBox(height: 24),
                      _StepCard(
                        icon: _steps[1].icon,
                        number: _steps[1].number,
                        title: _steps[1].title,
                        description: _steps[1].description,
                      ),
                      const SizedBox(height: 24),
                      _StepCard(
                        icon: _steps[2].icon,
                        number: _steps[2].number,
                        title: _steps[2].title,
                        description: _steps[2].description,
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  final String number;
  final IconData icon;
  final String title;
  final String description;

  const _StepCard({
    required this.number,
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: const Color(0xF20D1F3F),
        borderRadius: BorderRadius.circular(24),
        border:
            Border.all(color: Colors.white.withOpacity(0.16), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                number,
                style: GoogleFonts.poppins(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: kLandingGold,
                ),
              ),
              const Spacer(),
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: kLandingGold.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: kLandingGold, size: 24),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: GoogleFonts.poppins(
              fontSize: 13,
              height: 1.55,
              color: kLandingSky.withOpacity(0.9),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepConnector extends StatelessWidget {
  const _StepConnector();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 28,
      child: Center(
        child: Container(
          height: 2,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                kLandingGold.withOpacity(0.25),
                kLandingGold,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LandingCTA extends StatelessWidget {
  const _LandingCTA();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 80),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 64),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [kLandingBlue, kLandingBlueDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: kLandingBlue.withOpacity(0.35),
                  blurRadius: 40,
                  offset: const Offset(0, 20),
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  'Join the GradTrack Community',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Create your account today and stay connected with the '
                  'Computer Science department and your fellow graduates.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    height: 1.6,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
                const SizedBox(height: 32),
                Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  alignment: WrapAlignment.center,
                  children: [
                    FilledButton(
                      onPressed: () => context.go(AppRoutes.login),
                      style: FilledButton.styleFrom(
                        backgroundColor: kLandingGold,
                        foregroundColor: const Color(0xFF031A48),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Login',
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    OutlinedButton(
                      onPressed: () => context.go(AppRoutes.verifyAlumniId),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: Colors.white.withOpacity(0.7),
                        ),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Register',
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LandingFooter extends StatelessWidget {
  final GlobalKey sectionKey;

  const _LandingFooter({required this.sectionKey});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: sectionKey,
      color: kLandingNavy,
      padding: const EdgeInsets.fromLTRB(48, 72, 48, 32),
      child: Column(
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 800;
                final columns = [
                  const _FooterColumn(
                    title: 'BISU Bilar Campus',
                    items: [
                      'Computer Science Department',
                      'Alumni Tracer Program',
                      'Bilar, Bohol',
                    ],
                  ),
                  const _FooterColumn(
                    title: 'Quick Links',
                    items: ['Home', 'About', 'Features', 'Contact'],
                  ),
                ];
                if (isWide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Expanded(
                        flex: 2,
                        child: _FooterColumn(
                          title: 'GradTrack',
                          items: [
                            'A Computer Science Alumni Tracking System for BISU '
                                'Bilar Campus.',
                          ],
                          highlight: true,
                        ),
                      ),
                      Expanded(child: columns[0]),
                      Expanded(child: columns[1]),
                      const Expanded(
                        child: _FooterColumn(
                          title: 'Contact',
                          items: [
                            'compsecdep@bisu.edu.ph',
                            'Bilar, Bohol, Philippines',
                          ],
                        ),
                      ),
                    ],
                  );
                }
                return Wrap(
                  spacing: 24,
                  runSpacing: 32,
                  children: [
                    SizedBox(width: 320, child: columns[0]),
                    SizedBox(width: 220, child: columns[1]),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 48),
          Divider(color: Colors.white.withOpacity(0.12)),
          const SizedBox(height: 20),
          Text(
            '\u00a9 ${DateTime.now().year} GradTrack \u00b7 BISU Bilar Campus '
            '\u00b7 Computer Science Department. All rights reserved.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.white.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }
}

class _FooterColumn extends StatelessWidget {
  final String title;
  final List<String> items;
  final bool highlight;

  const _FooterColumn({
    required this.title,
    required this.items,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: const Color(0xFFF8FAFC),
          ),
        ),
        const SizedBox(height: 14),
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              item,
              style: GoogleFonts.poppins(
                fontSize: 13,
                height: 1.5,
                color: highlight
                    ? Colors.white.withOpacity(0.75)
                    : Colors.white.withOpacity(0.55),
              ),
            ),
          ),
      ],
    );
  }
}
