import '../constants/app_constants.dart';
import '../models/user_model.dart';
import '../services/api_client.dart';

/// Central user profile repository backed by the GradTrack MySQL backend.
/// Live streams are implemented as short-polling streams ([ApiClient.poll])
/// because the REST API has no push channel.
class UserRepository {
  UserRepository({ApiClient? api}) : _api = api ?? ApiClient();

  final ApiClient _api;

  static const Duration pollInterval = Duration(seconds: 30);

  Stream<UserModel?> watchUser(String uid) {
    return _api.poll(() => fetchUser(uid));
  }

  Future<UserModel?> fetchUser(String uid) async {
    final me = _api.currentUid;
    try {
      if (me == null || me == uid) {
        final raw = await _api.get('/api/profile');
        if (raw == null) return null;
        final map = Map<String, dynamic>.from(raw);
        return UserModel.fromJson(map, map['uid']?.toString() ?? uid);
      }
      final raw = await _api.get('/api/alumni/users/$uid');
      final map = Map<String, dynamic>.from(raw);
      return UserModel.fromJson(map, map['uid']?.toString() ?? uid);
    } on ApiException catch (e) {
      if (e.statusCode == 404 || e.statusCode == 403) return null;
      rethrow;
    }
  }

  /// Persists the current user's editable profile fields.
  Future<void> saveUser(UserModel user, {bool merge = true}) async {
    await _api.patch('/api/profile', body: _editableBody(user.toJson()));
  }

  Future<void> updateUser(String uid, Map<String, dynamic> changes) async {
    if (_api.currentUid == null || _api.currentUid == uid) {
      await _api.patch('/api/profile', body: changes);
    } else {
      await _api.patch('/api/alumni/users/$uid',
          body: _adminBody(changes));
    }
  }

  /// Keeps only the fields the self-profile endpoint accepts.
  Map<String, dynamic> _editableBody(Map<String, dynamic> json) {
    const allowed = {
      'fullName',
      'photoUrl',
      'studentNumber',
      'gender',
      'birthdate',
      'phoneNumber',
      'currentAddress',
      'permanentAddress',
      'graduationYear',
      'course',
      'section',
      'biography',
      'socialLinks',
      'employmentStatus',
      'academicYearGraduated',
    };
    return Map.fromEntries(
        json.entries.where((e) => allowed.contains(e.key)));
  }

  /// Translates client-side change maps to the admin user endpoint.
  Map<String, dynamic> _adminBody(Map<String, dynamic> changes) {
    const map = {
      'fullName': 'fullName',
      'course': 'course',
      'graduationYear': 'graduationYear',
      'academicYearGraduated': 'academicYearGraduated',
      'employmentStatus': 'employmentStatus',
      'isVerified': 'isVerified',
      'emailVerified': 'emailVerified',
      'approved': 'approved',
      'disabled': 'disabled',
      'role': 'role',
      'studentNumber': 'studentNumber',
      'section': 'section',
      'phoneNumber': 'phoneNumber',
      'hasLoggedIn': 'hasLoggedIn',
      'lastLoginAt': 'lastLoginAt',
    };
    final out = <String, dynamic>{};
    for (final entry in changes.entries) {
      final key = map[entry.key];
      if (key != null) out[key] = entry.value;
    }
    return out;
  }

  Future<bool> userExists(String uid) async {
    return (await fetchUser(uid)) != null;
  }

