import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../dashboards/admin/admin_dashboard.dart';
import '../dashboards/alumni/alumni_dashboard.dart';
import '../models/user_model.dart';
import '../providers/auth_providers.dart';
import '../screens/alumni/alumni_chat_screen.dart';
import '../screens/alumni/notifications_screen.dart';
import '../screens/alumni/survey_screen.dart';
import '../screens/analytics/analytics_screen.dart';
import '../screens/auth/forgot_password_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/onboarding_screen.dart';
import '../screens/auth/pending_approval_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/auth/splash_screen.dart';
import '../screens/auth/account_disabled_screen.dart';
import '../screens/auth/verify_alumni_id_screen.dart';
import '../screens/dashboard/dashboard_screen.dart';
import '../screens/documents/certificate_gallery_screen.dart';
import '../screens/documents/resume_upload_screen.dart';
import '../screens/employment/employment_history_screen.dart';
import '../screens/landing/landing_screen.dart';
import '../screens/profile/edit_profile_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/shared/collection_list_screen.dart';
import '../screens/staff/admin_settings_screen.dart';
import '../screens/staff/admin_messages_screen.dart';
import '../screens/staff/alumni_management_screen.dart';
import '../screens/staff/audit_log_screen.dart';
import '../screens/staff/batch_alumni_screen.dart';
import '../screens/staff/employment_history_screen.dart';
import '../screens/staff/reports_screen.dart';
import '../screens/staff/user_employment_screen.dart';
import '../screens/staff/user_management_screen.dart';

class AppRoutes {
  AppRoutes._();
  static const splash = '/';
  static const onboarding = '/onboarding';
  static const login = '/login';
  static const register = '/register';
  static const registerPattern = '/register/:alumniId';
  static const verifyAlumniId = '/verify-alumni-id';
  static const forgotPassword = '/forgot-password';
  static String registerWith(String alumniId) => '$register/$alumniId';
  static const dashboard = '/dashboard';
  static const dashboardAlumni = '/dashboard/alumni';
  static const dashboardJobs = '/dashboard/jobs';
  static const dashboardDocuments = '/dashboard/documents';
  static const dashboardProfile = '/dashboard/profile';
  static const pendingApproval = '/pending-approval';
  static const accountDisabled = '/account-disabled';

  static const alumniDashboard = '/alumni/dashboard';
  static const alumniSurvey = '/alumni/survey';
  static const alumniJobs = '/alumni/jobs';
  static const alumniNotifications = '/alumni/notifications';
  static const alumniProfile = '/alumni/profile';
  static const alumniDocuments = '/alumni/documents';
  static const alumniMessages = '/alumni/messages';
  static const adminDashboard = '/admin/dashboard';
  static const adminUsers = '/admin/users';
  static const adminBatch = '/admin/users/batch';
  static const adminBatchPattern = '/admin/users/batch/:year';
  static String adminBatchFor(int year) => '$adminBatch/$year';
  static const adminAlumni = '/admin/alumni';
  static const adminAnalytics = '/admin/analytics';
  static const adminAuditLogs = '/admin/audit-logs';
  static const adminEmploymentHistory = '/admin/employment-history';
  static const adminProfile = '/admin/profile';
  static const adminSettings = '/admin/settings';
  static const adminMessages = '/admin/messages';
  static const messages = '/messages';

  static const staffUsers = '/staff/users';
  static const staffUserEmployment = '/staff/users/employment';
  static String collectionData(String key) => '/staff/data/$key';
  static const staffData = '/staff/data';

  static const profile = '/profile';
  static const editProfile = '/profile/edit';
  static const employment = '/employment';
  static const resume = '/documents/resume';
  static const certificates = '/documents/certificates';
}

String dashboardForRole(UserRole role) => switch (role) {
      UserRole.alumni => AppRoutes.alumniDashboard,
      UserRole.admin => AppRoutes.adminDashboard,
    };

/// Laptops/desktops browsing the web app (>= tablet width) get the landing
/// page at the root. Phones - whether the mobile app or a web browser on a
/// small screen - keep the existing splash + 3-screen onboarding flow.
bool _isDesktopWeb(BuildContext context) {
  if (!kIsWeb) return false;
  return MediaQuery.sizeOf(context).width >= 768;
}

class _RouterListenable extends ChangeNotifier {
  _RouterListenable(Ref ref) {
    ref.listen(authStateProvider, (_, __) => notifyListeners());
    ref.listen(currentUserProfileProvider, (_, __) => notifyListeners());
  }
}

final routerListenableProvider = Provider<_RouterListenable>((ref) {
  return _RouterListenable(ref);
});

