import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../constants/app_constants.dart';
import '../models/notification_model.dart';
import '../providers/notification_providers.dart';
import '../utils/app_snack_bar.dart';

class NotificationBell extends ConsumerStatefulWidget {
  final String userId;

  const NotificationBell({super.key, required this.userId});

  @override
  ConsumerState<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends ConsumerState<NotificationBell> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  bool _isOpen = false;

  NotificationType? _typeFilter;
  String _readFilter = 'all';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    _closePanel();
    super.dispose();
  }

  void _togglePanel() {
    if (_isOpen) {
      _closePanel();
    } else {
      _openPanel();
    }
  }

  void _openPanel() {
    _overlayEntry = OverlayEntry(
      builder: (context) => _NotificationPanel(
        userId: widget.userId,
        layerLink: _layerLink,
        onClose: _closePanel,
        typeFilter: _typeFilter,
        readFilter: _readFilter,
        searchQuery: _searchController.text,
        onTypeFilterChanged: (t) => setState(() => _typeFilter = t),
        onReadFilterChanged: (r) => setState(() => _readFilter = r),
        searchController: _searchController,
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
    _isOpen = true;
  }

  void _closePanel() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _isOpen = false;
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = ref.watch(unreadCountProvider(widget.userId));

    return CompositedTransformTarget(
      link: _layerLink,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: _togglePanel,
            tooltip: 'Notifications',
          ),
          if (unreadCount > 0)
            Positioned(
              right: 4,
              top: 4,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.8, end: 1),
                duration: const Duration(milliseconds: 300),
                curve: Curves.elasticOut,
                builder: (context, scale, _) {
                  return Transform.scale(
                    scale: scale,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AppColors.error,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                      child: Text(
                        unreadCount > 99 ? '99+' : unreadCount.toString(),
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _NotificationPanel extends ConsumerWidget {
  final String userId;
  final LayerLink layerLink;
  final VoidCallback onClose;
  final NotificationType? typeFilter;
  final String readFilter;
  final String searchQuery;
  final ValueChanged<NotificationType?> onTypeFilterChanged;
  final ValueChanged<String> onReadFilterChanged;
  final TextEditingController searchController;

  const _NotificationPanel({
    required this.userId,
    required this.layerLink,
    required this.onClose,
    required this.typeFilter,
    required this.readFilter,
    required this.searchQuery,
    required this.onTypeFilterChanged,
    required this.onReadFilterChanged,
    required this.searchController,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = NotificationFilter(
      userId: userId,
      type: typeFilter,
      readFilter: readFilter == 'all'
          ? ReadFilter.all
          : readFilter == 'unread'
              ? ReadFilter.unread
              : ReadFilter.read,
      query: searchQuery.isNotEmpty ? searchQuery : null,
    );
    final notifications = ref.watch(filteredNotificationsProvider(filter));

    return GestureDetector(
      onTap: () {},
      child: CompositedTransformFollower(
        link: layerLink,
        offset: const Offset(-320, 8),
        targetAnchor: Alignment.topRight,
        followerAnchor: Alignment.topRight,
        child: Material(
          elevation: 16,
          borderRadius: BorderRadius.circular(16),
          color: Theme.of(context).colorScheme.surface,
          surfaceTintColor: Theme.of(context).colorScheme.surfaceTint,
          child: Container(
            width: 380,
            height: 520,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Theme.of(context)
                    .dividerColor
                    .withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              children: [
                _buildHeader(context, ref),
                _buildFilters(context),
                _buildActionBar(context, ref),
                Expanded(child: _buildList(context, ref, notifications)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: Row(
        children: [
          Text(
            'Notifications',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: onClose,
          ),
        ],
      ),
    );
  }

  Widget _buildFilters(BuildContext context) {
    final types = <NotificationType?>[null, ...NotificationType.values];
    final typeLabels = <String?>[
      'All',
      ...NotificationType.values.map((e) => e.label),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SizedBox(
        height: 32,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: types.length,
          separatorBuilder: (_, __) => const SizedBox(width: 6),
          itemBuilder: (context, i) {
            final isSelected = typeFilter == types[i];
            return FilterChip(
              label: Text(
                typeLabels[i]!,
                style: GoogleFonts.poppins(fontSize: 12),
              ),
              selected: isSelected,
              onSelected: (_) {
                onTypeFilterChanged(types[i]);
              },
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            );
          },
        ),
      ),
    );
  }

  Widget _buildActionBar(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: readFilter,
                isDense: true,
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All', style: TextStyle(fontSize: 12))),
                  DropdownMenuItem(value: 'unread', child: Text('Unread', style: TextStyle(fontSize: 12))),
                  DropdownMenuItem(value: 'read', child: Text('Read', style: TextStyle(fontSize: 12))),
                ],
                onChanged: (v) {
                  if (v != null) onReadFilterChanged(v);
                },
              ),
            ),
          ),
          const Spacer(),
          SizedBox(
            height: 28,
            child: TextButton(
              onPressed: () {
                ref.read(notificationServiceProvider).markAllAsRead(userId);
                showSuccess(context, 'All notifications marked as read');
              },
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                visualDensity: VisualDensity.compact,
              ),
              child: Text(
                'Mark all read',
                style: GoogleFonts.poppins(fontSize: 11),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(
      BuildContext context, WidgetRef ref, List<AppNotification> notifications) {
    if (notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.notifications_off_outlined,
              size: 48,
              color: Theme.of(context).disabledColor,
            ),
            const SizedBox(height: 8),
            Text(
              'No notifications',
              style: GoogleFonts.poppins(
                color: Theme.of(context).disabledColor,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: notifications.length,
      separatorBuilder: (_, __) => Divider(
        height: 1,
        indent: 16,
        endIndent: 16,
        color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
      ),
      itemBuilder: (context, i) {
        final n = notifications[i];
        return _NotificationItem(
          notification: n,
          onTap: () {
            if (!n.isRead) {
              ref.read(notificationServiceProvider).markAsRead(n.id);
            }
            onClose();
          },
          onDelete: () {
            ref.read(notificationServiceProvider).deleteNotification(n.id);
          },
        );
      },
    );
  }
}

class _NotificationItem extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _NotificationItem({
    required this.notification,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: notification.isRead
            ? Colors.transparent
            : theme.colorScheme.primaryContainer.withValues(alpha: 0.25),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: notification.priority.color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                notification.type.icon,
                size: 18,
                color: notification.priority.color,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    notification.title,
                    style: GoogleFonts.poppins(
                      fontWeight:
                          notification.isRead ? FontWeight.w500 : FontWeight.w600,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    notification.description,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    timeago.format(notification.createdAt),
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(
                Icons.close,
                size: 16,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
              ),
              onPressed: onDelete,
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            ),
          ],
        ),
      ),
    );
  }
}
