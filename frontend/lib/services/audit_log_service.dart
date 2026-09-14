import 'api_client.dart';

/// Append-only trail of administrative/security actions. Only admins may read
/// these records and only admins may write them (enforced by the backend);
/// entries are never updated or deleted.
///
/// The `title`/`description` fields double as the primary activity summary so
/// entries remain human-readable, alongside structured metadata (actor,
/// action, target) for filtering and review.
class AuditLogService {
  AuditLogService({ApiClient? api}) : _api = api ?? ApiClient();

  final ApiClient _api;

  static const Duration pollInterval = Duration(seconds: 30);

  Future<void> log({
    required String action,
    required String title,
    required String description,
    String? actorId,
    String? actorName,
    String? actorRole,
    String? targetId,
    String? targetType,
    Map<String, dynamic>? details,
  }) async {
    await _api.post('/api/audit-logs', body: {
      'action': action,
      'title': title,
      'description': description,
      if (actorId != null) 'actorId': actorId,
      if (actorName != null) 'actorName': actorName,
      if (actorRole != null) 'actorRole': actorRole,
      if (targetId != null) 'targetId': targetId,
      if (targetType != null) 'targetType': targetType,
      if (details != null) 'details': details,
    });
  }

  Stream<List<Map<String, dynamic>>> watchLogs({int limit = 200}) {
    return _api.poll(() => fetchLogs(limit: limit),
        interval: pollInterval);
  }

  Future<List<Map<String, dynamic>>> fetchLogs({int limit = 200}) async {
    final raw =
        await _api.get('/api/audit-logs', query: {'limit': '$limit'});
    return (raw as List).cast<Map<String, dynamic>>();
  }
}
