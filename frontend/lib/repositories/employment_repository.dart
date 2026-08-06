import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/app_constants.dart';
import '../models/employment_model.dart';
import '../models/user_model.dart';

/// Encapsulates all Firestore reads/writes for employment records and
/// career milestones. Screens/providers should go through this rather
/// than touching FirebaseFirestore directly.
class EmploymentRepository {
  final FirebaseFirestore _firestore;

  EmploymentRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _records =>
      _firestore.collection(FirestoreCollections.employment);

  CollectionReference<Map<String, dynamic>> get _milestones =>
      _firestore.collection(FirestoreCollections.careerMilestones);

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection(FirestoreCollections.users);

  /// Live stream of a user's employment records, most recent first.
  Stream<List<EmploymentRecord>> watchRecords(String userId) {
    return _records
        .where('userId', isEqualTo: userId)
        .orderBy('dateHired', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(EmploymentRecord.fromDoc).toList());
  }

  Stream<List<CareerMilestone>> watchMilestones(String userId) {
    return _milestones
        .where('userId', isEqualTo: userId)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(CareerMilestone.fromDoc).toList());
  }

  Future<void> addRecord(EmploymentRecord record) async {
    final batch = _firestore.batch();
    final docRef = _records.doc();
    batch.set(docRef, record.toMap());

    // If this is the current job, unset isCurrent on any previous ones
    // and update the user's employmentStatus field so dashboards stay in sync.
    if (record.isCurrent) {
      final existingCurrent = await _records
          .where('userId', isEqualTo: record.userId)
          .where('isCurrent', isEqualTo: true)
          .get()
          .timeout(const Duration(seconds: 10));
      for (final doc in existingCurrent.docs) {
        batch.update(doc.reference, {'isCurrent': false});
      }
      batch.set(
        _users.doc(record.userId),
        {'employmentStatus': EmploymentStatus.employed.name},
        SetOptions(merge: true),
      );

      // Auto-log a "first job" milestone if the user has no milestones yet.
      final milestoneSnap = await _milestones
          .where('userId', isEqualTo: record.userId)
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 10));
      if (milestoneSnap.docs.isEmpty) {
        final milestoneRef = _milestones.doc();
        batch.set(
          milestoneRef,
          CareerMilestone(
            id: milestoneRef.id,
            userId: record.userId,
            type: MilestoneType.firstJob,
            title: 'Started at ${record.company}',
            description: record.position,
            date: record.dateHired,
          ).toMap(),
        );
      }
    }

    await batch.commit().timeout(const Duration(seconds: 15));
  }

  Future<void> updateRecord(String recordId, Map<String, dynamic> changes) {
    return _records
        .doc(recordId)
        .update(changes)
        .timeout(const Duration(seconds: 10));
  }

  Future<void> deleteRecord(String recordId) {
    return _records.doc(recordId).delete().timeout(const Duration(seconds: 10));
  }

  Future<void> addMilestone(CareerMilestone milestone) {
    final ref = milestone.id.isEmpty
        ? _milestones.doc()
        : _milestones.doc(milestone.id);
    return ref.set(milestone.toMap()).timeout(const Duration(seconds: 10));
  }

  Future<void> deleteMilestone(String id) {
    return _milestones.doc(id).delete().timeout(const Duration(seconds: 10));
  }

  Future<void> setEmploymentStatus(String userId, EmploymentStatus status) {
    return _users.doc(userId).set(
      {'employmentStatus': status.name},
      SetOptions(merge: true),
    ).timeout(const Duration(seconds: 10));
  }
}