final routerProvider = Provider<GoRouter>((ref) {
  final listenable = ref.watch(routerListenableProvider);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: listenable,
    redirect: (context, state) {
      final location = state.matchedLocation;
      final authState = ref.read(authStateProvider);
      final profile = ref.read(currentUserProfileProvider).valueOrNull;
      return resolveRedirect(
        location: location,
        authLoading: authState.isLoading,
        loggedIn: authState.value != null,
        role: profile?.role,
        disabled: profile?.disabled ?? false,
        approved: profile?.approved ?? true,
      );
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, _) => _isDesktopWeb(context)
            ? const LandingScreen()
            : const SplashScreen(),
      ),
      GoRoute(
          path: AppRoutes.onboarding,
          builder: (_, __) => const OnboardingScreen()),
      GoRoute(path: AppRoutes.login, builder: (_, __) => const LoginScreen()),
      GoRoute(
          path: AppRoutes.verifyAlumniId,
          builder: (_, __) => const VerifyAlumniIdScreen()),
      GoRoute(
        path: AppRoutes.registerPattern,
        builder: (context, state) => RegisterScreen(
          alumniId: state.pathParameters['alumniId'] ?? '',
        ),
      ),
      GoRoute(
          path: AppRoutes.forgotPassword,
          builder: (_, __) => const ForgotPasswordScreen()),
      GoRoute(
        path: AppRoutes.pendingApproval,
        builder: (_, __) => const PendingApprovalScreen(),
      ),
      GoRoute(
        path: AppRoutes.accountDisabled,
        builder: (_, __) => const AccountDisabledScreen(),
      ),
      ShellRoute(
        builder: (_, __, child) => DashboardShell(child: child),
        routes: [
          GoRoute(
              path: AppRoutes.staffUsers,
              builder: (context, state) {
                final role = state.uri.queryParameters['role'];
                final pendingOnly = state.uri.queryParameters['pending'] == '1';
                return UserManagementScreen(
                  roleFilter: role,
                  canVerify: role == null || role == 'alumni',
                  approvedOnly: state.uri.queryParameters['approved'] == '1',
                  initialPendingOnly: pendingOnly,
                );
              }),
          GoRoute(
              path: AppRoutes.staffUserEmployment,
              builder: (context, state) {
                final userId = state.uri.queryParameters['userId'] ?? '';
                return UserEmploymentScreen(userId: userId);
              }),
          GoRoute(
            path: '${AppRoutes.staffData}/:key',
            builder: (context, state) {
              final key = state.pathParameters['key'] ?? '';
              if (key == 'audit_logs') {
                return const AuditLogScreen();
              }
              if (key == 'reports') {
                return const ReportsScreen();
              }
              final content = lookupCollection(key);
              if (content == null) {
                return const _NotFoundScreen();
              }
              return CollectionListScreen(content: content);
            },
          ),
          GoRoute(
              path: AppRoutes.alumniDashboard,
              builder: (_, __) => const _AlumniDashboardRoute()),
          GoRoute(
              path: AppRoutes.alumniSurvey,
              builder: (_, __) => const SurveyScreen()),
          GoRoute(
              path: AppRoutes.alumniJobs,
              builder: (_, __) =>
                  CollectionListScreen(content: lookupCollection('jobs')!)),
          GoRoute(
              path: AppRoutes.alumniNotifications,
              builder: (_, __) => const NotificationsScreen()),
          GoRoute(
              path: AppRoutes.alumniProfile,
              builder: (_, __) => const ProfileScreen()),
          GoRoute(
              path: AppRoutes.alumniDocuments,
              builder: (_, __) => const CertificateGalleryScreen()),
          GoRoute(
              path: AppRoutes.alumniMessages,
              builder: (_, __) => const AlumniChatScreen()),
          GoRoute(
              path: AppRoutes.adminDashboard,
              builder: (_, __) => const AdminDashboard()),
          GoRoute(
              path: AppRoutes.adminAnalytics,
              builder: (_, __) => const AnalyticsScreen(adminMode: true)),
          GoRoute(
              path: AppRoutes.adminEmploymentHistory,
              builder: (_, __) => const EmploymentHistoryAdminScreen()),
          GoRoute(
              path: AppRoutes.adminUsers,
              builder: (_, __) => const UserManagementScreen()),
          GoRoute(
            path: AppRoutes.adminBatchPattern,
            builder: (context, state) {
              final year = int.tryParse(state.pathParameters['year'] ?? '') ??
                  DateTime.now().year;
              return BatchAlumniScreen(batchYear: year);
            },
          ),
          GoRoute(
              path: AppRoutes.adminAlumni,
              builder: (_, __) => const AlumniManagementScreen()),
          GoRoute(
              path: AppRoutes.adminAuditLogs,
              builder: (_, __) => const AuditLogScreen()),
          GoRoute(
              path: AppRoutes.adminProfile,
              builder: (_, __) => const ProfileScreen()),
          GoRoute(
              path: AppRoutes.adminSettings,
              builder: (_, __) => const AdminSettingsScreen()),
          GoRoute(
              path: AppRoutes.adminMessages,
              builder: (context, state) {
                final params = state.uri.queryParameters;
                return AdminMessagesScreen(
                  initialAlumniId: params['alumniId'],
                  initialAlumniName: params['name'],
                  initialAlumniEmail: params['email'],
                  initialAlumniCourse: params['course'],
                );
              }),
        ],
      ),
      GoRoute(
          path: AppRoutes.profile, builder: (_, __) => const ProfileScreen()),
      GoRoute(
          path: AppRoutes.editProfile,
          builder: (_, __) => const EditProfileScreen()),
      GoRoute(
          path: AppRoutes.employment,
          builder: (_, __) => const EmploymentHistoryPage()),
      GoRoute(
          path: AppRoutes.resume,
          builder: (_, __) => const ResumeUploadScreen()),
      GoRoute(
          path: AppRoutes.certificates,
          builder: (_, __) => const CertificateGalleryScreen()),
      GoRoute(
          path: AppRoutes.messages,
          builder: (_, __) => const AlumniChatScreen()),
    ],
  );
});

