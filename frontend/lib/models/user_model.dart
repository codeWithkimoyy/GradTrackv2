import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { admin, coordinator, alumni, guest }

extension UserRoleX on UserRole {
  String get label => switch (this) {
        UserRole.admin => 'Administrator',
        UserRole.coordinator => 'Department Coordinator',
        UserRole.alumni => 'Alumni',
        UserRole.guest => 'Guest',
      };

  static UserRole fromString(String value) => UserRole.values.firstWhere(
        (r) => r.name == value,
        orElse: () => UserRole.guest,
      );
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
  final String? section;
  final String? biography;
  final SocialLinks socialLinks;
  final EmploymentStatus employmentStatus;
  final bool isVerified;
  final bool emailVerified;
  final bool disabled;
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
    this.section,
    this.biography,
    this.socialLinks = const SocialLinks(),
    this.employmentStatus = EmploymentStatus.unemployed,
    this.isVerified = false,
    this.emailVerified = false,
    this.disabled = false,
    this.profileCompletion = 0.0,
    required this.createdAt,
    this.updatedAt,
  });

  factory UserModel.fromMap(Map<String, dynamic> map, String uid) {
    return UserModel(
      uid: uid,
      email: map['email'] ?? '',
      fullName: map['fullName'] ?? '',
      role: UserRoleX.fromString(map['role'] ?? 'alumni'),
      photoUrl: map['photoUrl'],
      studentNumber: map['studentNumber'],
      gender: map['gender'],
      birthdate: (map['birthdate'] as Timestamp?)?.toDate(),
      phoneNumber: map['phoneNumber'],
      currentAddress: map['currentAddress'],
      permanentAddress: map['permanentAddress'],
      graduationYear: map['graduationYear'],
      course: map['course'],
      section: map['section'],
      biography: map['biography'],
      socialLinks: SocialLinks.fromMap(map['socialLinks']),
      employmentStatus:
          EmploymentStatusX.fromString(map['employmentStatus'] ?? 'unemployed'),
      isVerified: map['isVerified'] ?? false,
      emailVerified: map['emailVerified'] ?? false,
      disabled: map['disabled'] ?? false,
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
        'section': section,
        'biography': biography,
        'socialLinks': socialLinks.toMap(),
        'employmentStatus': employmentStatus.name,
        'isVerified': isVerified,
        'emailVerified': emailVerified,
        'disabled': disabled,
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
    String? section,
    String? biography,
    SocialLinks? socialLinks,
    EmploymentStatus? employmentStatus,
    bool? isVerified,
    bool? emailVerified,
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
      section: section ?? this.section,
      biography: biography ?? this.biography,
      socialLinks: socialLinks ?? this.socialLinks,
      employmentStatus: employmentStatus ?? this.employmentStatus,
      isVerified: isVerified ?? this.isVerified,
      emailVerified: emailVerified ?? this.emailVerified,
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
      u.biography != null,
      u.socialLinks.linkedIn != null,
    ];
    final filled = fields.where((f) => f).length;
    return (filled / fields.length) * 100;
  }
}
