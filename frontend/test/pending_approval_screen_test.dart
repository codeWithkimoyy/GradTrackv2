import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:gradtracker/models/user_model.dart';
import 'package:gradtracker/providers/auth_providers.dart';
import 'package:gradtracker/routes/app_router.dart';
import 'package:gradtracker/screens/auth/pending_approval_screen.dart';

void main() {
  final testUnapprovedUser = UserModel(
    uid: 'user123',
    email: 'user@example.com',
    fullName: 'Test User',
    role: UserRole.alumni,
    approved: false,
    createdAt: DateTime.now(),
  );

  final testApprovedUser = UserModel(
    uid: 'user123',
    email: 'user@example.com',
    fullName: 'Test User',
    role: UserRole.alumni,
    approved: true,
    createdAt: DateTime.now(),
  );

  GoRouter createTestRouter() {
    return GoRouter(
      initialLocation: AppRoutes.pendingApproval,
      routes: [
        GoRoute(
          path: AppRoutes.pendingApproval,
          builder: (context, state) => const PendingApprovalScreen(),
        ),
        GoRoute(
          path: AppRoutes.alumniDashboard,
          builder: (context, state) =>
              const Scaffold(body: Text('Alumni Dashboard Home')),
        ),
        GoRoute(
          path: AppRoutes.login,
          builder: (context, state) =>
              const Scaffold(body: Text('Login Screen')),
        ),
      ],
    );
  }

  testWidgets('PendingApprovalScreen renders all key elements cleanly',
      (tester) async {
    final router = createTestRouter();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProfileProvider.overrideWith(
            (ref) => Stream.value(testUnapprovedUser),
          ),
        ],
        child: MaterialApp.router(
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Account Pending Approval'), findsOneWidget);
    expect(find.byIcon(Icons.hourglass_top_rounded), findsOneWidget);
    expect(find.text('Check Approval Status'), findsOneWidget);
    expect(find.text('Sign Out'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('PendingApprovalScreen responsive test on compact screen',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final router = createTestRouter();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProfileProvider.overrideWith(
            (ref) => Stream.value(testUnapprovedUser),
          ),
        ],
        child: MaterialApp.router(
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Account Pending Approval'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Check Approval Status button can be tapped', (tester) async {
    final router = createTestRouter();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProfileProvider.overrideWith(
            (ref) => Stream.value(testUnapprovedUser),
          ),
        ],
        child: MaterialApp.router(
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final checkBtn = find.text('Check Approval Status');
    expect(checkBtn, findsOneWidget);
    await tester.tap(checkBtn);
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('Auto-forwards when live stream emits approved status',
      (tester) async {
    final streamController = StreamController<UserModel?>();
    addTearDown(streamController.close);

    final router = createTestRouter();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProfileProvider.overrideWith(
            (ref) => streamController.stream,
          ),
        ],
        child: MaterialApp.router(
          routerConfig: router,
        ),
      ),
    );

    // Initial state: unapproved
    streamController.add(testUnapprovedUser);
    await tester.pumpAndSettle();
    expect(find.text('Account Pending Approval'), findsOneWidget);

    // Live update: approved
    streamController.add(testApprovedUser);
    await tester.pumpAndSettle();

    // Verify auto-forwarded to alumni dashboard
    expect(find.text('Alumni Dashboard Home'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Already approved user routes immediately via postFrameCallback',
      (tester) async {
    final router = createTestRouter();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProfileProvider.overrideWith(
            (ref) => Stream.value(testApprovedUser),
          ),
        ],
        child: MaterialApp.router(
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Should immediately forward to Alumni Dashboard Home
    expect(find.text('Alumni Dashboard Home'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