  /// Returns the office pre-registered record for an Alumni ID, or null when
  /// the ID was never added by an administrator. Public (pre-login) endpoint.
  Future<AlumniRegistryEntry?> fetchRegistryEntry(String alumniId) async {
    try {
      final raw = await _api.get('/api/alumni/registry/$alumniId',
          auth: false);
      return AlumniRegistryEntry.fromJson(Map<String, dynamic>.from(raw));
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<void> saveRegistryEntry(AlumniRegistryEntry entry) async {
    await _api.post('/api/alumni/registry', body: entry.toJson());
  }

  Future<void> removeRegistryEntry(String alumniId) async {
    await _api.delete('/api/alumni/registry/$alumniId');
  }

  /// Transitions an ID's status (used when an alumni activates their account:
  /// Pending → Active). Other transitions are admin-only.
  Future<void> updateRegistryStatus(
    String alumniId,
    AlumniAccountStatus status, {
    DateTime? activatedAt,
  }) async {
    await _api.patch('/api/alumni/registry/$alumniId', body: {
      'status': status.name,
      if (activatedAt != null)
        'activatedAt': activatedAt.toIso8601String(),
    });
  }

  /// Registry records for the admin Alumni Management module.
  Stream<List<AlumniRegistryEntry>> watchRegistry() {
    return _api.poll(fetchRegistry, interval: pollInterval);
  }

  Future<List<AlumniRegistryEntry>> fetchRegistry() async {
    final raw = await _api.get('/api/alumni/registry');
    final list = (raw as List).cast<Map<String, dynamic>>();
    return list.map(AlumniRegistryEntry.fromJson).toList();
  }

  /// Finds the user id linked to an Alumni ID (e.g. to disable it).
  Future<String?> findUserByAlumniId(String alumniId) async {
    final raw = await _api
        .get('/api/alumni/users', query: {'q': alumniId, 'limit': '5'});
    final list = (raw as List).cast<Map<String, dynamic>>();
    for (final item in list) {
      if (item['alumniId']?.toString() == alumniId) {
        return item['uid']?.toString();
      }
    }
    return null;
  }

  /// Admin user directory (filters mirror the staff UI).
  Future<List<UserModel>> fetchUsers({
    String? role,
    bool? approved,
    String? query,
    int limit = 200,
  }) async {
    final params = <String, String>{'limit': '$limit'};
    if (role != null) params['role'] = role;
    if (approved != null) params['approved'] = approved ? '1' : '0';
    if (query != null && query.isNotEmpty) params['q'] = query;
    final raw = await _api.get('/api/alumni/users', query: params);
    final list = (raw as List).cast<Map<String, dynamic>>();
    return list
        .map((m) => UserModel.fromJson(m, m['uid']?.toString() ?? ''))
        .toList();
  }

  Stream<List<UserModel>> watchUsers({
    String? role,
    bool? approved,
    String? query,
    int limit = 200,
  }) {
    return _api.poll(
      () => fetchUsers(role: role, approved: approved, query: query, limit: limit),
      interval: pollInterval,
    );
  }

  Future<void> deleteUser(String uid) {
    return _api.delete('/api/alumni/users/$uid');
  }

  /// Admin creates a staff/alumni account directly (email + password).
  Future<UserModel> createUser({
    required String email,
    required String password,
    required String fullName,
    required UserRole role,
    int? graduationYear,
    String? course,
  }) async {
    final raw = await _api.post('/api/auth/admin/users', body: {
      'email': email,
      'password': password,
      'fullName': fullName,
      'role': role.name,
      if (graduationYear != null) 'graduationYear': graduationYear,
      if (course != null) 'course': course,
    });
    final map = Map<String, dynamic>.from(raw['user']);
    return UserModel.fromJson(map, map['uid']?.toString() ?? '');
  }

  Future<void> adminResetPassword(String uid, String newPassword) {
    return _api.post('/api/auth/admin/users/$uid/reset-password',
        body: {'newPassword': newPassword});
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) {
    return _api.post('/api/auth/change-password', body: {
      'currentPassword': currentPassword,
      'newPassword': newPassword,
    });
  }
}

/// Lifecycle of a pre-registered Alumni ID.
enum AlumniAccountStatus {
  pending,
  active,
  disabled;

  String get label => switch (this) {
        pending => 'Pending',
        active => 'Active',
        disabled => 'Disabled',
      };

  static AlumniAccountStatus fromString(String? value) {
    for (final status in AlumniAccountStatus.values) {
      if (status.name == value) return status;
    }
    return pending;
  }
}

/// A pre-registered Alumni ID record created by an administrator. Alumni can
/// only create an account for an ID that exists here in Pending status.
class AlumniRegistryEntry {
  final String alumniId;
  final String fullName;
  final String course;

  /// Graduation batch as an academic-year pair, e.g. "2020-2021".
  final String? academicYearGraduated;

  /// Numeric graduation year (the second year of the batch pair, matching the
  /// year the alumnus actually graduates, e.g. 2021 for batch "2020-2021").
  final int? graduationYear;
  final AlumniAccountStatus status;
  final DateTime? activatedAt;

  const AlumniRegistryEntry({
    required this.alumniId,
    required this.fullName,
    this.course = AppStrings.defaultCourse,
    this.academicYearGraduated,
    this.graduationYear,
    this.status = AlumniAccountStatus.pending,
    this.activatedAt,
  });

  AlumniRegistryEntry copyWith({
    String? fullName,
    String? course,
    String? academicYearGraduated,
    int? graduationYear,
    AlumniAccountStatus? status,
    DateTime? activatedAt,
  }) {
    return AlumniRegistryEntry(
      alumniId: alumniId,
      fullName: fullName ?? this.fullName,
      course: course ?? this.course,
      academicYearGraduated:
          academicYearGraduated ?? this.academicYearGraduated,
      graduationYear: graduationYear ?? this.graduationYear,
      status: status ?? this.status,
      activatedAt: activatedAt ?? this.activatedAt,
    );
  }

  factory AlumniRegistryEntry.fromJson(Map<String, dynamic> map) {
    return AlumniRegistryEntry(
      alumniId: map['alumniId']?.toString() ?? '',
      fullName: map['fullName']?.toString() ?? '',
      course: map['course']?.toString().trim().isNotEmpty == true
          ? map['course']!.toString()
          : AppStrings.defaultCourse,
      academicYearGraduated: map['academicYearGraduated']?.toString(),
      graduationYear: (map['graduationYear'] as num?)?.toInt(),
      status: AlumniAccountStatus.fromString(map['status']?.toString()),
      activatedAt: parseApiDate(map['activatedAt']),
    );
  }

  Map<String, dynamic> toJson() => {
        'alumniId': alumniId,
        'fullName': fullName,
        'course': course,
        if (academicYearGraduated != null)
          'academicYearGraduated': academicYearGraduated,
        if (graduationYear != null) 'graduationYear': graduationYear,
        'status': status.name,
        if (activatedAt != null)
          'activatedAt': activatedAt!.toIso8601String(),
      };

  /// Backwards-compatible alias.
  Map<String, dynamic> toMap() => toJson();
}
