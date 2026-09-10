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
        .snapshots()
        .map((snap) {
          final list = snap.docs.map(EmploymentRecord.fromDoc).toList();
          list.sort((a, b) => b.dateHired.compareTo(a.dateHired));
          return list;
        });
  }

  Stream<List<CareerMilestone>> watchMilestones(String userId) {
    return _milestones
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snap) {
          final list = snap.docs.map(CareerMilestone.fromDoc).toList();
          list.sort((a, b) => b.date.compareTo(a.date));
          return list;
        });
  }

  Future<void> addRecord(EmploymentRecord record) async {
    final docRef = _records.doc();
    // 1. Primary write: Save the employment record document
    await docRef.set(record.toMap()).timeout(const Duration(seconds: 15));

    // 2. Secondary syncs: Unset previous current jobs, update profile status & milestone
    if (record.isCurrent) {
      try {
        final existingCurrent = await _records
            .where('userId', isEqualTo: record.userId)
            .get()
            .timeout(const Duration(seconds: 10));
        final batch = _firestore.batch();
        bool hasBatchUpdates = false;
        for (final doc in existingCurrent.docs) {
          if (doc.id != docRef.id && doc.data()['isCurrent'] == true) {
            batch.update(doc.reference, {'isCurrent': false});
            hasBatchUpdates = true;
          }
        }
        if (hasBatchUpdates) {
          await batch.commit().timeout(const Duration(seconds: 10));
        }
      } catch (_) {}

      try {
        await _users.doc(record.userId).set(
          {'employmentStatus': EmploymentStatus.employed.name},
          SetOptions(merge: true),
        ).timeout(const Duration(seconds: 10));
      } catch (_) {}

      try {
        final milestoneSnap = await _milestones
            .where('userId', isEqualTo: record.userId)
            .limit(1)
            .get()
            .timeout(const Duration(seconds: 10));
        if (milestoneSnap.docs.isEmpty) {
          final milestoneRef = _milestones.doc();
          await milestoneRef.set(
            CareerMilestone(
              id: milestoneRef.id,
              userId: record.userId,
              type: MilestoneType.firstJob,
              title: 'Started at ${record.company}',
              description: record.position,
              date: record.dateHired,
            ).toMap(),
          ).timeout(const Duration(seconds: 10));
        }
      } catch (_) {}
    }
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
