import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../constants/app_constants.dart';
import '../../models/notification_model.dart';
import '../../models/user_model.dart';
import '../../providers/role_providers.dart';
import '../../routes/app_router.dart';
import '../../utils/app_snack_bar.dart';

enum ContentFieldType { text, longText, date, choice }

class ContentField {
  final String name;
  final String label;
  final ContentFieldType type;
  final List<String> options;

  const ContentField(this.name, this.label,
      {this.type = ContentFieldType.text, this.options = const []});
}

class ContentCollection {
  final String collection;
  final String title;
  final IconData icon;
  final List<ContentField> fields;
  final bool guestPublicOnly;
  final bool canAdd;

  const ContentCollection({
    required this.collection,
    required this.title,
    required this.icon,
    required this.fields,
    this.guestPublicOnly = true,
    this.canAdd = true,
  });
}

/// Registry of the content collections offered by the app. Keys are the
/// route segment used for `/staff/data/:collection`.
final Map<String, ContentCollection> contentCollections = {
  'announcements': const ContentCollection(
    collection: FirestoreCollections.announcements,
    title: 'Announcements',
    icon: Icons.campaign_outlined,
    fields: [
      ContentField('title', 'Title'),
      ContentField('description', 'Description', type: ContentFieldType.longText),
      ContentField('visibility', 'Visibility', type: ContentFieldType.choice, options: ['public', 'private']),
    ],
  ),
  'events': const ContentCollection(
    collection: FirestoreCollections.events,
    title: 'Events',
    icon: Icons.event_outlined,
    fields: [
      ContentField('title', 'Title'),
      ContentField('description', 'Description', type: ContentFieldType.longText),
      ContentField('date', 'Date', type: ContentFieldType.date),
      ContentField('location', 'Location'),
      ContentField('visibility', 'Visibility', type: ContentFieldType.choice, options: ['public', 'private']),
    ],
  ),
  'jobs': const ContentCollection(
    collection: FirestoreCollections.jobs,
    title: 'Job Opportunities',
    icon: Icons.business_center_outlined,
    fields: [
      ContentField('title', 'Position'),
      ContentField('company', 'Company'),
      ContentField('description', 'Description', type: ContentFieldType.longText),
      ContentField('visibility', 'Visibility', type: ContentFieldType.choice, options: ['public', 'private']),
    ],
  ),
  'surveys': const ContentCollection(
    collection: FirestoreCollections.surveys,
    title: 'Surveys',
    icon: Icons.fact_check_outlined,
    fields: [
      ContentField('title', 'Title'),
      ContentField('description', 'Description', type: ContentFieldType.longText),
      ContentField('visibility', 'Visibility', type: ContentFieldType.choice, options: ['public', 'private']),
    ],
  ),
  'reports': const ContentCollection(
    collection: 'reports',
    title: 'Reports',
    icon: Icons.assessment_outlined,
    fields: [
      ContentField('title', 'Title'),
      ContentField('description', 'Description', type: ContentFieldType.longText),
    ],
  ),
  'audit_logs': const ContentCollection(
    collection: FirestoreCollections.auditLogs,
    title: 'Audit Logs',
    icon: Icons.history_rounded,
    canAdd: false,
    fields: [
      ContentField('title', 'Activity'),
      ContentField('description', 'Details', type: ContentFieldType.longText),
    ],
  ),
  'system_settings': const ContentCollection(
    collection: 'system_settings',
    title: 'System Settings',
    icon: Icons.settings_outlined,
    fields: [
      ContentField('name', 'Name'),
      ContentField('value', 'Value'),
    ],
  ),
};

/// Resolves a `/staff/data/:collection` route segment to its definition.
ContentCollection? lookupCollection(String key) =>
    contentCollections[key];

/// Live Riverpod snapshot of a collection's docs. Guests and unknown roles
/// are limited to `visibility == 'public'` records, staff see everything.
final collectionContentsProvider = StreamProvider.autoDispose
    .family<QuerySnapshot<Map<String, dynamic>>, ContentCollection>(
        (ref, content) {
  final role = ref.watch(currentUserRoleProvider);
  final publicOnly = role == null || role.name == 'guest';
  Query<Map<String, dynamic>> query =
      FirebaseFirestore.instance.collection(content.collection);
  if (publicOnly) {
    query = query.where('visibility', isEqualTo: 'public');
  }
  return query.snapshots();
});

/// Live, role-aware list + CRUD screen for a Firestore collection.
/// Staff (admin/coordinator) can add, edit and delete records; alumni and
/// guests can only browse. Guests only ever see public records.
class CollectionListScreen extends ConsumerStatefulWidget {
  final ContentCollection content;

  const CollectionListScreen({super.key, required this.content});

  @override
  ConsumerState<CollectionListScreen> createState() =>
      _CollectionListScreenState();
}

class _CollectionListScreenState extends ConsumerState<CollectionListScreen> {
  String _query = '';

  bool get _publicOnly {
    final role = ref.watch(currentUserRoleProvider);
    return role == null || role.name == 'guest';
  }

