import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../dashboards/admin_dashboard.dart';
import '../dashboards/alumni_dashboard.dart';
import '../dashboards/coordinator_dashboard.dart';
import '../dashboards/guest_dashboard.dart';
import '../models/user_model.dart';
import '../providers/auth_providers.dart';
import '../screens/about/about_screen.dart';
import '../screens/alumni/notifications_screen.dart';
import '../screens/alumni/survey_screen.dart';
import '../screens/analytics/analytics_screen.dart';
import '../screens/auth/forgot_password_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/onboarding_screen.dart';
import '../screens/auth/pending_approval_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/auth/splash_screen.dart';
import '../screens/dashboard/dashboard_screen.dart';
import '../screens/documents/certificate_gallery_screen.dart';
import '../screens/documents/resume_upload_screen.dart';
import '../screens/employment/add_employment_screen.dart';
import '../screens/employment/employment_history_screen.dart';
import '../screens/profile/edit_profile_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/shared/collection_list_screen.dart';
import '../screens/staff/audit_log_screen.dart';
import '../screens/staff/user_management_screen.dart';

class AppRoutes {
  AppRoutes._();
  static const splash = '/';
  static const onboarding = '/onboarding';
  static const login = '/login';
  static const register = '/register';
  static const forgotPassword = '/forgot-password';
  static const dashboard = '/dashboard';
  static const dashboardAlumni = '/dashboard/alumni';
  static const dashboardJobs = '/dashboard/jobs';
  static const dashboardDocuments = '/dashboard/documents';
  static const dashboardProfile = '/dashboard/profile';
  static const about = '/about';
  static const pendingApproval = '/pending-approval';

  static const guestDashboard = '/guest/dashboard';
  static const alumniDashboard = '/alumni/dashboard';
  static const alumniSurvey = '/alumni/survey';
  static const alumniJobs = '/alumni/jobs';
  static const alumniNotifications = '/alumni/notifications';
  static const alumniProfile = '/alumni/profile';
  static const alumniDocuments = '/alumni/documents';
  static const coordinatorDashboard = '/coordinator/dashboard';
  static const coordinatorAlumni = '/coordinator/alumni';
  static const coordinatorSurveys = '/coordinator/surveys';
  static const coordinatorReports = '/coordinator/reports';
  static const coordinatorEvents = '/coordinator/events';
  static const coordinatorAnalytics = '/coordinator/analytics';
  static const adminDashboard = '/admin/dashboard';
  static const adminUsers = '/admin/users';
  static const adminAnalytics = '/admin/analytics';
  static const adminAuditLogs = '/admin/audit-logs';
  static const adminProfile = '/admin/profile';

  static const staffUsers = '/staff/users';
  static String collectionData(String key) => '/staff/data/$key';
  static const staffData = '/staff/data';

  static const profile = '/profile';
  static const editProfile = '/profile/edit';
  static const employment = '/employment';
  static const addEmployment = '/employment/add';
  static const resume = '/documents/resume';
  static const certificates = '/documents/certificates';
}

