import 'package:flutter/material.dart';

/// Centralized University-themed palette: Deep Navy, Royal Blue, Teal, Gold
class AppColors {
  AppColors._();

  static const Color primaryBlue = Color(0xFF2563EB);
  static const Color primaryBlueDark = Color(0xFF1D4ED8);
  static const Color secondaryBlue = Color(0xFF3B82F6);
  static const Color accentBlue = Color(0xFF60A5FA);

  static const Color primaryNavy = Color(0xFF0F172A);
  static const Color surfaceDark = Color(0xFF0F172A);
  static const Color surfaceDarkAlt = Color(0xFF0B132B);
  static const Color cardDark = Color(0xFF1E293B);
  static const Color cardDarkElevated = Color(0xFF24334D);

  static const Color surfaceLight = Color(0xFFF8FAFC);
  static const Color cardLight = Colors.white;

  static const Color teal = Color(0xFF0D9488);
  static const Color tealLight = Color(0xFF14B8A6);
  static const Color cyan = Color(0xFF06B6D4);

  static const Color gold = Color(0xFFF5B041);
  static const Color goldDark = Color(0xFFD97706);
  static const Color goldLight = Color(0xFFFDE68A);

  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // Border & Divider colors
  static const Color borderDark = Color(0xFF334155);
  static const Color borderLight = Color(0xFFE2E8F0);

  // Squircle icon background colors
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
}
