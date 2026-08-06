import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/user_model.dart';
import '../providers/auth_providers.dart';
import '../providers/role_providers.dart';
import '../screens/auth/splash_screen.dart';
import '../screens/auth/onboarding_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/auth/forgot_password_screen.dart';
import '../screens/dashboard/dashboard_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/profile/edit_profile_screen.dart';
import '../screens/employment/employment_history_screen.dart';
import '../screens/employment/add_employment_screen.dart';
import '../screens/documents/resume_upload_screen.dart';
import '../screens/documents/certificate_gallery_screen.dart';

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
  static const profile = '/profile';
  static const editProfile = '/profile/edit';
  static const employment = '/employment';
  static const addEmployment = '/employment/add';
  static const resume = '/documents/resume';
  static const certificates = '/documents/certificates';
}

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: false,
    redirect: (context, state) {
      final loggedIn = authState.value != null;
      final loc = state.matchedLocation;
      final userRole = ref.watch(currentUserRoleProvider);

      final authRoutes = {
        AppRoutes.splash,
        AppRoutes.onboarding,
        AppRoutes.login,
        AppRoutes.register,
        AppRoutes.forgotPassword,
      };

      final alumniRoutes = {
        ...authRoutes,
        AppRoutes.dashboard,
        AppRoutes.dashboardAlumni,
        AppRoutes.dashboardJobs,
        AppRoutes.dashboardDocuments,
        AppRoutes.dashboardProfile,
        AppRoutes.profile,
        AppRoutes.editProfile,
        AppRoutes.employment,
        AppRoutes.addEmployment,
        AppRoutes.resume,
        AppRoutes.certificates,
      };

      final staffRoutes = {
        ...alumniRoutes,
        // Add staff-only routes here when implemented.
      };

      if (authState.isLoading) {
        return loc == AppRoutes.splash ? null : AppRoutes.splash;
      }

      if (!loggedIn && !authRoutes.contains(loc)) {
        return AppRoutes.login;
      }

      if (loggedIn && userRole == null) {
        return loc == AppRoutes.splash ? null : AppRoutes.splash;
      }

      if (userRole == UserRole.guest) {
        const guestRoutes = {
          AppRoutes.login,
          AppRoutes.register,
        };
        return guestRoutes.contains(loc) ? null : AppRoutes.login;
      }

      if (loggedIn && authRoutes.contains(loc)) {
        return AppRoutes.dashboard;
      }

      if (userRole == UserRole.alumni && !alumniRoutes.contains(loc)) {
        return AppRoutes.dashboard;
      }

      if ((userRole == UserRole.coordinator || userRole == UserRole.admin) &&
          !staffRoutes.contains(loc)) {
        return AppRoutes.dashboard;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => DashboardShell(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.dashboard,
            builder: (context, state) => const DashboardHomeTab(),
          ),
          GoRoute(
            path: AppRoutes.dashboardAlumni,
            builder: (context, state) => const DashboardAlumniTab(),
          ),
          GoRoute(
            path: AppRoutes.dashboardJobs,
            builder: (context, state) => const DashboardJobsTab(),
          ),
          GoRoute(
            path: AppRoutes.dashboardDocuments,
            builder: (context, state) => const DashboardDocumentsTab(),
          ),
          GoRoute(
            path: AppRoutes.dashboardProfile,
            builder: (context, state) => const ProfileScreen(),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.profile,
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: AppRoutes.editProfile,
        builder: (context, state) => const EditProfileScreen(),
      ),
      GoRoute(
        path: AppRoutes.employment,
        builder: (context, state) => const EmploymentHistoryPage(),
      ),
      GoRoute(
        path: AppRoutes.addEmployment,
        builder: (context, state) => const AddEmploymentScreen(),
      ),
      GoRoute(
        path: AppRoutes.resume,
        builder: (context, state) => const ResumeUploadScreen(),
      ),
      GoRoute(
        path: AppRoutes.certificates,
        builder: (context, state) => const CertificateGalleryScreen(),
      ),
    ],
  );
});
