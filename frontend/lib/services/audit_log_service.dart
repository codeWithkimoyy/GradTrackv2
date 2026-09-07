import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/app_constants.dart';

/// Append-only trail of administrative/security actions. Only admins may read
/// these records and only staff (admin/coordinator) may write them (enforced
/// by the Firestore rules); entries are never updated or deleted.
///
/// The `title`/`description` fields double as the primary activity summary so
/// entries remain human-readable, alongside structured metadata (actor,
/// action, target) for filtering and review.
class AuditLogService {
  AuditLogService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<void> log({
    required String action,
    required String title,
    required String description,
    String? actorId,
    String? actorName,
    String? actorRole,
    String? targetId,
    String? targetType,
  }) async {
    await _firestore.collection(FirestoreCollections.auditLogs).add({
      'action': action,
      'title': title,
      'description': description,
      if (actorId != null) 'actorId': actorId,
      if (actorName != null) 'actorName': actorName,
      if (actorRole != null) 'actorRole': actorRole,
      if (targetId != null) 'targetId': targetId,
      if (targetType != null) 'targetType': targetType,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}