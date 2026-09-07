import 'package:flutter_test/flutter_test.dart';
import 'package:gradtracker/models/user_model.dart';
import 'package:gradtracker/routes/app_router.dart';

void main() {
  const loggedIn = true;
  const notLoading = false;

  group('resolveRedirect - admin navigation', () {
    test('all five admin tabs are allowed (return null)', () {
      const adminTabs = [
        AppRoutes.adminDashboard, // Overview
        AppRoutes.adminUsers, // Users
        AppRoutes.adminAnalytics, // Analytics
        AppRoutes.adminAuditLogs, // Audit Logs
        AppRoutes.adminProfile, // Profile
      ];

      for (final path in adminTabs) {
        final result = resolveRedirect(
          location: path,
          authLoading: notLoading,
          loggedIn: loggedIn,
          role: UserRole.admin,
          approved: true,
        );
        expect(result, isNull,
            reason: 'admin should be allowed to reach $path');
      }
    });

    test('Users and Audit Logs are NOT bounced back to the dashboard', () {
      for (final path in [AppRoutes.adminUsers, AppRoutes.adminAuditLogs]) {
        expect(
          resolveRedirect(
            location: path,
            authLoading: notLoading,
            loggedIn: loggedIn,
            role: UserRole.admin,
            approved: true,
          ),
          isNull,
          reason: '$path must not redirect to the dashboard',
        );
      }
    });
  });

  group('resolveRedirect - other roles', () {
    test('guest is redirected home when not signed in', () {
      final result = resolveRedirect(
        location: AppRoutes.adminDashboard,
        authLoading: notLoading,
        loggedIn: false,
        role: null,
        approved: true,
      );
      expect(result, AppRoutes.login);
    });

    test('coordinator cannot reach admin Audit Logs tab', () {
      final result = resolveRedirect(
        location: AppRoutes.adminAuditLogs,
        authLoading: notLoading,
        loggedIn: loggedIn,
        role: UserRole.coordinator,
        approved: true,
      );
      expect(result, AppRoutes.coordinatorDashboard);
    });

    test('approved alumni on pending-approval is automatically redirected to alumni dashboard', () {
      final result = resolveRedirect(
        location: AppRoutes.pendingApproval,
        authLoading: notLoading,
        loggedIn: loggedIn,
        role: UserRole.alumni,
        approved: true,
      );
      expect(result, AppRoutes.alumniDashboard);
    });

    test('unapproved alumni attempting to access alumni dashboard is redirected to pending-approval', () {
      final result = resolveRedirect(
        location: AppRoutes.alumniDashboard,
        authLoading: notLoading,
        loggedIn: loggedIn,
        role: UserRole.alumni,
        approved: false,
      );
      expect(result, AppRoutes.pendingApproval);
    });
  });
}