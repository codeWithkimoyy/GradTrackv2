import 'dart:convert';
import 'dart:typed_data';

const Object _unset = Object();

/// Parses API date values (ISO-8601 strings, epoch millis, or DateTime).
DateTime? parseApiDate(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  if (value is String) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    // MySQL DATETIME comes back as "YYYY-MM-DD HH:MM:SS".
    final normalized =
        trimmed.contains('T') ? trimmed : trimmed.replaceFirst(' ', 'T');
    return DateTime.tryParse(normalized);
  }
  return null;
}

/// Parses an API date-only value ("YYYY-MM-DD").
DateTime? parseApiDateOnly(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is String) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    return DateTime.tryParse(trimmed.length > 10 ? trimmed : '${trimmed}T00:00:00');
  }
  return null;
}

enum UserRole { admin, alumni }

extension UserRoleX on UserRole {
  String get label => switch (this) {
        UserRole.admin => 'Administrator',
        UserRole.alumni => 'Alumni',
      };

  static UserRole fromString(String value) => UserRole.values.firstWhere(
        (r) => r.name == value,
        orElse: () => UserRole.alumni,
      );
}

/// Converts a stored academic year like "2025-2026" into its display form
/// "2025–2026". Falls back to "Not Specified" for legacy records.
String displayAcademicYear(String? value) {
  final v = value?.trim() ?? '';
  return v.isEmpty ? 'Not Specified' : v.replaceAll('-', '\u2013');
}

/// Parses the starting year of an academic year ("2025-2026" -> 2025).
int? academicYearStart(String? value) =>
    int.tryParse((value ?? '').split('-').first.trim());

/// Academic-year pair label for a starting year, e.g. 2022 -> "2022–2023".
/// Matches the display style used by [displayAcademicYear].
String academicYearLabel(int startYear) =>
    '$startYear\u2013${startYear + 1}';

/// Human label for a graduation batch header, e.g. "S.Y. 2025–2026".
/// Legacy alumni without an academic year are shown under
/// "Academic Year Not Specified".
String graduationBatchLabel(String? value) {
  final v = value?.trim() ?? '';
  return v.isEmpty
      ? 'Academic Year Not Specified'
      : 'S.Y. ${displayAcademicYear(v)}';
}

/// Derives a stable graduation-batch key for grouping and sorting.
/// Prefers `academicYearGraduated` ("2025-2026"); falls back to the legacy
/// `graduationYear` (bucket "gy:2025"); empty when neither is available.
String graduationBatchKey({
  String? academicYearGraduated,
  int? graduationYear,
}) {
  final ac = (academicYearGraduated ?? '').trim();
  if (ac.isNotEmpty) return ac;
  if (graduationYear != null && graduationYear > 0) {
    return 'gy:$graduationYear';
  }
  return '';
}

/// Returns (sort weight, section label) for a graduation-batch key.
/// Newer years sort first; records with no year sort last.
(int? startYear, String label) graduationBatchInfo(String key) {
  if (key.isEmpty) {
    return (null, 'Academic Year Not Specified');
  }
  if (key.startsWith('gy:')) {
    final y = int.tryParse(key.substring(3));
    return y == null ? (null, 'Academic Year Not Specified') : (y, 'S.Y. $y');
  }
  return (academicYearStart(key), graduationBatchLabel(key));
}

enum EmploymentStatus {
  employed,
  selfEmployed,
  freelance,
  unemployed,
  studying
}

extension EmploymentStatusX on EmploymentStatus {
  String get label => switch (this) {
        EmploymentStatus.employed => 'Employed',
        EmploymentStatus.selfEmployed => 'Self-employed',
        EmploymentStatus.freelance => 'Freelance',
        EmploymentStatus.unemployed => 'Unemployed',
        EmploymentStatus.studying => 'Continuing Studies',
      };

  static EmploymentStatus fromString(String value) =>
      EmploymentStatus.values.firstWhere(
        (s) => s.name == value,
        orElse: () => EmploymentStatus.unemployed,
      );
}

class SocialLinks {
  final String? github;
  final String? linkedIn;
  final String? portfolio;
  final String? facebook;

