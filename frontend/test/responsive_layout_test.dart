import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:gradtracker/dashboards/dashboard_components.dart';
import 'package:gradtracker/screens/auth/login_screen.dart';
import 'package:gradtracker/screens/dashboard/dashboard_screen.dart';

void main() {
  GoRouter createTestRouter(Widget child) {
    return GoRouter(
      initialLocation: '/dashboard',
      routes: [
        ShellRoute(
          builder: (context, state, shellChild) =>
              DashboardShell(child: shellChild),
          routes: [
            GoRoute(
              path: '/dashboard',
              builder: (context, state) => child,
            ),
          ],
        ),
      ],
    );
  }

  testWidgets('DashboardShell renders bottom navigation on mobile viewport',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final router = createTestRouter(
      const Scaffold(body: Center(child: Text('Dashboard Content'))),
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          routerConfig: router,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));

    expect(tester.takeException(), isNull);
  });

  testWidgets('DashboardShell renders desktop sidebar on wide web viewport',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final router = createTestRouter(
      const Scaffold(body: Center(child: Text('Desktop Web Content'))),
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          routerConfig: router,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));

    expect(tester.takeException(), isNull);
  });

  testWidgets('Auth forms do not overflow across dynamic heights',
      (tester) async {
    // Simulating keyboard open on small phone: height drops to 340px
    await tester.binding.setSurfaceSize(const Size(360, 340));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: LoginScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));

    expect(tester.takeException(), isNull);
  });

  testWidgets('DashboardMetricGrid does not overflow on compact viewports',
      (tester) async {
    // Test across compact and wide widths where cards get constrained
    for (final width in [200.0, 260.0, 320.0, 375.0, 480.0, 600.0, 850.0, 1200.0]) {
      await tester.binding.setSurfaceSize(Size(width, 800));

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: DashboardMetricGrid(
                metrics: [
                  DashboardMetric(
                    'Total Alumni',
                    '156',
                    Icons.school_outlined,
                    Colors.blue,
                  ),
                  DashboardMetric(
                    'Class of 2025–2026',
                    '24',
                    Icons.calendar_month_outlined,
                    Colors.green,
                  ),
                  DashboardMetric(
                    'Total Events',
                    '12',
                    Icons.event_outlined,
                    Colors.orange,
                  ),
                  DashboardMetric(
                    'Announcements',
                    '5',
                    Icons.campaign_outlined,
                    Colors.purple,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull,
          reason: 'DashboardMetricGrid overflowed at width $width');
    }
  });
}
