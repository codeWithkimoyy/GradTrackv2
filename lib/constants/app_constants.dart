import 'package:flutter/material.dart';

/// University-themed palette: Blue, White, Gold
class AppColors {
  AppColors._();

  static const Color primaryBlue = Color(0xFF1E3A8A);
  static const Color secondaryBlue = Color(0xFF60A5FA);
  static const Color gold = Color(0xFFF4B400);
  static const Color goldLight = Color(0xFFFFD166);
  static const Color surfaceLight = Color(0xFFF7F9FC);
  static const Color surfaceDark = Color(0xFF121417);

  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF2563EB);
}

class AppRadius {
  AppRadius._();
  static const double card = 18;
  static const double button = 16;
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
}

class AppStrings {
  AppStrings._();
  static const String appName = 'GradTrack';
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