  const SocialLinks(
      {this.github, this.linkedIn, this.portfolio, this.facebook});

  factory SocialLinks.fromMap(dynamic map) {
    if (map is! Map) return const SocialLinks();
    return SocialLinks(
      github: map['github']?.toString(),
      linkedIn: map['linkedIn']?.toString(),
      portfolio: map['portfolio']?.toString(),
      facebook: map['facebook']?.toString(),
    );
  }

  Map<String, dynamic> toMap() => {
        'github': github,
        'linkedIn': linkedIn,
        'portfolio': portfolio,
        'facebook': facebook,
      };
}

class UserModel {
  final String uid;
  final String email;
  final String fullName;
  final UserRole role;
  final String? photoUrl;
  final String? studentNumber;
  final String? alumniId;
  final String? gender;
  final DateTime? birthdate;
  final String? phoneNumber;
  final String? currentAddress;
  final String? permanentAddress;
  final int? graduationYear;
  final String? course;
  final String? academicYearGraduated;
  final String? section;
  final String? biography;
  final SocialLinks socialLinks;
  final EmploymentStatus employmentStatus;
  final bool isVerified;
  final bool emailVerified;
  final bool disabled;
  final bool approved;
  final bool hasLoggedIn;
  final DateTime? lastLoginAt;
  final double profileCompletion;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const UserModel({
    required this.uid,
    required this.email,
    required this.fullName,
    required this.role,
    this.photoUrl,
this.studentNumber,
    this.alumniId,
    this.gender,
    this.birthdate,
    this.phoneNumber,
    this.currentAddress,
    this.permanentAddress,
    this.graduationYear,
    this.course,
    this.academicYearGraduated,
    this.section,
    this.biography,
    this.socialLinks = const SocialLinks(),
    this.employmentStatus = EmploymentStatus.unemployed,
        this.isVerified = false,
        this.emailVerified = false,
        this.disabled = false,
        this.approved = true,
        this.hasLoggedIn = false,
        this.lastLoginAt,
        this.profileCompletion = 0.0,
    required this.createdAt,
    this.updatedAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> map, String uid) {
    final role = UserRoleX.fromString(map['role'] ?? 'alumni');
    return UserModel(
      uid: uid,
      email: map['email']?.toString() ?? '',
      fullName: map['fullName']?.toString() ?? '',
      role: role,
      photoUrl: map['photoUrl']?.toString(),
      studentNumber: map['studentNumber']?.toString(),
      alumniId: map['alumniId']?.toString(),
      gender: map['gender']?.toString(),
      birthdate: parseApiDateOnly(map['birthdate']),
      phoneNumber: map['phoneNumber']?.toString(),
      currentAddress: map['currentAddress']?.toString(),
      permanentAddress: map['permanentAddress']?.toString(),
      graduationYear: (map['graduationYear'] as num?)?.toInt(),
      course: map['course']?.toString(),
      academicYearGraduated: map['academicYearGraduated']?.toString(),
      section: map['section']?.toString(),
      biography: map['biography']?.toString(),
      socialLinks: SocialLinks.fromMap(map['socialLinks']),
      employmentStatus:
          EmploymentStatusX.fromString(map['employmentStatus']?.toString() ?? 'unemployed'),
      isVerified: map['isVerified'] == true,
      emailVerified: map['emailVerified'] == true,
      disabled: map['disabled'] == true,
      approved: role == UserRole.admin ? true : (map['approved'] ?? true) == true,
      hasLoggedIn: map['hasLoggedIn'] == true,
      lastLoginAt: parseApiDate(map['lastLoginAt']),
      profileCompletion: (map['profileCompletion'] as num?)?.toDouble() ?? 0.0,
      createdAt: parseApiDate(map['createdAt']) ?? DateTime.now(),
      updatedAt: parseApiDate(map['updatedAt']),
    );
  }

  /// Encodes the profile for the REST API (ISO-8601 dates, no Timestamps).
  Map<String, dynamic> toJson() => {
        'email': email,
        'fullName': fullName,
        'role': role.name,
        'photoUrl': photoUrl,
        'studentNumber': studentNumber,
        'alumniId': alumniId,
        'gender': gender,
        'birthdate': birthdate != null
            ? '${birthdate!.year.toString().padLeft(4, '0')}-${birthdate!.month.toString().padLeft(2, '0')}-${birthdate!.day.toString().padLeft(2, '0')}'
            : null,
        'phoneNumber': phoneNumber,
        'currentAddress': currentAddress,
        'permanentAddress': permanentAddress,
        'graduationYear': graduationYear,
        'course': course,
        'academicYearGraduated': academicYearGraduated,
        'section': section,
        'biography': biography,
        'socialLinks': socialLinks.toMap(),
        'employmentStatus': employmentStatus.name,
        'isVerified': isVerified,
        'emailVerified': emailVerified,
        'disabled': disabled,
        'approved': approved,
        'hasLoggedIn': hasLoggedIn,
        if (lastLoginAt != null)
          'lastLoginAt': lastLoginAt!.toIso8601String(),
        'profileCompletion': profileCompletion,
        'createdAt': createdAt.toIso8601String(),
        if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
      };

  /// Backwards-compatible alias (the REST API uses [toJson]).
  Map<String, dynamic> toMap() => toJson();

  bool get hasBase64Photo => photoUrl?.startsWith('data:') ?? false;

  Uint8List? get photoBytes =>
      hasBase64Photo ? base64Decode(photoUrl!.split(',').last) : null;

  UserModel copyWith({
    String? fullName,
    String? photoUrl,
    String? studentNumber,
    Object? alumniId = _unset,
    String? gender,
    DateTime? birthdate,
    String? phoneNumber,
    String? currentAddress,
    String? permanentAddress,
    int? graduationYear,
    String? course,
    Object? academicYearGraduated = _unset,
    String? section,
    String? biography,
    SocialLinks? socialLinks,
    EmploymentStatus? employmentStatus,
    bool? isVerified,
    bool? emailVerified,
    bool? approved,
    bool? hasLoggedIn,
    Object? lastLoginAt = _unset,
    double? profileCompletion,
  }) {
    return UserModel(
      uid: uid,
      email: email,
      fullName: fullName ?? this.fullName,
      role: role,
      photoUrl: photoUrl ?? this.photoUrl,
      studentNumber: studentNumber ?? this.studentNumber,
      alumniId: alumniId == _unset ? this.alumniId : alumniId as String?,
      gender: gender ?? this.gender,
      birthdate: birthdate ?? this.birthdate,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      currentAddress: currentAddress ?? this.currentAddress,
      permanentAddress: permanentAddress ?? this.permanentAddress,
      graduationYear: graduationYear ?? this.graduationYear,
      course: course ?? this.course,
      academicYearGraduated: academicYearGraduated == _unset
          ? this.academicYearGraduated
          : academicYearGraduated as String?,
      section: section ?? this.section,
      biography: biography ?? this.biography,
      socialLinks: socialLinks ?? this.socialLinks,
      employmentStatus: employmentStatus ?? this.employmentStatus,
      isVerified: isVerified ?? this.isVerified,
      emailVerified: emailVerified ?? this.emailVerified,
      approved: approved ?? this.approved,
      hasLoggedIn: hasLoggedIn ?? this.hasLoggedIn,
      lastLoginAt: lastLoginAt == _unset
          ? this.lastLoginAt
          : lastLoginAt as DateTime?,
      profileCompletion: profileCompletion ?? this.profileCompletion,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  /// Computes how complete the profile is (0-100) based on filled fields.
  static double computeCompletion(UserModel u) {
    final fields = <bool>[
      u.photoUrl != null,
      u.studentNumber != null,
      u.gender != null,
      u.birthdate != null,
      u.phoneNumber != null,
      u.currentAddress != null,
      u.permanentAddress != null,
      u.graduationYear != null,
      u.course != null,
      u.academicYearGraduated != null,
      u.biography != null,
      u.socialLinks.linkedIn != null,
    ];
    final filled = fields.where((f) => f).length;
    return (filled / fields.length) * 100;
  }
}
