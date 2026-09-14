import '../models/notification_model.dart';
import 'api_client.dart';

class NotificationService {
  NotificationService({ApiClient? api}) : _api = api ?? ApiClient();

  final ApiClient _api;

  static const Duration pollInterval = Duration(seconds: 30);

  Stream<List<AppNotification>> watchNotifications(
    String userId, {
    bool includeRoleBroadcasts = false,
  }) {
    return _api.poll(
      () => fetchNotifications(userId,
          includeRoleBroadcasts: includeRoleBroadcasts),
      interval: pollInterval,
    );
  }

  Future<List<AppNotification>> fetchNotifications(
    String userId, {
    bool includeRoleBroadcasts = false,
  }) async {
    final raw = await _api.get('/api/notifications', query: {
      'includeRoleBroadcasts': includeRoleBroadcasts ? 'true' : 'false',
    });
    return (raw as List)
        .cast<Map<String, dynamic>>()
        .map((m) => AppNotification.fromJson(m, m['id']?.toString() ?? ''))
        .toList();
  }

  Future<int> getUnreadCount(
    String userId, {
    bool includeRoleBroadcasts = false,
  }) async {
    final raw = await _api.get('/api/notifications/unread-count', query: {
      'includeRoleBroadcasts': includeRoleBroadcasts ? 'true' : 'false',
    });
    return (raw['unread'] as num?)?.toInt() ?? 0;
  }

  Future<void> markAsRead(String notificationId) {
    return _api.patch('/api/notifications/$notificationId/read');
  }

  Future<void> markAllAsRead(
    String userId, {
    bool includeRoleBroadcasts = false,
  }) {
    return _api.patch('/api/notifications/read-all', query: {
      'includeRoleBroadcasts': includeRoleBroadcasts ? 'true' : 'false',
    });
  }

  Future<void> deleteNotification(String notificationId) {
    return _api.delete('/api/notifications/$notificationId');
  }

  Future<void> deleteMultiple(List<String> notificationIds) {
    if (notificationIds.isEmpty) return Future.value();
    return _api.delete('/api/notifications', body: {'ids': notificationIds});
  }

  Future<AppNotification> createNotification(
      AppNotification notification) async {
    final raw = await _api.post('/api/notifications',
        body: notification.toJson());
    final map = Map<String, dynamic>.from(raw);
    return AppNotification.fromJson(map, map['id']?.toString() ?? '');
  }

  /// Sends a bell alert to every alumni user — used when new public content
  /// (announcements, events, jobs) is published by staff.
  Future<int> notifyAllAlumni({
    required NotificationType type,
    required String title,
    String description = '',
    NotificationPriority priority = NotificationPriority.medium,
    String? link,
  }) async {
    final raw = await _api.post('/api/notifications/broadcast', body: {
      'type': type.name,
      'title': title,
      'description': description,
      'priority': priority.name,
      if (link != null) 'link': link,
    });
    return (raw['sent'] as num?)?.toInt() ?? 0;
  }

  Future<AppNotification?> getNotification(String id) async {
    try {
      final list = await fetchNotifications('', includeRoleBroadcasts: true);
      for (final n in list) {
        if (n.id == id) return n;
      }
      return null;
    } on ApiException {
      return null;
    }
  }
}