  Future<void> _openEditor([DocumentSnapshot<Map<String, dynamic>>? doc]) async {
    final canEdit = await showDialog<bool>(
      context: context,
      builder: (_) => _ContentEditorDialog(
        content: widget.content,
        existing: doc,
      ),
    );
    if (!mounted || canEdit == null || !canEdit) return;
  }

  Future<void> _delete(DocumentSnapshot<Map<String, dynamic>> doc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete record?'),
        content: Text(
            'This "${widget.content.title}" record will be permanently removed from Firebase.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    try {
      await doc.reference.delete();
      if (mounted) {
        showAppSnackBar(context, 'Deleted successfully.',
            backgroundColor: AppColors.success);
      }
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, 'Delete failed: $e',
            backgroundColor: AppColors.error);
      }
    }
  }

  Widget _buildListError(Object error) {
    final isPermission = error.toString().toLowerCase().contains('permission');
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isPermission ? Icons.lock_outline : Icons.cloud_off_rounded,
              size: 56,
              color: isPermission ? AppColors.error : AppColors.warning,
            ),
            const SizedBox(height: 12),
            Text(
              isPermission
                  ? 'You do not have permission to view this content.'
                  : 'This content could not be loaded right now.',
              textAlign: TextAlign.center,
            ),
            if (!isPermission) ...[
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: () =>
                    ref.invalidate(collectionContentsProvider(widget.content)),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isStaff = ref.watch(isStaffProvider);
    final publicOnly = _publicOnly;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.content.title),
        actions: [
          if (!publicOnly && widget.content.canAdd)
            IconButton(
              tooltip: 'Add ${widget.content.title}',
              icon: const Icon(Icons.add_rounded),
              onPressed: () => _openEditor(),
            ),
        ],
      ),
      floatingActionButton: isStaff && !publicOnly
          ? FloatingActionButton.extended(
              onPressed: () => _openEditor(),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add'),
            )
          : null,
      body: ref.watch(collectionContentsProvider(widget.content)).when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _buildListError(e),
        data: (snapshot) {
          final docs = snapshot.docs;
          final filtered = _query.isEmpty
              ? docs
              : docs.where((d) {
                  final haystack = d.data().values
                      .whereType<String>()
                      .join(' ')
                      .toLowerCase();
                  return haystack.contains(_query.toLowerCase());
                }).toList();

          if (docs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(widget.content.icon,
                        size: 64, color: AppColors.primaryBlue.withValues(alpha: .25)),
                    const SizedBox(height: 14),
                    Text('No ${widget.content.title.toLowerCase()} yet.'),
                    const SizedBox(height: 6),
                    if (isStaff && !publicOnly)
                      TextButton.icon(
                        onPressed: () => _openEditor(),
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Add the first one'),
                      ),
                  ],
                ),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              TextField(
                decoration: InputDecoration(
                  hintText: 'Search ${widget.content.title.toLowerCase()}...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.button),
                  ),
                  isDense: true,
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Text(
                    '${filtered.length} of ${docs.length} records',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              ...filtered.map((doc) => _RecordCard(
                    doc: doc,
                    icon: widget.content.icon,
                    onEdit: isStaff && !publicOnly
                        ? () => _openEditor(doc)
                        : null,
                    onDelete: isStaff && !publicOnly
                        ? () => _delete(doc)
                        : null,
                  )),
            ],
          );
        },
      ),
    );
  }
}

class _RecordCard extends StatelessWidget {
  final DocumentSnapshot<Map<String, dynamic>> doc;
  final IconData icon;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _RecordCard({
    required this.doc,
    required this.icon,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final data = doc.data() ?? {};
    final entries = data.entries
        .where((e) =>
            e.value != null &&
            e.key != 'createdBy' &&
            e.key != 'updatedAt' &&
            e.key != 'createdAt' &&
            (e.value is String || e.value is num || e.value is bool ||
                e.value is Timestamp))
        .take(5)
        .toList();

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: AppColors.primaryBlue.withValues(alpha: .10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppColors.primaryBlue, size: 22),
        ),
        title: Text(
          entries.isEmpty
              ? doc.id
              : entries.first.value.toString(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: entries.skip(1).isEmpty
            ? null
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final e in entries.skip(1).take(3))
                    Text(
                      '${e.key}: ${e.value}'
                          .replaceAll('Timestamp', ''),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
        trailing: (onEdit == null && onDelete == null)
            ? null
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (onEdit != null)
                    IconButton(
                      tooltip: 'Edit',
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: onEdit,
                    ),
                  if (onDelete != null)
                    IconButton(
                      tooltip: 'Delete',
                      color: AppColors.error,
                      icon: const Icon(Icons.delete_outline_rounded),
                      onPressed: onDelete,
                    ),
                ],
              ),
      ),
    );
  }
}

class _ContentEditorDialog extends ConsumerStatefulWidget {
  final ContentCollection content;
  final DocumentSnapshot<Map<String, dynamic>>? existing;