String dashboardForRole(UserRole role) => switch (role) {
      UserRole.guest => AppRoutes.guestDashboard,
      UserRole.alumni => AppRoutes.alumniDashboard,
      UserRole.coordinator => AppRoutes.coordinatorDashboard,
      UserRole.admin => AppRoutes.adminDashboard,
    };

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  return GoRouter(
    initialLocation: AppRoutes.splash,
    redirect: (context, state) {
      final location = state.matchedLocation;
      final profile = ref.read(currentUserProfileProvider).valueOrNull;
      return resolveRedirect(
        location: location,
        authLoading: authState.isLoading,
        loggedIn: authState.value != null,
        role: profile?.role,
        approved: profile?.approved ?? true,
      );
    },
    routes: [
      GoRoute(path: AppRoutes.splash, builder: (_, __) => const SplashScreen()),
      GoRoute(path: AppRoutes.onboarding, builder: (_, __) => const OnboardingScreen()),
      GoRoute(path: AppRoutes.login, builder: (_, __) => const LoginScreen()),
      GoRoute(path: AppRoutes.register, builder: (_, __) => const RegisterScreen()),
      GoRoute(path: AppRoutes.forgotPassword, builder: (_, __) => const ForgotPasswordScreen()),
      GoRoute(path: AppRoutes.about, builder: (_, __) => const AboutScreen()),
      GoRoute(
        path: AppRoutes.pendingApproval,
        builder: (_, __) => const PendingApprovalScreen(),
      ),
      ShellRoute(
        builder: (_, __, child) => DashboardShell(child: child),
        routes: [
          GoRoute(path: AppRoutes.staffUsers, builder: (context, state) {
            final role = state.uri.queryParameters['role'];
            return UserManagementScreen(
              roleFilter: role,
              canVerify: role == null || role == 'alumni',
            );
          }),
          GoRoute(
            path: '${AppRoutes.staffData}/:key',
            builder: (context, state) {
              final key = state.pathParameters['key'] ?? '';
              if (key == 'audit_logs') {
                return const AuditLogScreen();
              }
              final content = lookupCollection(key);
              if (content == null) {
                return const _NotFoundScreen();
              }
              return CollectionListScreen(content: content);
            },
          ),
          GoRoute(path: AppRoutes.guestDashboard, builder: (_, __) => const GuestDashboard()),
          GoRoute(path: AppRoutes.alumniDashboard, builder: (_, __) => const _AlumniDashboardRoute()),
          GoRoute(path: AppRoutes.alumniSurvey, builder: (_, __) => const SurveyScreen()),
          GoRoute(path: AppRoutes.alumniJobs, builder: (_, __) => CollectionListScreen(content: lookupCollection('jobs')!)),
          GoRoute(path: AppRoutes.alumniNotifications, builder: (_, __) => const NotificationsScreen()),
          GoRoute(path: AppRoutes.alumniProfile, builder: (_, __) => const ProfileScreen()),
          GoRoute(path: AppRoutes.alumniDocuments, builder: (_, __) => const CertificateGalleryScreen()),
          GoRoute(path: AppRoutes.coordinatorDashboard, builder: (_, __) => const CoordinatorDashboard()),
          GoRoute(path: AppRoutes.coordinatorAlumni, builder: (_, __) => const UserManagementScreen(roleFilter: 'alumni')),
          GoRoute(path: AppRoutes.coordinatorSurveys, builder: (_, __) => CollectionListScreen(content: lookupCollection('surveys')!)),
          GoRoute(path: AppRoutes.coordinatorReports, builder: (_, __) => CollectionListScreen(content: lookupCollection('reports')!)),
          GoRoute(path: AppRoutes.coordinatorEvents, builder: (_, __) => CollectionListScreen(content: lookupCollection('events')!)),
          GoRoute(path: AppRoutes.coordinatorAnalytics, builder: (_, __) => const AnalyticsScreen()),
          GoRoute(path: AppRoutes.adminDashboard, builder: (_, __) => const AdminDashboard()),
          GoRoute(path: AppRoutes.adminAnalytics, builder: (_, __) => const AnalyticsScreen(adminMode: true)),
          GoRoute(path: AppRoutes.adminUsers, builder: (_, __) => const UserManagementScreen()),
          GoRoute(path: AppRoutes.adminAuditLogs, builder: (_, __) => const AuditLogScreen()),
          GoRoute(path: AppRoutes.adminProfile, builder: (_, __) => const ProfileScreen()),
        ],
      ),
      GoRoute(path: AppRoutes.profile, builder: (_, __) => const ProfileScreen()),
      GoRoute(path: AppRoutes.editProfile, builder: (_, __) => const EditProfileScreen()),
      GoRoute(path: AppRoutes.employment, builder: (_, __) => const EmploymentHistoryPage()),
      GoRoute(path: AppRoutes.addEmployment, builder: (_, __) => const AddEmploymentScreen()),
      GoRoute(path: AppRoutes.resume, builder: (_, __) => const ResumeUploadScreen()),
      GoRoute(path: AppRoutes.certificates, builder: (_, __) => const CertificateGalleryScreen()),
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
  required bool approved,
}) {
  const authRoutes = {
    AppRoutes.splash,
    AppRoutes.onboarding,
    AppRoutes.login,
    AppRoutes.register,
    AppRoutes.forgotPassword,
  };

  if (authLoading) {
    return location == AppRoutes.splash ? null : AppRoutes.splash;
  }
  if (!loggedIn) return authRoutes.contains(location) ? null : AppRoutes.login;
  if (role == null) return location == AppRoutes.splash ? null : AppRoutes.splash;

  if (!approved && role != UserRole.admin) {
    return location == AppRoutes.pendingApproval
        ? null
        : AppRoutes.pendingApproval;
  }

  final home = dashboardForRole(role);
  final legacy = <String, String>{
    AppRoutes.dashboard: home,
    AppRoutes.dashboardAlumni: role == UserRole.alumni ? AppRoutes.alumniDashboard : home,
    AppRoutes.dashboardJobs: role == UserRole.alumni ? AppRoutes.alumniJobs : home,
    AppRoutes.dashboardDocuments: role == UserRole.alumni ? AppRoutes.alumniDocuments : home,
    AppRoutes.dashboardProfile: role == UserRole.alumni ? AppRoutes.alumniProfile : home,
  };
  if (legacy.containsKey(location)) return legacy[location];
  if (authRoutes.contains(location)) return home;

  final collectionKey = location.startsWith(AppRoutes.staffData)
      ? location
          .substring(AppRoutes.staffData.length + 1)
          .split('?')
          .first
      : null;
  final collectionExists =
      collectionKey != null && lookupCollection(collectionKey) != null;

  final allowed = <UserRole, Set<String>>{
      UserRole.guest: {
        AppRoutes.guestDashboard,
        AppRoutes.about,
        AppRoutes.pendingApproval,
        if (collectionExists) location,
      },
    UserRole.alumni: {
      AppRoutes.alumniDashboard,
      AppRoutes.alumniSurvey,
      AppRoutes.alumniJobs,
      AppRoutes.alumniNotifications,
      AppRoutes.alumniProfile,
      AppRoutes.alumniDocuments,
      AppRoutes.profile,
      AppRoutes.editProfile,
      AppRoutes.employment,
      AppRoutes.addEmployment,
      AppRoutes.resume,
        AppRoutes.certificates,
        AppRoutes.pendingApproval,
        if (collectionExists) location,
      },
    UserRole.coordinator: {
      AppRoutes.coordinatorDashboard,
      AppRoutes.coordinatorAnalytics,
      AppRoutes.adminAnalytics,
      AppRoutes.staffUsers,
      AppRoutes.adminUsers,
      AppRoutes.coordinatorAlumni,
      AppRoutes.coordinatorSurveys,
      AppRoutes.coordinatorReports,
        AppRoutes.coordinatorEvents,
        AppRoutes.pendingApproval,
        if (collectionExists) location,
      },
    UserRole.admin: {
      AppRoutes.adminDashboard,
      AppRoutes.adminAnalytics,
      AppRoutes.adminUsers,
      AppRoutes.adminAuditLogs,
      AppRoutes.adminProfile,
      AppRoutes.editProfile,
        AppRoutes.staffUsers,
        AppRoutes.pendingApproval,
        if (collectionExists) location,
      },
  }[role]!;
  final canAccess =
      allowed.any((path) => location == path || location.startsWith('$path/'));
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