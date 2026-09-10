import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../constants/app_constants.dart';
import '../models/user_model.dart';

/// Central user profile repository for clean Firestore access.
class UserRepository {
  final FirebaseFirestore? _firestore;

  UserRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ??
            (Firebase.apps.isNotEmpty ? FirebaseFirestore.instance : null);

  CollectionReference<Map<String, dynamic>>? get _users =>
      _firestore?.collection(FirestoreCollections.users);

  Stream<UserModel?> watchUser(String uid) {
    final collection = _users;
    if (collection == null) return Stream<UserModel?>.value(null);
    return collection.doc(uid).snapshots().map((snapshot) {
      if (!snapshot.exists) return null;
      return UserModel.fromDoc(snapshot);
    });
  }

  Future<UserModel?> fetchUser(String uid) async {
    final collection = _users;
    if (collection == null) return null;
    final doc = await collection.doc(uid).get();
    return doc.exists ? UserModel.fromDoc(doc) : null;
  }

  Future<void> saveUser(UserModel user, {bool merge = true}) async {
    final collection = _users;
    if (collection == null) return;
    await collection.doc(user.uid).set(user.toMap(), SetOptions(merge: merge));
  }

  Future<void> updateUser(String uid, Map<String, dynamic> changes) async {
    final collection = _users;
    if (collection == null) return;
    await collection.doc(uid).update(changes);
  }

  Future<bool> userExists(String uid) async {
    final collection = _users;
    if (collection == null) return false;
    final doc = await collection.doc(uid).get();
    return doc.exists;
  }

  CollectionReference<Map<String, dynamic>>? get _registry =>
      _firestore?.collection(FirestoreCollections.alumniRegistry);

  /// Returns the office pre-registered record for an Alumni ID, or null when
  /// the ID was never added by an administrator.
  Future<AlumniRegistryEntry?> fetchRegistryEntry(String alumniId) async {
    final collection = _registry;
    if (collection == null) return null;
    final doc = await collection.doc(alumniId).get();
    return doc.exists ? AlumniRegistryEntry.fromMap(doc.data() ?? {}) : null;
  }

  Future<void> saveRegistryEntry(AlumniRegistryEntry entry) async {
    final collection = _registry;
    if (collection == null) return;
    await collection.doc(entry.alumniId).set(entry.toMap());
  }

  Future<void> removeRegistryEntry(String alumniId) async {
    final collection = _registry;
    if (collection == null) return;
    await collection.doc(alumniId).delete();
  }

  /// Transitions an ID's status (used when an alumni activates their account:
  /// Pending → Active). Other transitions are admin-only.
  Future<void> updateRegistryStatus(
    String alumniId,
    AlumniAccountStatus status, {
    DateTime? activatedAt,
  }) async {
    final collection = _registry;
    if (collection == null) return;
    await collection.doc(alumniId).update({
      'status': status.name,
      if (activatedAt != null) 'activatedAt': activatedAt,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Live stream of registry records for the admin Alumni Management module.
  Stream<List<AlumniRegistryEntry>> watchRegistry() {
    final collection = _registry;
    if (collection == null) return Stream.value(const []);
    return collection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AlumniRegistryEntry.fromMap(doc.data()))
            .toList());
  }

  /// Finds the user document linked to an Alumni ID (e.g. to disable it).
  Future<DocumentReference<Map<String, dynamic>>?>
      findUserByAlumniId(String alumniId) async {
    final collection = _users;
    if (collection == null) return null;
    final snapshot = await collection
        .where('alumniId', isEqualTo: alumniId)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) return null;
    return snapshot.docs.first.reference;
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
  final int? graduationYear;
  final AlumniAccountStatus status;
  final DateTime? activatedAt;

  const AlumniRegistryEntry({
    required this.alumniId,
    required this.fullName,
    this.course = AppStrings.defaultCourse,
    this.graduationYear,
    this.status = AlumniAccountStatus.pending,
    this.activatedAt,
  });

  AlumniRegistryEntry copyWith({
    String? fullName,
    String? course,
    int? graduationYear,
    AlumniAccountStatus? status,
    DateTime? activatedAt,
  }) {
    return AlumniRegistryEntry(
      alumniId: alumniId,
      fullName: fullName ?? this.fullName,
      course: course ?? this.course,
      graduationYear: graduationYear ?? this.graduationYear,
      status: status ?? this.status,
      activatedAt: activatedAt ?? this.activatedAt,
    );
  }

  factory AlumniRegistryEntry.fromMap(Map<String, dynamic> map) {
    return AlumniRegistryEntry(
      alumniId: map['alumniId']?.toString() ?? '',
      fullName: map['fullName']?.toString() ?? '',
      course: map['course']?.toString().trim().isNotEmpty == true
          ? map['course']!.toString()
          : AppStrings.defaultCourse,
      graduationYear: (map['graduationYear'] as num?)?.toInt(),
      status: AlumniAccountStatus.fromString(map['status']?.toString()),
      activatedAt: (map['activatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'alumniId': alumniId,
        'fullName': fullName,
        'course': course,
        if (graduationYear != null) 'graduationYear': graduationYear,
        'status': status.name,
        if (activatedAt != null) 'activatedAt': activatedAt,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
}
