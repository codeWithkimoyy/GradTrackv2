import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../constants/app_constants.dart';
import '../../models/notification_model.dart';
import '../../models/user_model.dart';
import '../../providers/audit_log_providers.dart';
import '../../providers/role_providers.dart';
import '../../routes/app_router.dart';
import '../../utils/app_snack_bar.dart';
import '../staff/survey_editor_screen.dart';
import '../staff/survey_responses_screen.dart';

enum ContentFieldType { text, longText, date, choice, monthYear, toggle }

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
  final bool canAdd;

  const ContentCollection({
    required this.collection,
    required this.title,
    required this.icon,
    required this.fields,
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
    title: 'Employment',
    icon: Icons.business_center_outlined,
    fields: [
      ContentField('jobTitle', 'Job Title'),
      ContentField('company', 'Company / Organization'),
      ContentField('employmentType', 'Employment Type',
          type: ContentFieldType.choice,
          options: [
            'Full-time',
            'Part-time',
            'Internship',
            'Freelance',
            'Contract',
            'Self-employed',
          ]),
      ContentField('startDate', 'Start Date', type: ContentFieldType.monthYear),
      ContentField('endDate', 'End Date', type: ContentFieldType.monthYear),
      ContentField('isCurrent', 'Currently Working Here',
          type: ContentFieldType.toggle),
      ContentField('salary', 'Salary'),
      ContentField('location', 'Location'),
      ContentField('description', 'Description / Responsibilities',
          type: ContentFieldType.longText),
      ContentField('visibility', 'Visibility',
          type: ContentFieldType.choice, options: ['public', 'private']),
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

/// Live Riverpod snapshot of a collection's docs. Unknown roles
/// are limited to `visibility == 'public'` records, staff see everything.
final collectionContentsProvider = StreamProvider.autoDispose
    .family<QuerySnapshot<Map<String, dynamic>>, ContentCollection>(
        (ref, content) {
  final role = ref.watch(currentUserRoleProvider);
  final publicOnly = role == null;
  Query<Map<String, dynamic>> query =
      FirebaseFirestore.instance.collection(content.collection);
  if (publicOnly) {
    query = query.where('visibility', isEqualTo: 'public');
  }
  return query.snapshots();
});

/// Live, role-aware list + CRUD screen for a Firestore collection.
/// Staff (admin) can add, edit and delete records; alumni can browse.
/// Unknown roles only ever see public records.
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
    return role == null;
  }

  Future<void> _openEditor([DocumentSnapshot<Map<String, dynamic>>? doc]) async {
    if (widget.content.collection == FirestoreCollections.surveys) {
      final saved = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => SurveyEditorScreen(existing: doc)),
      );
      if (saved == true && mounted) {
        showAppSnackBar(context, 'Survey saved successfully.',
            backgroundColor: AppColors.success);
      }
      if (saved == true) {
        await logAudit(
          ref,
          action: doc == null ? 'create' : 'update',
          title: doc == null ? 'Survey created' : 'Survey updated',
          description:
              '${doc == null ? 'Created' : 'Updated'} the ${widget.content.title} "${_recordTitle(doc)}".',
          targetId: doc?.id,
          targetType: widget.content.title.toLowerCase(),
        );
      }
      return;
    }

    final canEdit = await showDialog<bool>(
      context: context,
      builder: (_) => _ContentEditorDialog(
        content: widget.content,
        existing: doc,
      ),
    );
    if (!mounted || canEdit == null || !canEdit) return;
    await logAudit(
      ref,
      action: doc == null ? 'create' : 'update',
      title: doc == null
          ? '${widget.content.title} created'
          : '${widget.content.title} updated',
      description: '${doc == null ? 'Created' : 'Updated'} a ${widget.content.title.toLowerCase()} record "${_recordTitle(doc)}".',
      targetId: doc?.id,
      targetType: widget.content.title.toLowerCase(),
    );
  }

  String _recordTitle(DocumentSnapshot<Map<String, dynamic>>? doc) {
    if (doc == null) return '(new)';
    final data = doc.data();
    final title =
        data?['jobTitle']?.toString() ?? data?['title']?.toString();
    return title != null && title.isNotEmpty ? title : doc.id;
  }

  void _openResponses(DocumentSnapshot<Map<String, dynamic>> doc) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SurveyResponsesScreen(survey: doc)),
    );
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
    final title = _recordTitle(doc);
    try {
      await doc.reference.delete();
      if (mounted) {
        showAppSnackBar(context, 'Deleted successfully.',
            backgroundColor: AppColors.success);
      }
      await logAudit(
        ref,
        action: 'delete',
        title: '${widget.content.title} deleted',
        description:
            'Deleted ${widget.content.title.toLowerCase()} record "$title".',
        targetId: doc.id,
        targetType: widget.content.title.toLowerCase(),
      );
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, 'Delete failed: $e',
            backgroundColor: AppColors.error);
      }
    }
  }

  bool get _isJobs => widget.content.collection == FirestoreCollections.jobs;

  bool _matchesQuery(Map<String, dynamic> data) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return true;
    final haystack = _isJobs
        ? [data['jobTitle'], data['title'], data['company'],
            data['employmentType'], data['location']]
            .whereType<String>()
            .join(' ')
            .toLowerCase()
        : data.values.whereType<String>().join(' ').toLowerCase();
    return haystack.contains(q);
  }

  /// Staff can manage every record; alumni can manage the employment
  /// records they created themselves. Unknown roles never mutate content.
  bool _canManageDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    if (_publicOnly) return false;
    if (ref.read(isStaffProvider)) return true;
    if (!_isJobs) return false;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return uid != null && doc.data()?['createdBy'] == uid;
  }

  Future<void> _openEmploymentDetails(
    DocumentSnapshot<Map<String, dynamic>> doc, {
    required bool canManage,
    VoidCallback? onEdit,
    VoidCallback? onDelete,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => _EmploymentDetailsSheet(
        doc: doc,
        canManage: canManage,
        onEdit: () {
          Navigator.pop(sheetCtx);
          onEdit?.call();
        },
        onDelete: () {
          Navigator.pop(sheetCtx);
          onDelete?.call();
        },
      ),
    );
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
    final canAddRecords = isStaff ||
        widget.content.collection == FirestoreCollections.jobs;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.content.title),
        actions: [
          if (canAddRecords && !publicOnly && widget.content.canAdd)
            IconButton(
              tooltip: 'Add ${widget.content.title}',
              icon: const Icon(Icons.add_rounded),
              onPressed: () => _openEditor(),
            ),
        ],
      ),
      floatingActionButton: canAddRecords && !publicOnly
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
          final filtered =
              _query.isEmpty ? docs : docs.where((d) => _matchesQuery(d.data())).toList();

          if (docs.isEmpty) {
            if (_isJobs) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: AppColors.primaryBlue.withValues(alpha: .12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.work_outline_rounded,
                            size: 44, color: AppColors.primaryBlue),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No employment records yet',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Add your first employment experience.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (canAddRecords && !publicOnly) ...[
                        const SizedBox(height: 12),
                        TextButton.icon(
                          onPressed: () => _openEditor(),
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Add the first one'),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }
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
                    if (canAddRecords && !publicOnly)
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
              ...filtered.map((doc) {
                final canManage = _canManageDoc(doc);
                if (_isJobs) {
                  return _EmploymentRecordCard(
                    doc: doc,
                    onView: () => _openEmploymentDetails(
                      doc,
                      canManage: canManage,
                      onEdit: canManage ? () => _openEditor(doc) : null,
                      onDelete: canManage ? () => _delete(doc) : null,
                    ),
                    onEdit: canManage ? () => _openEditor(doc) : null,
                    onDelete: canManage ? () => _delete(doc) : null,
                  );
                }
                return _RecordCard(
                  doc: doc,
                  icon: widget.content.icon,
                  onResponses:
                      widget.content.collection ==
                              FirestoreCollections.surveys &&
                          isStaff &&
                          !publicOnly
                          ? () => _openResponses(doc)
                          : null,
                  onEdit: isStaff && !publicOnly
                      ? () => _openEditor(doc)
                      : null,
                  onDelete: isStaff && !publicOnly
                      ? () => _delete(doc)
                      : null,
                );
              }),
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
  final VoidCallback? onResponses;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _RecordCard({
    required this.doc,
    required this.icon,
    this.onResponses,
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
        trailing: (onResponses == null && onEdit == null && onDelete == null)
            ? null
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (onResponses != null)
                    IconButton(
                      tooltip: 'View Responses',
                      icon: const Icon(Icons.poll_outlined),
                      onPressed: onResponses,
                    ),
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

class _EmploymentRecordCard extends StatelessWidget {
  final DocumentSnapshot<Map<String, dynamic>> doc;
  final VoidCallback? onView;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _EmploymentRecordCard({
    required this.doc,
    this.onView,
    this.onEdit,
    this.onDelete,
  });

  static String? _monthYear(Object? value) {
    if (value is Timestamp) return DateFormat.yMMM().format(value.toDate());
    return null;
  }

  String _range(Map<String, dynamic> data) {
    final start = _monthYear(data['startDate']);
    final current = data['isCurrent'] == true;
    if (start == null) return current ? 'Present' : '';
    if (current) return '$start \u2013 Present';
    final end = _monthYear(data['endDate']);
    return end == null ? start : '$start \u2013 $end';
  }

  @override
  Widget build(BuildContext context) {
    final data = doc.data() ?? {};
    final jobTitle =
        data['jobTitle']?.toString() ?? data['title']?.toString() ?? 'Untitled';
    final company = data['company']?.toString() ?? '';
    final type = data['employmentType']?.toString() ?? '';
    final location = data['location']?.toString() ?? '';
    final salary = data['salary']?.toString() ?? '';
    final isCurrent = data['isCurrent'] == true;
    final description = data['description']?.toString() ?? '';
    final range = _range(data);

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onView,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue.withValues(alpha: .10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.business_center_outlined,
                        color: AppColors.primaryBlue, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          jobTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        if (company.isNotEmpty)
                          Text(
                            company,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ),
                  if (onEdit != null)
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Edit',
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      onPressed: onEdit,
                    ),
                  if (onDelete != null)
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Delete',
                      color: AppColors.error,
                      icon: const Icon(Icons.delete_outline_rounded, size: 20),
                      onPressed: onDelete,
                    ),
                ],
              ),
              const SizedBox(height: 10),
              if (range.isNotEmpty || type.isNotEmpty || location.isNotEmpty)
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    if (isCurrent)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: .15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Present',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.success,
                          ),
                        ),
                      )
                    else if (range.isNotEmpty)
                      _chip(context, Icons.calendar_today_outlined, range),
                    if (type.isNotEmpty)
                      _chip(context, Icons.badge_outlined, type),
                    if (salary.isNotEmpty)
                      _chip(context, Icons.payments_outlined, salary),
                    if (location.isNotEmpty)
                      _chip(context, Icons.location_on_outlined, location),
                  ],
                ),
              if (description.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(BuildContext context, IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primaryBlue.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primaryBlue.withValues(alpha: .20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.primaryBlue),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryNavy,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmploymentDetailsSheet extends StatelessWidget {
  final DocumentSnapshot<Map<String, dynamic>> doc;
  final bool canManage;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _EmploymentDetailsSheet({
    required this.doc,
    required this.canManage,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final data = doc.data() ?? {};
    final jobTitle =
        data['jobTitle']?.toString() ?? data['title']?.toString() ?? 'Untitled';
    final description = data['description']?.toString() ?? '';

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withValues(alpha: .3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Icon(Icons.business_center_rounded,
                  color: AppColors.primaryBlue),
              const SizedBox(height: 8),
              Text(jobTitle,
                  style: Theme.of(context).textTheme.titleLarge),
              if (data['company']?.toString().isNotEmpty == true)
                Text(data['company'].toString(),
                    style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 14),
              for (final (label, value) in [
                ('Employment Type', data['employmentType']?.toString()),
                ('Salary', data['salary']?.toString()),
                ('Status',
                    data['isCurrent'] == true ? 'Currently working here' : null),
                ('Start Date',
                    _EmploymentRecordCard._monthYear(data['startDate'])),
                ('End Date', data['isCurrent'] == true
                    ? 'Present'
                    : _EmploymentRecordCard._monthYear(data['endDate'])),
                ('Location', data['location']?.toString()),
                ('Visibility', data['visibility']?.toString()),
              ])
                if (value != null && value.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 128,
                          child: Text(label,
                              style: Theme.of(context).textTheme.bodySmall),
                        ),
                        Expanded(
                          child: Text(value,
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ),
              if (description.isNotEmpty) ...[
                const Divider(height: 24),
                Text('Description / Responsibilities',
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 4),
                Text(description),
              ],
              if (canManage) ...[
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: onEdit,
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Edit'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onDelete,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error),
                        icon: const Icon(Icons.delete_outline_rounded),
                        label: const Text('Delete'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MonthYearPickerDialog extends StatefulWidget {
  final DateTime initial;
  const _MonthYearPickerDialog({required this.initial});

  @override
  State<_MonthYearPickerDialog> createState() =>
      _MonthYearPickerDialogState();
}

class _MonthYearPickerDialogState extends State<_MonthYearPickerDialog> {
  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  late int _year = widget.initial.year;
  late int? _month = widget.initial.month;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? Colors.white : AppColors.surfaceDark;

    return AlertDialog(
      title: const Text('Select month and year'),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left_rounded),
                  onPressed: () => setState(() => _year--),
                ),
                Text('$_year',
                    style: Theme.of(context).textTheme.titleMedium),
                IconButton(
                  icon: const Icon(Icons.chevron_right_rounded),
                  onPressed: () => setState(() => _year++),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < 12; i++)
                  InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => setState(() => _month = i + 1),
                    child: Container(
                      width: 60,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _month == i + 1
                            ? AppColors.primaryBlue
                            : AppColors.primaryBlue.withValues(alpha: .10),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _months[i],
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12.5,
                          color: _month == i + 1 ? Colors.white : fg,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _month == null
              ? null
              : () => Navigator.pop(
                  context, DateTime(_year, _month!, 1)),
          child: const Text('OK'),
        ),
      ],
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
  late final Map<String, DateTime?> _months;
  late final Map<String, bool> _toggles;

  bool get _isEdit => widget.existing != null;
  bool get _isCurrent => _toggles['isCurrent'] ?? false;

  @override
  void initState() {
    super.initState();
    final data = widget.existing?.data() ?? {};
    _controllers = {
      for (final f in widget.content.fields) f.name: TextEditingController(
        text: switch (f.type) {
          ContentFieldType.date => _formatDate(data[f.name]) ?? '',
          ContentFieldType.monthYear => data[f.name] is Timestamp
              ? DateFormat.yMMM().format((data[f.name] as Timestamp).toDate())
              : '',
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
    _months = {
      for (final f in widget.content.fields)
        if (f.type == ContentFieldType.monthYear)
          f.name: data[f.name] is Timestamp
              ? (data[f.name] as Timestamp).toDate()
              : null,
    };
    _toggles = {
      for (final f in widget.content.fields)
        if (f.type == ContentFieldType.toggle) f.name: data[f.name] == true,
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

  Future<void> _pickMonth(TextEditingController controller, String name) async {
    final picked = await showDialog<DateTime>(
      context: context,
      builder: (_) =>
          _MonthYearPickerDialog(initial: _months[name] ?? DateTime.now()),
    );
    if (picked != null) {
      setState(() {
        _months[name] = picked;
        controller.text = DateFormat.yMMM().format(picked);
      });
    }
  }

  Future<void> _save() async {
    final isCurrent = _isCurrent;
    for (final f in widget.content.fields) {
      if (f.type == ContentFieldType.choice) continue;
      if (f.type == ContentFieldType.toggle) continue;
      if (f.name == 'endDate' && isCurrent) continue;
      if (_controllers[f.name]!.text.trim().isEmpty) {
        showAppSnackBar(context, '${f.label} is required.',
            backgroundColor: AppColors.error);
        return;
      }
    }

    final data = <String, dynamic>{'updatedAt': FieldValue.serverTimestamp()};
    for (final f in widget.content.fields) {
      switch (f.type) {
        case ContentFieldType.choice:
          data[f.name] = _choices[f.name];
        case ContentFieldType.date:
          data[f.name] = Timestamp.fromDate(
              DateTime.tryParse(_controllers[f.name]!.text) ?? DateTime.now());
        case ContentFieldType.monthYear:
          final m = _months[f.name];
          if (m != null) data[f.name] = Timestamp.fromDate(m);
        case ContentFieldType.toggle:
          data[f.name] = _toggles[f.name] ?? false;
        case ContentFieldType.text:
        case ContentFieldType.longText:
          data[f.name] = _controllers[f.name]!.text.trim();
      }
    }
    if (!_isEdit) {
      data['createdAt'] = FieldValue.serverTimestamp();
    }
    final isJobs =
        widget.content.collection == FirestoreCollections.jobs;
    if (isJobs) {
      if (isCurrent) {
        data['endDate'] = FieldValue.delete();
      }
      if (!_isEdit) {
        data['createdBy'] = FirebaseAuth.instance.currentUser?.uid ?? '';
      }
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
              else if (f.type == ContentFieldType.monthYear)
                TextFormField(
                  controller: _controllers[f.name],
                  readOnly: true,
                  enabled: !(f.name == 'endDate' && _isCurrent),
                  onTap: () => _pickMonth(_controllers[f.name]!, f.name),
                  decoration: InputDecoration(
                    labelText: f.label,
                    suffixIcon: const Icon(Icons.event_outlined),
                  ),
                )
              else if (f.type == ContentFieldType.toggle)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(f.label),
                  subtitle: f.name == 'isCurrent'
                      ? Text(
                          _isCurrent
                              ? 'End date not required. Show “Present”.'
                              : 'End date becomes required.',
                          style: Theme.of(context).textTheme.bodySmall,
                        )
                      : null,
                  value: _toggles[f.name] ?? false,
                  activeTrackColor: AppColors.primaryBlue,
                  onChanged: (v) => setState(() {
                    _toggles[f.name] = v;
                    if (f.name == 'isCurrent' && v) {
                      _controllers['endDate']?.clear();
                      _months['endDate'] = null;
                    }
                  }),
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