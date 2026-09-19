import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../constants/app_constants.dart';
import '../../models/user_model.dart' show parseApiDate;
import '../../providers/audit_log_providers.dart';
import '../../providers/role_providers.dart';
import '../../providers/stats_providers.dart';
import '../../repositories/content_repository.dart';
import '../../repositories/stats_repository.dart';
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
  /// When true, no AppBar is built so the screen can be embedded as a tab.
  final bool hideAppBar;

  const ReportsScreen({super.key, this.hideAppBar = false});

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
      appBar:
          widget.hideAppBar ? null : AppBar(title: const Text('Reports')),
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
                        color: AppColors.primaryBlue.withOpacity(.25)),
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
              const _LiveSummaryCard(),
              const SizedBox(height: AppSpacing.sm),
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

/// Auto-generated institutional summary computed from live backend data.
/// This is the always-current "true report": alumni totals, verification and
/// employment rates, survey activity, and per-batch employment outcomes.
class _LiveSummaryCard extends ConsumerWidget {
  const _LiveSummaryCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final stats =
        ref.watch(staffStatsProvider).valueOrNull ?? DashboardStats.empty;
    final generated = DateFormat('MMM d, yyyy · h:mm a').format(DateTime.now());
    final figureColor = isDark ? Colors.white : AppColors.textPrimary;
    final labelColor =
        isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary;
    final barColor = isDark ? AppColors.bisuBlue300 : AppColors.primaryBlue;

    Widget figure(String value, String label) {
      return Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                    color: figureColor)),
            const SizedBox(height: 2),
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: labelColor)),
          ],
        ),
      );
    }

    final batches = [...stats.employmentByYear]
      ..sort((a, b) => b.year.compareTo(a.year));

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: BorderSide(
          color: AppColors.primaryBlue.withOpacity(0.35),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withOpacity(isDark ? 0.22 : 0.10),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.verified_rounded,
                      color: AppColors.primaryBlue, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Institutional Tracer Summary',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: figureColor)),
                      const SizedBox(height: 2),
                      Text('Auto-generated from live data · $generated',
                          style: TextStyle(fontSize: 11, color: labelColor)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(isDark ? 0.20 : 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'LIVE',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: isDark
                          ? AppColors.successLight
                          : AppColors.success,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                figure('${stats.alumni}', 'Alumni'),
                figure('${stats.verificationRate.toStringAsFixed(1)}%',
                    'Verified'),
                figure('${stats.employmentRate.toStringAsFixed(1)}%',
                    'Employed'),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                figure('${stats.surveyCount}', 'Surveys'),
                figure('${stats.responseCount}', 'Responses'),
                figure('${stats.eventCount}', 'Events'),
              ],
            ),
            if (batches.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Text('Employment by graduation batch',
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: figureColor)),
              const SizedBox(height: 8),
              for (final row in batches)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 52,
                        child: Text('${row.year}',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: labelColor)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: row.total == 0
                                ? 0
                                : (row.employedCount / row.total)
                                    .clamp(0.0, 1.0),
                            minHeight: 8,
                            backgroundColor: AppColors.primaryBlue
                                .withOpacity(isDark ? 0.25 : 0.12),
                            valueColor:
                                AlwaysStoppedAnimation<Color>(barColor),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 44,
                        child: Text(
                          row.total == 0
                              ? '—'
                              : '${((row.employedCount / row.total) * 100).round()}%',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: barColor),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final deleteColor = isDark ? AppColors.errorLight : AppColors.error;
    final type = data['type']?.toString();
    final period = data['period']?.toString();
    final createdAt = parseApiDate(data['createdAt']);

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: AppColors.primaryBlue.withOpacity(.10),
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
                color: deleteColor,
                icon: const Icon(Icons.delete_outline_rounded),
                onPressed: onDelete,
              ),
      ),
    );
  }
}