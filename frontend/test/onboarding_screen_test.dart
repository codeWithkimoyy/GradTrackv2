import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gradtracker/screens/auth/onboarding_screen.dart';

void main() {
  Future<void> pumpOnboarding(
    WidgetTester tester,
    Size size,
    EdgeInsets padding, {
    double textScale = 1.0,
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: size,
            padding: padding,
            textScaler: TextScaler.linear(textScale),
          ),
          child: const OnboardingScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> goToLastPage(WidgetTester tester) async {
    for (var i = 0; i < 2; i++) {
      await tester.drag(
        find.byType(OnboardingScreen),
        const Offset(-400, 0),
      );
      await tester.pump(const Duration(milliseconds: 500));
    }
  }

  // size + realistic system insets (status bar / home indicator / nav bar)
  final devices = <String, (Size, EdgeInsets)>{
    'iPhone SE (375x667)': (
      const Size(375, 667),
      const EdgeInsets.only(top: 20),
    ),
    'iPhone X (375x812)': (
      const Size(375, 812),
      const EdgeInsets.only(top: 44, bottom: 34),
    ),
    'Android compact (360x640)': (
      const Size(360, 640),
      const EdgeInsets.only(top: 24, bottom: 24),
    ),
    'Android small (320x568)': (
      const Size(320, 568),
      const EdgeInsets.only(top: 24, bottom: 24),
    ),
    'Android gesture (412x915)': (
      const Size(412, 915),
      const EdgeInsets.only(top: 24, bottom: 24),
    ),
  };

  for (final entry in devices.entries) {
    testWidgets('OnboardingScreen has no overflow on ${entry.key}',
        (tester) async {
      await pumpOnboarding(tester, entry.value.$1, entry.value.$2);
      await goToLastPage(tester);

      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      'OnboardingScreen has no overflow on small screen with large text',
      (tester) async {
    await pumpOnboarding(
      tester,
      const Size(320, 568),
      const EdgeInsets.only(top: 24, bottom: 24),
      textScale: 1.15,
    );
    await goToLastPage(tester);

    expect(tester.takeException(), isNull);
  });
}