  const _ContentEditorDialog({required this.content, this.existing});

  @override
  ConsumerState<_ContentEditorDialog> createState() =>
      _ContentEditorDialogState();
}

class _ContentEditorDialogState extends ConsumerState<_ContentEditorDialog> {
  late final Map<String, TextEditingController> _controllers;
  late final Map<String, String> _choices;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final data = widget.existing?.data() ?? {};
    _controllers = {
      for (final f in widget.content.fields) f.name: TextEditingController(
        text: switch (f.type) {
          ContentFieldType.date => _formatDate(data[f.name]),
          _ => data[f.name]?.toString() ?? '',
        },
      ),
    };
    _choices = {
      for (final f in widget.content.fields)
        if (f.type == ContentFieldType.choice)
          f.name: (data[f.name]?.toString() ??
              (f.options.isEmpty ? '' : f.options.first)),
    };
  }

  String? _formatDate(Object? value) {
    if (value is Timestamp) {
      final d = value.toDate();
      return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    }
    return null;
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate(TextEditingController controller) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      controller.text =
          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    }
  }

  Future<void> _save() async {
    for (final f in widget.content.fields) {
      if (f.type == ContentFieldType.choice) continue;
      if (_controllers[f.name]!.text.trim().isEmpty) {
        showAppSnackBar(context, '${f.label} is required.',
            backgroundColor: AppColors.error);
        return;
      }
    }

    final data = <String, dynamic>{
      for (final f in widget.content.fields)
        f.name: switch (f.type) {
          ContentFieldType.choice => _choices[f.name],
          ContentFieldType.date => Timestamp.fromDate(DateTime.tryParse(
                      _controllers[f.name]!.text) ??
                  DateTime.now()),
          _ => _controllers[f.name]!.text.trim(),
        },
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (!_isEdit) {
      data['createdAt'] = FieldValue.serverTimestamp();
    }

    try {
      if (_isEdit) {
        await widget.existing!.reference.update(data);
      } else {
        await FirebaseFirestore.instance
            .collection(widget.content.collection)
            .add(data);
        if (widget.content.collection == FirestoreCollections.announcements) {
          try {
            await _notifyAlumniOfAnnouncement(data);
          } catch (e) {
            if (mounted) {
              showAppSnackBar(context,
                  'Announcement saved, but notifying alumni failed: $e',
                  backgroundColor: AppColors.warning);
            }
          }
        }
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, 'Save failed: $e',
            backgroundColor: AppColors.error);
      }
    }
  }

  /// Creates an in-app notification for every alumni user so they see the
  /// new announcement in their notification bell.
  Future<void> _notifyAlumniOfAnnouncement(
      Map<String, dynamic> announcementData) async {
    final firestore = FirebaseFirestore.instance;
    final alumni = await firestore
        .collection(FirestoreCollections.users)
        .where('role', isEqualTo: UserRole.alumni.name)
        .get();

    if (alumni.docs.isEmpty) return;

    final batch = firestore.batch();
    final now = DateTime.now();
    for (final doc in alumni.docs) {
      if (doc.data()['disabled'] == true) continue;
      final notification = AppNotification(
        id: '',
        userId: doc.id,
        type: NotificationType.announcement,
        title: 'New announcement: ${announcementData['title']}',
        description: (announcementData['description'] as String? ?? '')
            .trim()
            .isEmpty
            ? 'A new announcement has been posted.'
            : announcementData['description'] as String,
        priority: NotificationPriority.medium,
        createdAt: now,
        link: AppRoutes.collectionData('announcements'),
      );
      batch.set(
        firestore.collection(FirestoreCollections.notifications).doc(),
        notification.toMap(),
      );
    }
    await batch.commit();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEdit ? 'Edit ${widget.content.title}' : 'Add ${widget.content.title}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final f in widget.content.fields) ...[
              if (f.type == ContentFieldType.longText)
                TextFormField(
                  controller: _controllers[f.name],
                  maxLines: 4,
                  decoration: InputDecoration(labelText: f.label),
                )
              else if (f.type == ContentFieldType.date)
                TextFormField(
                  controller: _controllers[f.name],
                  readOnly: true,
                  onTap: () => _pickDate(_controllers[f.name]!),
                  decoration: InputDecoration(
                    labelText: f.label,
                    suffixIcon: const Icon(Icons.calendar_today_outlined),
                  ),
                )
              else if (f.type == ContentFieldType.choice)
                DropdownButtonFormField<String>(
                  initialValue: _choices[f.name],
                  decoration: InputDecoration(labelText: f.label),
                  items: [
                    for (final option in f.options)
                      DropdownMenuItem(
                          value: option, child: Text(option)),
                  ],
                  onChanged: (v) => setState(() => _choices[f.name] = v ?? ''),
                )
              else
                TextFormField(
                  controller: _controllers[f.name],
                  decoration: InputDecoration(labelText: f.label),
                ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _save,
          child: Text(_isEdit ? 'Save Changes' : 'Add'),
        ),
      ],
    );
  }
}