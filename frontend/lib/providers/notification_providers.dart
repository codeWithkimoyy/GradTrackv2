import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/notification_model.dart';
import '../services/notification_service.dart';
import 'auth_providers.dart';
import 'role_providers.dart';

final notificationServiceProvider = Provider<NotificationService>(
    (ref) => NotificationService(api: ref.watch(apiClientProvider)));

final notificationsProvider =
    StreamProvider.family<List<AppNotification>, String>((ref, userId) {
  final isAdmin = ref.watch(isAdminProvider);
  return ref.read(notificationServiceProvider).watchNotifications(
        userId,
        includeRoleBroadcasts: isAdmin,
      );
});

final unreadCountProvider = Provider.family<int, String>((ref, userId) {
  final notifications = ref.watch(notificationsProvider(userId));
  return notifications.valueOrNull?.where((n) => !n.isRead).length ?? 0;
});

final filteredNotificationsProvider =
    Provider.family<List<AppNotification>, NotificationFilter>((ref, filter) {
  final notifications = ref.watch(notificationsProvider(filter.userId));
  final all = notifications.valueOrNull ?? [];
  return all.where((n) {
    if (filter.type != null && n.type != filter.type) return false;
    if (filter.readFilter == ReadFilter.unread && n.isRead) return false;
    if (filter.readFilter == ReadFilter.read && !n.isRead) return false;
    if (filter.query != null && filter.query!.isNotEmpty) {
      final q = filter.query!.toLowerCase();
      if (!n.title.toLowerCase().contains(q) &&
          !n.description.toLowerCase().contains(q)) {
        return false;
      }
    }
    return true;
  }).toList();
});

class NotificationFilter {
  final String userId;
  final NotificationType? type;
  final ReadFilter readFilter;
  final String? query;

  const NotificationFilter({
    required this.userId,
    this.type,
    this.readFilter = ReadFilter.all,
    this.query,
  });
}

enum ReadFilter { all, read, unread }
