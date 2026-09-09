import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/app_constants.dart';
import '../services/audit_log_service.dart';
import 'auth_providers.dart';

final auditLogServiceProvider =
    Provider<AuditLogService>((ref) => AuditLogService());

/// Newest-first stream of audit entries for the admin Audit Logs screen.
final auditLogsProvider =
    StreamProvider.autoDispose<QuerySnapshot<Map<String, dynamic>>>((ref) {
  return FirebaseFirestore.instance
      .collection(FirestoreCollections.auditLogs)
      .orderBy('createdAt', descending: true)
      .snapshots();
});

/// Records a staff/security action to the append-only audit trail. Resolves
/// the acting user from the signed-in profile and swallows errors so audit
/// logging never breaks (or blocks) the action it is describing.
Future<void> logAudit(
  WidgetRef ref, {
  required String action,
  required String title,
  required String description,
  String? targetId,
  String? targetType,
}) async {
  final actor = ref.read(currentUserProfileProvider).valueOrNull;
  try {
    await ref.read(auditLogServiceProvider).log(
          action: action,
          title: title,
          description: description,
          actorId: actor?.uid,
          actorName: actor?.fullName,
          actorRole: actor?.role.name,
          targetId: targetId,
          targetType: targetType,
        );
  } catch (_) {
    // Intentionally ignored: audit logging is best-effort.
  }
}