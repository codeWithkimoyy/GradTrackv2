import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/app_constants.dart';
import '../providers/notification_providers.dart';
import '../routes/app_router.dart';

/// Bell icon with an unread badge. Tapping it opens the full-screen
/// notification center instead of a pop-up panel/modal dialog, so the same
/// layout on every screen size.
class NotificationBell extends ConsumerWidget {
  final String userId;
  final bool isAdmin;

  const NotificationBell({
    super.key,
    required this.userId,
    this.isAdmin = false,
  });

  @override
<<<<<<< HEAD
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
    if (widget.isAdmin) {
      _openModal();
      return;
    }
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

  void _openModal() {
    final bellContext = context;
    _isOpen = true;
    Navigator.of(context)
        .push(
      MaterialPageRoute<void>(
        builder: (_) => _AdminNotificationsFullScreen(
          userId: widget.userId,
          onOpenLink: (link) {
            if (link != null && link.isNotEmpty) bellContext.go(link);
          },
        ),
      ),
    )
        .whenComplete(() => _isOpen = false);
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
=======
>>>>>>> 7bc5174b2ee3a5144e46557288b8ceade5dcff3e
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCount = ref.watch(unreadCountProvider(userId));

    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: const Icon(Icons.notifications_outlined),
          onPressed: () => context.go(AppRoutes.alumniNotifications),
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
                    constraints:
                        const BoxConstraints(minWidth: 18, minHeight: 18),
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
<<<<<<< HEAD
        ),
      ),
    );
  }
}

class _AdminNotificationsFullScreen extends ConsumerStatefulWidget {
  final String userId;
  final ValueChanged<String?> onOpenLink;

  const _AdminNotificationsFullScreen({
    required this.userId,
    required this.onOpenLink,
  });

  @override
  ConsumerState<_AdminNotificationsFullScreen> createState() =>
      _AdminNotificationsFullScreenState();
}

class _AdminNotificationsFullScreenState
    extends ConsumerState<_AdminNotificationsFullScreen> {
  NotificationType? _typeFilter;
  String _readFilter = 'all';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Notifications',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        centerTitle: false,
      ),
      body: _NotificationPanelBody(
        userId: widget.userId,
        typeFilter: _typeFilter,
        readFilter: _readFilter,
        searchQuery: _searchController.text,
        onTypeFilterChanged: (t) => setState(() => _typeFilter = t),
        onReadFilterChanged: (r) => setState(() => _readFilter = r),
        searchController: _searchController,
        onClose: () => Navigator.of(context).pop(),
        onTapNotification: (link) {
          Navigator.of(context).pop();
          widget.onOpenLink(link);
        },
      ),
    );
  }
}

class _NotificationModal extends ConsumerWidget {
  final String userId;
  final NotificationType? typeFilter;
  final String readFilter;
  final String searchQuery;
  final ValueChanged<NotificationType?> onTypeFilterChanged;
  final ValueChanged<String> onReadFilterChanged;
  final TextEditingController searchController;
  final ValueChanged<String?> onOpenLink;

  const _NotificationModal({
    required this.userId,
    required this.typeFilter,
    required this.readFilter,
    required this.searchQuery,
    required this.onTypeFilterChanged,
    required this.onReadFilterChanged,
    required this.searchController,
    required this.onOpenLink,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 56),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      clipBehavior: Clip.antiAlias,
      backgroundColor: Theme.of(context).colorScheme.surface,
      surfaceTintColor: Theme.of(context).colorScheme.surfaceTint,
      child: Container(
        width: 520,
        height: 620,
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
          ),
        ),
        child: _NotificationPanelBody(
          userId: userId,
          typeFilter: typeFilter,
          readFilter: readFilter,
          searchQuery: searchQuery,
          onTypeFilterChanged: onTypeFilterChanged,
          onReadFilterChanged: onReadFilterChanged,
          searchController: searchController,
          onClose: () => Navigator.of(context).pop(),
          onTapNotification: (link) {
            Navigator.of(context).pop();
            onOpenLink(link);
          },
        ),
      ),
    );
  }
}

class _NotificationPanelBody extends ConsumerWidget {
  final String userId;
  final NotificationType? typeFilter;
  final String readFilter;
  final String searchQuery;
  final ValueChanged<NotificationType?> onTypeFilterChanged;
  final ValueChanged<String> onReadFilterChanged;
  final TextEditingController searchController;
  final VoidCallback onClose;
  final ValueChanged<String?> onTapNotification;

  const _NotificationPanelBody({
    required this.userId,
    required this.typeFilter,
    required this.readFilter,
    required this.searchQuery,
    required this.onTypeFilterChanged,
    required this.onReadFilterChanged,
    required this.searchController,
    required this.onClose,
    required this.onTapNotification,
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

    return Column(
      children: [
        _buildHeader(context, ref),
        _buildFilters(context),
        _buildActionBar(context, ref),
        Expanded(child: _buildList(context, ref, notifications)),
=======
>>>>>>> 7bc5174b2ee3a5144e46557288b8ceade5dcff3e
      ],
    );
  }
}