/// Pure redirect decision for the GoRouter. Kept as a top-level function so
/// the routing rules can be unit-tested without Firebase.
String? resolveRedirect({
  required String location,
  required bool authLoading,
  required bool loggedIn,
  required UserRole? role,
  bool disabled = false,
  required bool approved,
}) {
  const authRoutes = {
    AppRoutes.splash,
    AppRoutes.onboarding,
    AppRoutes.login,
    AppRoutes.verifyAlumniId,
    AppRoutes.register,
    AppRoutes.forgotPassword,
  };

  final isRegisterLocation = location.startsWith('${AppRoutes.register}/');

  if (authLoading) {
    return location == AppRoutes.splash ? null : AppRoutes.splash;
  }
  if (!loggedIn) {
    return (authRoutes.contains(location) || isRegisterLocation)
        ? null
        : AppRoutes.login;
  }
  // A disabled account has all data access revoked in the security rules, so
  // pin the user to an explanatory screen instead of letting the rest of the
  // routing logic scatter them into screens that just throw permission errors.
  if (disabled) {
    return location == AppRoutes.accountDisabled
        ? null
        : AppRoutes.accountDisabled;
  }
  if (role == null) {
    return location == AppRoutes.splash ? null : AppRoutes.splash;
  }

  // Approval is only enforced for alumni. Admins are credentialed staff
  // accounts managed by the university, so they never wait.
  if (!approved && role == UserRole.alumni) {
    return location == AppRoutes.pendingApproval
        ? null
        : AppRoutes.pendingApproval;
  }

  final home = dashboardForRole(role);
  if ((approved || role == UserRole.admin) &&
      location == AppRoutes.pendingApproval) {
    return home;
  }

  // Strip any query string so role checks match the path-only route.
  final path = location.split('?').first;
  final legacy = <String, String>{
    AppRoutes.dashboard: home,
    AppRoutes.dashboardAlumni:
        role == UserRole.alumni ? AppRoutes.alumniDashboard : home,
    AppRoutes.dashboardJobs:
        role == UserRole.alumni ? AppRoutes.alumniJobs : home,
    AppRoutes.dashboardDocuments:
        role == UserRole.alumni ? AppRoutes.alumniDocuments : home,
    AppRoutes.dashboardProfile:
        role == UserRole.alumni ? AppRoutes.alumniProfile : home,
  };
  if (legacy.containsKey(path)) return legacy[path];
  if (authRoutes.contains(path) || isRegisterLocation) return home;

  final collectionKey = path.startsWith(AppRoutes.staffData)
      ? path.substring(AppRoutes.staffData.length + 1).split('?').first
      : null;
  final collectionExists =
      collectionKey != null && lookupCollection(collectionKey) != null;

  final allowed = <UserRole, Set<String>>{
    UserRole.alumni: {
      AppRoutes.alumniDashboard,
      AppRoutes.alumniSurvey,
      AppRoutes.alumniJobs,
      AppRoutes.alumniNotifications,
      AppRoutes.alumniProfile,
      AppRoutes.alumniDocuments,
      AppRoutes.alumniMessages,
      AppRoutes.profile,
      AppRoutes.editProfile,
      AppRoutes.employment,
      AppRoutes.resume,
      AppRoutes.certificates,
      AppRoutes.messages,
      if (collectionExists) path,
    },
    UserRole.admin: {
      AppRoutes.adminDashboard,
      AppRoutes.adminAnalytics,
      AppRoutes.adminUsers,
      AppRoutes.adminAlumni,
      AppRoutes.adminAuditLogs,
      AppRoutes.adminEmploymentHistory,
      AppRoutes.adminProfile,
      AppRoutes.adminSettings,
      AppRoutes.adminMessages,
      AppRoutes.messages,
      AppRoutes.editProfile,
      AppRoutes.staffUsers,
      AppRoutes.alumniNotifications,
      AppRoutes.pendingApproval,
      if (collectionExists) path,
    },
  }[role]!;
  final canAccess = allowed.any((p) => path == p || path.startsWith('$p/'));
  return canAccess ? null : home;
}

class _NotFoundScreen extends StatelessWidget {
  const _NotFoundScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('This content is not available.')),
    );
  }
}

class _AlumniDashboardRoute extends ConsumerWidget {
  const _AlumniDashboardRoute();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentUserProfileProvider);
    return profile.when(
      data: (user) => user == null
          ? const Center(child: CircularProgressIndicator())
          : AlumniDashboard(user: user),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Center(
        child: Text('Your profile is temporarily unavailable.'),
      ),
    );
  }
}
