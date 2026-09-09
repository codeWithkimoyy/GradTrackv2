import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';

<<<<<<< HEAD
enum UserRole { admin, alumni }
=======
/// Library-scope sentinel distinguishing an omitted copyWith argument
/// from an explicitly provided null (which clears the field).
const Object _unset = Object();

enum UserRole { admin, coordinator, alumni, guest }
>>>>>>> 912ab68eea4fd77971b7cda4789ea56cc9845bd6

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

  factory SocialLinks.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const SocialLinks();
    return SocialLinks(
      github: map['github'],
      linkedIn: map['linkedIn'],
      portfolio: map['portfolio'],
      facebook: map['facebook'],
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
  final String? gender;
  final DateTime? birthdate;
  final String? phoneNumber;
  final String? currentAddress;
  final String? permanentAddress;
  final int? graduationYear;
  final String? course;
  final String? academicYearGraduated;
  final String? section;
  final String? academicYearGraduated;
  final String? biography;
  final SocialLinks socialLinks;
  final EmploymentStatus employmentStatus;
  final bool isVerified;
  final bool emailVerified;
  final bool disabled;
  final bool approved;
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
    this.gender,
    this.birthdate,
    this.phoneNumber,
    this.currentAddress,
    this.permanentAddress,
    this.graduationYear,
    this.course,
    this.academicYearGraduated,
    this.section,
    this.academicYearGraduated,
    this.biography,
    this.socialLinks = const SocialLinks(),
    this.employmentStatus = EmploymentStatus.unemployed,
        this.isVerified = false,
        this.emailVerified = false,
        this.disabled = false,
        this.approved = true,
        this.profileCompletion = 0.0,
    required this.createdAt,
    this.updatedAt,
  });

  factory UserModel.fromMap(Map<String, dynamic> map, String uid) {
    final role = UserRoleX.fromString(map['role'] ?? 'alumni');
    return UserModel(
      uid: uid,
      email: map['email'] ?? '',
      fullName: map['fullName'] ?? '',
      role: role,
      photoUrl: map['photoUrl'],
      studentNumber: map['studentNumber'],
      gender: map['gender'],
      birthdate: (map['birthdate'] as Timestamp?)?.toDate(),
      phoneNumber: map['phoneNumber'],
      currentAddress: map['currentAddress'],
      permanentAddress: map['permanentAddress'],
      graduationYear: map['graduationYear'],
      course: map['course'],
      academicYearGraduated: map['academicYearGraduated'],
      section: map['section'],
      academicYearGraduated: map['academicYearGraduated'],
      biography: map['biography'],
      socialLinks: SocialLinks.fromMap(map['socialLinks']),
      employmentStatus:
          EmploymentStatusX.fromString(map['employmentStatus'] ?? 'unemployed'),
      isVerified: map['isVerified'] ?? false,
      emailVerified: map['emailVerified'] ?? false,
      disabled: map['disabled'] ?? false,
      approved: role == UserRole.admin ? true : (map['approved'] ?? true),
      profileCompletion: (map['profileCompletion'] ?? 0.0).toDouble(),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  factory UserModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      UserModel.fromMap(doc.data() ?? {}, doc.id);

  Map<String, dynamic> toMap() => {
        'email': email,
        'fullName': fullName,
        'role': role.name,
        'photoUrl': photoUrl,
        'studentNumber': studentNumber,
        'gender': gender,
        'birthdate': birthdate != null ? Timestamp.fromDate(birthdate!) : null,
        'phoneNumber': phoneNumber,
        'currentAddress': currentAddress,
        'permanentAddress': permanentAddress,
        'graduationYear': graduationYear,
        'course': course,
        'academicYearGraduated': academicYearGraduated,
        'section': section,
        'academicYearGraduated': academicYearGraduated,
        'biography': biography,
        'socialLinks': socialLinks.toMap(),
        'employmentStatus': employmentStatus.name,
        'isVerified': isVerified,
        'emailVerified': emailVerified,
        'disabled': disabled,
        'approved': approved,
        'profileCompletion': profileCompletion,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.now(),
      };

  bool get hasBase64Photo => photoUrl?.startsWith('data:') ?? false;

  Uint8List? get photoBytes =>
      hasBase64Photo ? base64Decode(photoUrl!.split(',').last) : null;

  UserModel copyWith({
    String? fullName,
    String? photoUrl,
    String? studentNumber,
    String? gender,
    DateTime? birthdate,
    String? phoneNumber,
    String? currentAddress,
    String? permanentAddress,
    int? graduationYear,
    String? course,
    Object? academicYearGraduated = _unset,
    String? section,
    String? academicYearGraduated,
    String? biography,
    SocialLinks? socialLinks,
    EmploymentStatus? employmentStatus,
    bool? isVerified,
    bool? emailVerified,
    bool? approved,
    double? profileCompletion,
  }) {
    return UserModel(
      uid: uid,
      email: email,
      fullName: fullName ?? this.fullName,
      role: role,
      photoUrl: photoUrl ?? this.photoUrl,
      studentNumber: studentNumber ?? this.studentNumber,
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
      academicYearGraduated:
          academicYearGraduated ?? this.academicYearGraduated,
      biography: biography ?? this.biography,
      socialLinks: socialLinks ?? this.socialLinks,
      employmentStatus: employmentStatus ?? this.employmentStatus,
      isVerified: isVerified ?? this.isVerified,
      emailVerified: emailVerified ?? this.emailVerified,
      approved: approved ?? this.approved,
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
