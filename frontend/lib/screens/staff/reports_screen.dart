import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../constants/app_constants.dart';
import '../../models/user_model.dart' show parseApiDate;
import '../../providers/audit_log_providers.dart';
import '../../providers/role_providers.dart';
import '../../repositories/content_repository.dart';
import '../../services/auth_service.dart';
import '../../utils/app_snack_bar.dart';
import 'report_editor_screen.dart';

/// Newest-first stream of reports for the staff Reports screen.
final reportsProvider = StreamProvider.autoDispose<
    List<Map<String, dynamic>>>((ref) {
  return ref.watch(contentRepositoryProvider).watchCollection('reports');
});

/// Staff Reports screen. Staff (admin) can add reports; only
/// admins can delete them (reports are append-only by backend policy).
class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  Future<void> _addReport() async {
    final added = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const ReportEditorScreen()),
    );
    if (added == true && mounted) {
      showAppSnackBar(context, 'Report added.',
          backgroundColor: AppColors.success);
    }
  }

  Future<void> _delete(Map<String, dynamic> report) async {
    final id = report['id']?.toString() ?? '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete report?'),
        content: Text(
            'The report "${report['title']?.toString() ?? id}" will be permanently removed.'),
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
      await ref.read(contentRepositoryProvider).deleteItem('reports', id);
      await logAudit(
        ref,
        action: 'delete',
        title: 'Report deleted',
        description:
            'Deleted report "${report['title']?.toString() ?? id}".',
        targetId: id,
        targetType: 'report',
      );
      if (mounted) {
        showAppSnackBar(context, 'Report deleted.',
            backgroundColor: AppColors.success);
      }
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, 'Delete failed: ${AuthService.friendlyError(e)}',
            backgroundColor: AppColors.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = ref.watch(isAdminProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addReport,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Report'),
      ),
      body: ref.watch(reportsProvider).when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              'Reports could not be loaded right now.\n\n$e',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (reports) {
          if (reports.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.assessment_outlined,
                        size: 64,
                        color: AppColors.primaryBlue.withValues(alpha: .25)),
                    const SizedBox(height: 14),
                    const Text('No reports yet.'),
                    const SizedBox(height: 6),
                    Text(
                      'Add employment, tracer or institutional reports for BISU.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.tonalIcon(
                      onPressed: _addReport,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Add the first report'),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              Text('${reports.length} report${reports.length == 1 ? '' : 's'}',
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: AppSpacing.sm),
              for (final report in reports)
                _ReportCard(
                    report: report,
                    onDelete:
                        isAdmin ? () => _delete(report) : null),
              const SizedBox(height: AppSpacing.lg),
            ],
          );
        },
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final Map<String, dynamic> report;
  final VoidCallback? onDelete;

  const _ReportCard({required this.report, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final data = report;
    final type = data['type']?.toString();
    final period = data['period']?.toString();
    final createdAt = parseApiDate(data['createdAt']);

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: AppColors.primaryBlue.withValues(alpha: .10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.assessment_outlined,
              color: AppColors.primaryBlue, size: 22),
        ),
        title: Text(
          data['title']?.toString() ?? 'Report',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (type != null)
              Container(
                margin: const EdgeInsets.only(top: 4, bottom: 4),
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(AppRadius.chip),
                ),
                child: Text(
                  type,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.primaryBlue),
                ),
              ),
            if (period != null) Text('Period: $period'),
            if (data['description'] != null)
              Text(data['description'].toString(),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
            if (createdAt != null)
              Text('Added ${DateFormat('MMM d, yyyy').format(createdAt)}',
                  style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        trailing: onDelete == null
            ? null
            : IconButton(
                tooltip: 'Delete',
                color: AppColors.error,
                icon: const Icon(Icons.delete_outline_rounded),
                onPressed: onDelete,
              ),
      ),
    );
  }
}