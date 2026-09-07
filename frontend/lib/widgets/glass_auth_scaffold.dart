import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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
  late final AnimationController _ambientController;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    )..forward();
    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat();
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
              color: Color(0xD9031A48),
            ),
          ),
          AnimatedBuilder(
            animation: _ambientController,
            builder: (context, _) => CustomPaint(
              painter: _AuthAtmospherePainter(
                progress: _ambientController.value,
              ),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 370;
                final horizontal = compact ? 18.0 : 28.0;
                return SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(horizontal, 210, horizontal, 28),
                  physics: const BouncingScrollPhysics(),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 460),
                      child: FadeTransition(
                        opacity: _fade,
                        child: SlideTransition(
                          position: _slide,
                          child: Column(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(30),
                                child: BackdropFilter(
                                  filter: ImageFilter.blur(
                                    sigmaX: 22,
                                    sigmaY: 22,
                                  ),
                                  child: Container(
                                    width: double.infinity,
                                    padding: EdgeInsets.fromLTRB(
                                      compact ? 20 : 26,
                                      22,
                                      compact ? 20 : 26,
                                      28,
                                    ),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(30),
                                      color: const Color(0xDD0A2B5E),
                                      border: Border.all(
                                        color:
                                            Colors.white.withValues(alpha: .45),
                                      ),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Color(0x6600C8FF),
                                          blurRadius: 24,
                                          spreadRadius: -6,
                                        ),
                                        BoxShadow(
                                          color: Color(0x66001034),
                                          blurRadius: 35,
                                          offset: Offset(0, 20),
                                        ),
                                      ],
                                    ),
                                    child: Theme(
                                      data: _glassTheme(context),
                                      child: Column(
                                        children: [
                                          const _AuthLogo(),
                                          const SizedBox(height: 18),
                                          _AuthTitle(title: widget.title),
                                          if (widget.subtitle != null) ...[
                                            const SizedBox(height: 7),
                                            Text(
                                              widget.subtitle!,
                                              textAlign: TextAlign.center,
                                              style: GoogleFonts.poppins(
                                                color: Colors.white
                                                    .withValues(alpha: .86),
                                                fontSize: compact ? 12 : 13.5,
                                                height: 1.4,
                                              ),
                                            ),
                                          ],
                                          const SizedBox(height: 24),
                                          widget.child,
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 42),
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
      borderRadius: BorderRadius.circular(13),
      borderSide: BorderSide(color: Colors.white.withValues(alpha: .28)),
    );
    return base.copyWith(
      textTheme: GoogleFonts.poppinsTextTheme(base.textTheme).apply(
        bodyColor: Colors.white,
        displayColor: Colors.white,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withValues(alpha: .10),
        labelStyle: TextStyle(color: Colors.white.withValues(alpha: .78)),
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: .68)),
        prefixIconColor: Colors.white.withValues(alpha: .78),
        suffixIconColor: const Color(0xFF9FD5FF),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: const BorderSide(color: Color(0xFF5DDCFF), width: 1.4),
        ),
        errorBorder: border.copyWith(
          borderSide: const BorderSide(color: Color(0xFFFF8A8A)),
        ),
        focusedErrorBorder: border.copyWith(
          borderSide: const BorderSide(color: Color(0xFFFF8A8A), width: 1.4),
        ),
        errorStyle: const TextStyle(color: Color(0xFFFFC4C4)),
      ),
      dropdownMenuTheme: const DropdownMenuThemeData(),
    );
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _ambientController.dispose();
    super.dispose();
  }
}

class _AuthLogo extends StatelessWidget {
  const _AuthLogo();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      height: 58,
      child: Image.asset('assets/images/logo_full.png', fit: BoxFit.contain),
    );
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
              style: TextStyle(color: Color(0xFFFFC21A)),
            ),
          ],
        ),
        textAlign: TextAlign.center,
        style: GoogleFonts.poppins(
          color: Colors.white,
          fontSize: 30,
          height: 1.08,
          fontWeight: FontWeight.w700,
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
            style: const TextStyle(color: Color(0xFFFFC21A)),
          ),
        ],
      ),
      textAlign: TextAlign.center,
      style: GoogleFonts.poppins(
        color: Colors.white,
        fontSize: 27,
        height: 1.15,
        fontWeight: FontWeight.w700,
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
            Text(
              'Secure. Trusted. Connected.',
              style: GoogleFonts.poppins(color: Colors.white, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 7),
        Text(
          'Powered by BISU Bilar Campus',
          style: GoogleFonts.poppins(
            color: Colors.white.withValues(alpha: .76),
            fontSize: 11.5,
          ),
        ),
      ],
    );
  }
}

class _AuthAtmospherePainter extends CustomPainter {
  _AuthAtmospherePainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < 18; i++) {
      final x = (i * 71.0 + progress * 34) % size.width;
      final y = (i * 109.0 - progress * 38 + size.height) % size.height;
      final gold = i % 7 == 0;
      canvas.drawCircle(
        Offset(x, y),
        gold ? 2.2 : 1.4,
        Paint()
          ..color = (gold ? const Color(0xFFFFC21A) : Colors.lightBlueAccent)
              .withValues(alpha: .48)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
    }
    for (var i = 0; i < 5; i++) {
      final path = Path()
        ..moveTo(-30, size.height * (.63 + i * .055))
        ..cubicTo(
          size.width * .25,
          size.height * (.57 + i * .05),
          size.width * .65,
          size.height * (.76 + i * .035),
          size.width + 30,
          size.height * (.68 + i * .045),
        );
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = i == 0 ? 1.1 : .65
          ..color = Colors.white.withValues(alpha: .11 - i * .014),
      );
    }
    final pulse = .94 + math.sin(progress * math.pi * 2) * .04;
    canvas.drawCircle(
      Offset(size.width * .9, size.height * .33),
      68 * pulse,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = Colors.white.withValues(alpha: .07),
    );
  }

  @override
  bool shouldRepaint(covariant _AuthAtmospherePainter oldDelegate) =>
      oldDelegate.progress != progress;
}
