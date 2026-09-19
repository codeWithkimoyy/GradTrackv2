import 'package:flutter/material.dart';

/// Bohol Island State University (BISU) & GradTrack High-Contrast Design System
/// Official Primary Navy (#003DA5), Sky Cyan (#0284C7), University Gold, Defined 1.5px Outlines, Ice White Surfaces
class AppColors {
  AppColors._();

  // 1. Core Interactive Blues (WCAG AAA High Contrast against white text)
  static const Color primaryBlue = Color(0xFF003DA5); // BISU Official Primary Navy (Contrast 9.8:1)
  static const Color primaryBlueDark = Color(0xFF002D7A); // bisuBlue800 for pressed/active states
  static const Color secondaryBlue = Color(0xFF1D4ED8); // Rich royal blue
  static const Color primaryLight = Color(0xFF0284C7); // High-contrast accessible cyan
  static const Color primaryLightSkyCyan = Color(0xFF0284C7);
  static const Color bisuOfficialPrimary = Color(0xFF003DA5);

  // 2. GradTrack Accent Palette
  static const Color logoCyan = Color(0xFF0284C7);
  static const Color logoCyanAccent = Color(0xFF00B4D8); // Electric cyan accent
  static const Color logoCyanLight = Color(0xFF38BDF8); // Chart & highlight accents
  static const Color logoCyanSoft = Color(0xFFE0F2FE); // Soft cyan tint background
  static const Color logoBlue = Color(0xFF003DA5);
  static const Color logoGold = Color(0xFFD97706); // High-contrast dark amber/gold for text (4.8:1)
  static const Color logoGoldBright = Color(0xFFF5B041); // Bright gold for icons, nodes, accents
  static const Color logoGoldSoft = Color(0xFFFFFBEB);
  static const Color logoNavy = Color(0xFF071E4A);
  static const Color logoNavyDark = Color(0xFF031A48);

  // 3. Shape Outline Tokens (Defined 1.5px contours)
  static const Color outlineCard = Color(0xFFE2EAF4);
  static const Color outlineCardActive = Color(0x59003DA5); // rgba(0, 61, 165, 0.35)
  static const Color outlineBadge = Color(0x4D0284C7); // rgba(2, 132, 199, 0.30)
  static const Color outlineGold = Color(0x59D97706); // rgba(217, 119, 6, 0.35)
  static const Color outlineSoft = Color(0xFFEDF2F8);

  // 4. Eye-Comfort Surfaces & Backgrounds (Soothing Ice-White / Slate)
  static const Color surfaceLight = Color(0xFFF4F7FB); // Soothing cool paper / ice tint
  static const Color cardLight = Colors.white; // Crisp rounded card surface
  static const Color surfaceLightAlt = Color(0xFFEEF4F9); // Gentle input and pill surface

  static const Color surfaceDark = Color(0xFF0F172A);
  static const Color surfaceDarkAlt = Color(0xFF0B132B);
  static const Color cardDark = Color(0xFF1E293B);

  // Overlays & Web Meta
  static const Color webThemeMetaColor = Color(0xFF031A48);
  static const Color overlayNavyPhotoVeil = Color(0xD1071E4A); // rgba(7, 30, 74, 0.82)
  static const Color overlayAuthSolid = Color(0xDE003DA8); // rgba(0, 61, 168, 0.87)

  // 5. Typography & Ink (High Contrast, WCAG AAA compliant)
  static const Color primaryNavy = Color(0xFF0F172A);
  static const Color textPrimary = Color(0xFF0F172A); // Deep slate navy (16.2:1 against white)
  static const Color textSecondary = Color(0xFF475569); // Darker slate (7.1:1 against white)
  static const Color textMuted = Color(0xFF64748B); // Medium slate (4.6:1 against white)

  // Accents
  static const Color teal = Color(0xFF0284C7);
  static const Color tealLight = Color(0xFF38BDF8);
  static const Color cyan = Color(0xFF0284C7);

  /// Text-safe deep teal for small text on light surfaces (5.9:1 on white).
  /// [teal] itself is 4.1:1 on white — use only for large text, icons, fills.
  static const Color tealDeep = Color(0xFF0369A1);

