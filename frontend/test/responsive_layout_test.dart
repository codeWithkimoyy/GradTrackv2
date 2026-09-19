import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:gradtracker/dashboards/admin/admin_components.dart';
import 'package:gradtracker/models/user_model.dart';
import 'package:gradtracker/providers/auth_providers.dart';
import 'package:gradtracker/screens/auth/login_screen.dart';
import 'package:gradtracker/screens/dashboard/dashboard_screen.dart';

UserModel _buildUser(UserRole role) => UserModel(
      uid: 'test-uid',
      email: 'test@bisutest.edu.ph',
      fullName: 'Test User',
      role: role,
      createdAt: DateTime(2026, 1, 1),
    );

Widget _buildShell(Widget child, {required UserRole role}) {
  final router = GoRouter(
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

  return ProviderScope(
    overrides: [
      currentUserProfileProvider.overrideWith(
        (ref) => Stream.value(_buildUser(role)),
      ),
    ],
    child: MaterialApp.router(
      routerConfig: router,
    ),
  );
}

bool _hasBottomNavigation(WidgetTester tester) {
  final scaffolds = tester.widgetList<Scaffold>(find.byType(Scaffold));
  return scaffolds.any((s) => s.bottomNavigationBar != null);
}

void main() {
  testWidgets('alumni gets the app-style bottom nav on a mobile viewport',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _buildShell(
        const Scaffold(body: Center(child: Text('Alumni Mobile Content'))),
        role: UserRole.alumni,
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));

    expect(tester.takeException(), isNull);
    expect(_hasBottomNavigation(tester), isTrue);
    expect(find.text('Audit Logs'), findsNothing);
  });

  testWidgets('alumni keeps the app-style bottom nav on a wide web viewport',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _buildShell(
        const Scaffold(body: Center(child: Text('Alumni Web Content'))),
        role: UserRole.alumni,
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));

    expect(tester.takeException(), isNull);
    expect(_hasBottomNavigation(tester), isTrue);
    expect(find.text('Audit Logs'), findsNothing);
  });

  testWidgets('admin gets the web-style sidebar on a wide viewport',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _buildShell(
        const Scaffold(body: Center(child: Text('Admin Dashboard'))),
        role: UserRole.admin,
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));

    expect(tester.takeException(), isNull);
    expect(_hasBottomNavigation(tester), isFalse);
    expect(find.text('Audit Logs'), findsOneWidget);
    expect(find.text('Reports & Analytics'), findsOneWidget);
    expect(find.text('Announcements & Events'), findsOneWidget);
  });

  testWidgets('admin keeps the web-style shell even on a narrow viewport',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _buildShell(
        const Scaffold(body: Center(child: Text('Admin Mobile Web'))),
        role: UserRole.admin,
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));

    expect(tester.takeException(), isNull);
    // Compact shell: still the sidebar (rail with tooltips), never bottom nav.
    expect(_hasBottomNavigation(tester), isFalse);
    expect(find.byType(Tooltip), findsWidgets);
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
              child: AdminMetricGrid(
                metrics: [
                  AdminMetric(
                    'Total Alumni',
                    '156',
                    Icons.school_outlined,
                    Colors.blue,
                  ),
                  AdminMetric(
                    'Class of 2025–2026',
                    '24',
                    Icons.calendar_month_outlined,
                    Colors.green,
                  ),
                  AdminMetric(
                    'Total Events',
                    '12',
                    Icons.event_outlined,
                    Colors.orange,
                  ),
                  AdminMetric(
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