import 'package:flutter_test/flutter_test.dart';
import 'package:gradtracker/models/user_model.dart';
import 'package:gradtracker/routes/app_router.dart';

void main() {
  const loggedIn = true;
  const notLoading = false;

  group('resolveRedirect - admin navigation', () {
    test('all admin tabs are allowed (return null)', () {
      const adminTabs = [
        AppRoutes.adminDashboard, // Overview
        AppRoutes.adminUsers, // Users
        AppRoutes.adminAnalytics, // Analytics
        AppRoutes.adminAuditLogs, // Audit Logs
        AppRoutes.adminMessages, // Messages
        AppRoutes.adminProfile, // Legacy Profile
        AppRoutes.adminSettings, // Settings
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

    test('admin can open a batch year details page', () {
      expect(
        resolveRedirect(
          location: AppRoutes.adminBatchFor(2023),
          authLoading: notLoading,
          loggedIn: loggedIn,
          role: UserRole.admin,
          approved: true,
        ),
        isNull,
      );
    });

    test('alumni cannot open a batch year details page', () {
      expect(
        resolveRedirect(
          location: AppRoutes.adminBatchFor(2023),
          authLoading: notLoading,
          loggedIn: loggedIn,
          role: UserRole.alumni,
          approved: true,
        ),
        AppRoutes.alumniDashboard,
      );
    });

    test('alumni cannot open the admin Settings page', () {
      expect(
        resolveRedirect(
          location: AppRoutes.adminSettings,
          authLoading: notLoading,
          loggedIn: loggedIn,
          role: UserRole.alumni,
          approved: true,
        ),
        AppRoutes.alumniDashboard,
      );
    });

    test('alumni cannot open the admin Messages page', () {
      expect(
        resolveRedirect(
          location: AppRoutes.adminMessages,
          authLoading: notLoading,
          loggedIn: loggedIn,
          role: UserRole.alumni,
          approved: true,
        ),
        AppRoutes.alumniDashboard,
      );
    });

    test('alumni can open the alumni chat screen', () {
      expect(
        resolveRedirect(
          location: AppRoutes.messages,
          authLoading: notLoading,
          loggedIn: loggedIn,
          role: UserRole.alumni,
          approved: true,
        ),
        isNull,
      );
    });

    test('admin cannot reach the alumni chat screen', () {
      expect(
        resolveRedirect(
          location: AppRoutes.messages,
          authLoading: notLoading,
          loggedIn: loggedIn,
          role: UserRole.admin,
          approved: true,
        ),
        isNull,
      );
    });
  });

  group('resolveRedirect - other roles', () {
    test('unauthenticated user is redirected to login', () {
      final result = resolveRedirect(
        location: AppRoutes.adminDashboard,
        authLoading: notLoading,
        loggedIn: false,
        role: null,
        approved: true,
      );
      expect(result, AppRoutes.login);
    });

    test('alumni cannot reach admin Audit Logs tab', () {
      final result = resolveRedirect(
        location: AppRoutes.adminAuditLogs,
        authLoading: notLoading,
        loggedIn: loggedIn,
        role: UserRole.alumni,
        approved: true,
      );
      expect(result, AppRoutes.alumniDashboard);
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

  group('resolveRedirect - alumni verification flow', () {
    test('unauthenticated user can open the Verify Alumni ID page', () {
      expect(
        resolveRedirect(
          location: AppRoutes.verifyAlumniId,
          authLoading: notLoading,
          loggedIn: false,
          role: null,
          approved: true,
        ),
        isNull,
      );
    });

    test('unauthenticated user can open a registration page for an Alumni ID', () {
      expect(
        resolveRedirect(
          location: AppRoutes.registerWith('BISU-2020-001'),
          authLoading: notLoading,
          loggedIn: false,
          role: null,
          approved: true,
        ),
        isNull,
      );
    });

    test('admin can open the Alumni Management module', () {
      expect(
        resolveRedirect(
          location: AppRoutes.adminAlumni,
          authLoading: notLoading,
          loggedIn: loggedIn,
          role: UserRole.admin,
          approved: true,
        ),
        isNull,
      );
    });

    test('alumni cannot open the Alumni Management module', () {
      expect(
        resolveRedirect(
          location: AppRoutes.adminAlumni,
          authLoading: notLoading,
          loggedIn: loggedIn,
          role: UserRole.alumni,
          approved: true,
        ),
        AppRoutes.alumniDashboard,
      );
    });

    test('signed-in user is sent home from the auth flow pages', () {
      for (final path in [
        AppRoutes.verifyAlumniId,
        AppRoutes.registerWith('BISU-2020-001'),
      ]) {
        expect(
          resolveRedirect(
            location: path,
            authLoading: notLoading,
            loggedIn: loggedIn,
            role: UserRole.alumni,
            approved: true,
          ),
          AppRoutes.alumniDashboard,
          reason: 'signed-in users must be redirected away from auth pages',
        );
      }
    });
  });

  group('resolveRedirect - disabled accounts', () {
    test('disabled alumni is pinned to the account-disabled screen', () {
      for (final path in [
        AppRoutes.alumniDashboard,
        AppRoutes.alumniSurvey,
        AppRoutes.alumniJobs,
        AppRoutes.alumniMessages,
        AppRoutes.adminUsers,
      ]) {
        expect(
          resolveRedirect(
            location: path,
            authLoading: notLoading,
            loggedIn: loggedIn,
            role: UserRole.alumni,
            disabled: true,
            approved: true,
          ),
          AppRoutes.accountDisabled,
          reason: '$path must redirect to account-disabled when disabled',
        );
      }
    });

    test('disabled alumni stays on the account-disabled screen', () {
      expect(
        resolveRedirect(
          location: AppRoutes.accountDisabled,
          authLoading: notLoading,
          loggedIn: loggedIn,
          role: UserRole.alumni,
          disabled: true,
          approved: true,
        ),
        isNull,
      );
    });

    test('disabled logged-out user is sent to login, not account-disabled', () {
      expect(
        resolveRedirect(
          location: AppRoutes.alumniDashboard,
          authLoading: notLoading,
          loggedIn: false,
          role: UserRole.alumni,
          disabled: true,
          approved: true,
        ),
        AppRoutes.login,
      );
    });
  });
}