  static const Color gold = Color(0xFFF5B041);
  static const Color goldDark = Color(0xFFD97706);
  static const Color goldLight = Color(0xFFFDE68A);

  /// Text-safe deep bronze for small text on light surfaces (7.1:1 on white).
  /// [goldDark] is 3.2:1 on white — use only for large text, icons, fills.
  static const Color goldDeep = Color(0xFF92400E);

  // 6. Status Colors
  static const Color success = Color(0xFF047857); // Deep emerald (Contrast 4.9:1)
  static const Color warning = Color(0xFFB45309); // Deep amber (Contrast 4.6:1)
  static const Color error = Color(0xFFDC2626); // Deep crimson red (Contrast 4.7:1)
  static const Color info = Color(0xFF003DA5); // BISU Blue

  // Light variants for small text on dark surfaces (all 6.8:1+ on cardDark)
  static const Color successLight = Color(0xFF6EE7B7);
  static const Color warningLight = Color(0xFFFCD34D);
  static const Color errorLight = Color(0xFFFCA5A5);

  // 7. Soft Fills (for Squircle icons and badges)
  static const Color primarySoft = Color(0xFFEFF6FF);
  static const Color goldSoft = Color(0xFFFFFBEB);
  static const Color greenSoft = Color(0xFFECFDF5);
  static const Color redSoft = Color(0xFFFEF2F2);
  static const Color tealSoft = Color(0xFFE0F2FE);
  static const Color orangeSoft = Color(0xFFFFFBEB);
  static const Color purpleSoft = Color(0xFFEFF6FF);

  // Borders & Dividers
  static const Color borderLight = Color(0xFFE2EAF4);
  static const Color borderSoftLight = Color(0xFFEDF2F8);
  static const Color borderDark = Color(0xFF334155);

  // Icon background colors
  static const Color iconBgBlue = Color(0xFF003DA5);
  static const Color iconBgTeal = Color(0xFF0284C7);
  static const Color iconBgGold = Color(0xFFD97706);
  static const Color iconBgGreen = Color(0xFF047857);
  static const Color iconBgRed = Color(0xFFDC2626);

  // BISU Royal Blue Scale
  static const Color bisuBlue50 = Color(0xFFEFF6FF);
  static const Color bisuBlue100 = Color(0xFFDBEAFE);
  static const Color bisuBlue200 = Color(0xFFBFDBFE);
  static const Color bisuBlue300 = Color(0xFF93C5FD);
  static const Color bisuBlue400 = Color(0xFF60A5FA);
  static const Color bisuBlue500 = Color(0xFF3B82F6);
  static const Color bisuBlue600 = Color(0xFF1E5FD1);
  static const Color bisuBlue700 = Color(0xFF003DA5); // Official Primary
  static const Color bisuBlue800 = Color(0xFF002D7A);
  static const Color bisuBlue900 = Color(0xFF001F5B);
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

  /// The program this deployment tracks. Admin lists show only matching
  /// records. Blank courses count as a match, consistent with the display
  /// fallback to [defaultCourse].
  static const String focusCourse = 'BS Computer Science';

  static bool isFocusCourse(String? course) {
    final c = (course ?? '').trim().toLowerCase();
    if (c.isEmpty) return true;
    return c.contains('computer science');
  }

  /// Synthesized address used for alumni Auth login so they can sign in with
  /// their Alumni ID instead of an email: BISU-2020-001@gradtrack.bisu.edu.ph.
  static const String alumniEmailSuffix = '@gradtrack.bisu.edu.ph';

  static String alumniEmailFromId(String alumniId) =>
      '$alumniId$alumniEmailSuffix';

  /// Alumni IDs may only contain letters, digits, hyphens and underscores.
  static final RegExp alumniIdPattern = RegExp(r'^[A-Za-z0-9_\-]+$');

  /// Build tag shown on the login screen so deployments/caches are verifiable.
  static const String buildId = 'b-2026-0909-16';
}

/// Backend content-collection names, centralized to avoid typos across the
/// app. These keys address `GET|POST|PATCH|DELETE /api/content/:collection`
/// (and the dedicated survey/audit endpoints) on the MySQL backend.
class ApiCollections {
  ApiCollections._();
  static const String users = 'users';
  static const String alumniRegistry = 'alumni_registry';
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
