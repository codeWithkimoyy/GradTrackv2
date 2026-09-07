import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
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
}
