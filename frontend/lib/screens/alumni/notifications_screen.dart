import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../constants/app_constants.dart';
import '../../models/notification_model.dart';
import '../../providers/auth_providers.dart';
import '../../providers/notification_providers.dart';

/// Alumni notification center: live list, mark single/all as read, delete.
/// Only the signed-in user's own notifications are ever read or modified.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProfileProvider).valueOrNull;
    if (user == null) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator()));
    }

    final notificationsAsync = ref.watch(notificationsProvider(user.uid));
    final service = ref.read(notificationServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            tooltip: 'Mark all as read',
            icon: const Icon(Icons.done_all_rounded),
            onPressed: notificationsAsync.valueOrNull?.isEmpty ?? true
                ? null
                : () async {
                    await service.markAllAsRead(user.uid);
                  },
          ),
        ],
      ),
      body: notificationsAsync.when(
        data: (notifications) {
          if (notifications.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.notifications_none_rounded,
                        size: 64, color: AppColors.primaryBlue),
                    SizedBox(height: 14),
                    Text('You have no notifications yet.'),
                    SizedBox(height: 6),
                    Text(
                      'Updates about surveys, events and your profile will appear here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            );
          }

          final unread =
              notifications.where((n) => !n.isRead).length;

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              Text('$unread unread of ${notifications.length} total',
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: AppSpacing.sm),
              ...notifications.map((n) => _NotificationCard(
                    notification: n,
                    onRead: n.isRead
                        ? null
                        : () async {
                            await service.markAsRead(n.id);
                          },
                    onDelete: () async {
                      await service.deleteNotification(n.id);
                    },
                  )),
            ],
          );
        },
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text('Could not load notifications.\n\n$e',
                textAlign: TextAlign.center),
          ),
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback? onRead;
  final VoidCallback onDelete;

  const _NotificationCard({
    required this.notification,
    required this.onRead,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ListTile(
        onTap: onRead,
        leading: CircleAvatar(
          backgroundColor: notification.priority.color.withValues(alpha: .22),
          child: Icon(notification.type.icon,
              size: 21,
              color: notification.priority.color),
        ),
        title: Text(
          notification.title,
          style: TextStyle(
            fontWeight: notification.isRead
                ? FontWeight.w500
                : FontWeight.w700,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (notification.description.isNotEmpty)
              Text(
                notification.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            const SizedBox(height: 2),
            Text(
              timeago.format(notification.createdAt),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey,
                    fontSize: 11,
                  ),
            ),
          ],
        ),
        trailing: IconButton(
          tooltip: 'Delete',
          icon: const Icon(Icons.delete_outline_rounded,
              color: AppColors.error),
          onPressed: onDelete,
        ),
      ),
    );
  }
}