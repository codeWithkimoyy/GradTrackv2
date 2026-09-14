import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../constants/app_constants.dart';
import '../../models/user_model.dart' show parseApiDate;
import '../../providers/audit_log_providers.dart';

/// Admin-only, read-only trail of staff/security actions, newest first.
/// Entries are written by [logAudit] and can never be edited or deleted.
class AuditLogScreen extends ConsumerWidget {
  const AuditLogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsync = ref.watch(auditLogsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Audit Logs')),
      body: logsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              'Audit logs are restricted to administrators.\n\n$e',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (entries) {
          if (entries.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.history_rounded,
                        size: 64,
                        color: AppColors.primaryBlue.withValues(alpha: .25)),
                    const SizedBox(height: 14),
                    const Text('No audit entries yet.'),
                    const SizedBox(height: 6),
                    Text(
                      'Staff and security actions will be recorded here.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              Row(
                children: [
                  Text(
                    '${entries.length} entr${entries.length == 1 ? 'y' : 'ies'}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              for (final entry in entries) _AuditEntryCard(entry: entry),
              const SizedBox(height: AppSpacing.lg),
            ],
          );
        },
      ),
    );
  }
}

class _AuditEntryCard extends StatelessWidget {
  final Map<String, dynamic> entry;

  const _AuditEntryCard({required this.entry});

  (IconData, Color) _styleFor(String action) => switch (action) {
        'delete' => (Icons.delete_outline_rounded, AppColors.error),
        'create' => (Icons.add_circle_outline_rounded, AppColors.success),
        'update' => (Icons.edit_outlined, AppColors.primaryBlue),
        _ => (Icons.security_rounded, AppColors.secondaryBlue),
      };

  @override
  Widget build(BuildContext context) {
    final data = entry;
    final (icon, color) = _styleFor(data['action']?.toString() ?? '');
    final actorName = data['actorName']?.toString();
    final actorRole = data['actorRole']?.toString();
    final target = data['targetType']?.toString();
    final createdAt = parseApiDate(data['createdAt']);

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: .10),
          child: Icon(icon, color: color, size: 22),
        ),
        title: Text(
          data['title']?.toString() ?? 'Activity',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (data['description'] != null)
              Text(data['description'].toString()),
            const SizedBox(height: 4),
            Text(
              [
                if (target != null) target,
                if (actorName != null)
                  'by $actorName${actorRole != null ? ' ($actorRole)' : ''}',
                if (createdAt != null)
                  DateFormat('MMM d, yyyy · h:mm a').format(createdAt),
              ].join(' · '),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }
}