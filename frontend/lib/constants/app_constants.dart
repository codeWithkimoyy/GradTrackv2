import 'package:flutter/material.dart';

/// University-themed palette inspired by StudyBuddy & BISU branding:
/// Deep Ink Navy, Royal Cover Blue, Sky Cyan, University Gold, Soft Ice Surfaces
class AppColors {
  AppColors._();

  // Core Brand
  static const Color primaryBlue = Color(0xFF2563EB); // Royal Blue
  static const Color primaryBlueDark = Color(0xFF1D4ED8);
  static const Color primaryLight = Color(0xFF38BDF8); // Sky Cyan
  static const Color secondaryBlue = Color(0xFF3B82F6);

  // Deep Ink & Text
  static const Color primaryNavy = Color(0xFF0F172A); // Deep Ink Text / Navy
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textMuted = Color(0xFF94A3B8);

  // Surfaces & Backgrounds (StudyBuddy Cool Paper / Ice)
  static const Color surfaceLight = Color(0xFFF3F8FC); // Cool Paper Light BG
  static const Color cardLight = Colors.white; // Pure White Card
  static const Color surfaceLightAlt = Color(0xFFEEF5FA); // Soft Cool Grey Fill

  static const Color surfaceDark = Color(0xFF0F172A);
  static const Color surfaceDarkAlt = Color(0xFF0B132B);
  static const Color cardDark = Color(0xFF1E293B);

  // Accents
  static const Color teal = Color(0xFF0D9488);
  static const Color tealLight = Color(0xFF14B8A6);
  static const Color cyan = Color(0xFF06B6D4);

  static const Color gold = Color(0xFFF5B041);
  static const Color goldDark = Color(0xFFD97706);
  static const Color goldLight = Color(0xFFFDE68A);

  // Status Colors
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF2563EB);

  // Soft Fills (for Squircle icons and badges in Light Theme)
  static const Color primarySoft = Color(0xFFEFF6FF);
  static const Color goldSoft = Color(0xFFFFFBEB);
  static const Color greenSoft = Color(0xFFECFDF5);
  static const Color redSoft = Color(0xFFFEF2F2);
  static const Color tealSoft = Color(0xFFF0FDFA);

  // Borders & Dividers
  static const Color borderLight = Color(0xFFE2E8F0);
  static const Color borderSoftLight = Color(0xFFEDF2F7);
  static const Color borderDark = Color(0xFF334155);

  // Icon background colors
  static const Color iconBgBlue = Color(0xFF1E3A8A);
  static const Color iconBgTeal = Color(0xFF115E59);
  static const Color iconBgGold = Color(0xFF78350F);
  static const Color iconBgGreen = Color(0xFF065F46);
  static const Color iconBgRed = Color(0xFF991B1B);
}

class AppRadius {
  AppRadius._();
  static const double sm = 10;
  static const double card = 20;
  static const double button = 14;
  static const double sheet = 24;
  static const double chip = 20;
}

class AppSpacing {
  AppSpacing._();
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

class AppStrings {
  AppStrings._();
  static const String appName = 'GradTrack';
  static const String universityName = 'Bohol Island State University';
  static const String tagline = 'Empowering Graduates. Connecting Futures.';
  static const String defaultCourse = 'BS Computer Science';

  /// Build tag shown on the login screen so deployments/caches are verifiable.
  static const String buildId = 'b-2026-0909-01';
}

/// Firestore collection names, centralized to avoid typos across the app.
class FirestoreCollections {
  FirestoreCollections._();
  static const String users = 'users';
  static const String employment = 'employment_records';
  static const String surveys = 'surveys';
  static const String surveyResponses = 'survey_responses';
  static const String announcements = 'announcements';
  static const String events = 'events';
  static const String eventRegistrations = 'event_registrations';
  static const String jobs = 'jobs';
  static const String messages = 'messages';
  static const String conversations = 'conversations';
  static const String notifications = 'notifications';
  static const String auditLogs = 'audit_logs';
  static const String skills = 'skills';
  static const String certificates = 'certificates';
  static const String careerMilestones = 'career_milestones';
  static const String reports = 'reports';
  static const String systemSettings = 'system_settings';
}
