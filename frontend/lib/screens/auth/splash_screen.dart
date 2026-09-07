import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/auth_providers.dart';
import '../../routes/app_router.dart';
import '../../widgets/splash_background.dart';
import '../../widgets/splash_brand_content.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _controller;
  late final AnimationController _glowController;
  late final Animation<double> _scale;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;
  late final Animation<double> _glow;

  static const _onboardingSeenKey = 'onboarding_seen';

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..forward();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _scale = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, .72, curve: Curves.easeOutBack),
    );
    _fade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(.12, 1, curve: Curves.easeOut),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, .18),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(.3, 1, curve: Curves.easeOutCubic),
      ),
    );
    _glow = CurvedAnimation(parent: _glowController, curve: Curves.easeInOut);

    _resolveNextRoute();
  }

  Future<void> _resolveNextRoute() async {
    // Give the animation a moment to play and let the first auth-state
    // event arrive before deciding where to route.
    final prefs = SharedPreferences.getInstance();
    final results = await Future.wait([
      Future.delayed(const Duration(milliseconds: 2200)),
      prefs,
    ]);
    if (!mounted) return;

    final sharedPrefs = results[1] as SharedPreferences;
    final onboardingSeen = sharedPrefs.getBool(_onboardingSeenKey) ?? false;

    final authUser = await ref.read(authStateProvider.future).timeout(
      const Duration(seconds: 3),
      onTimeout: () => null,
    );

    if (!mounted) return;
    if (authUser != null) {
      context.go(AppRoutes.dashboard);
    } else if (!onboardingSeen) {
      context.go(AppRoutes.onboarding);
    } else {
      context.go(AppRoutes.login);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF081B33),
      body: SplashBackground(
        child: SplashBrandContent(
          logoScale: _scale,
          logoOpacity: _fade,
          textSlide: _slide,
          glow: _glow,
        ),
      ),
    );
  }
}
