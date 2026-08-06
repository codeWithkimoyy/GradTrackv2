import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../constants/app_constants.dart';
import '../../models/employment_model.dart';
import '../../providers/employment_providers.dart';


class EmploymentHistoryScreen extends ConsumerWidget {
  const EmploymentHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recordsAsync = ref.watch(myEmploymentRecordsProvider);
    final milestonesAsync = ref.watch(myCareerMilestonesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Employment & Career'),
        bottom: const TabBar(tabs: [
          Tab(text: 'History'),
          Tab(text: 'Timeline'),
        ]),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/employment/add'),
        icon: const Icon(Icons.add),
        label: const Text('Add Job'),
      ),
      body: TabBarView(
        children: [
          recordsAsync.when(
            data: (records) => _HistoryList(records: records),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
          milestonesAsync.when(
            data: (milestones) => _CareerTimeline(milestones: milestones),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
        ],
      ),
    );
  }
}

/// Wraps the screen body with a DefaultTabController since the AppBar's
/// TabBar needs a TabController ancestor.
class EmploymentHistoryPage extends StatelessWidget {
  const EmploymentHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const DefaultTabController(
      length: 2,
      child: EmploymentHistoryScreen(),
    );
  }
}

class _HistoryList extends ConsumerWidget {
  final List<EmploymentRecord> records;
  const _HistoryList({required this.records});

  Future<void> _delete(BuildContext context, WidgetRef ref, EmploymentRecord r) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Record'),
        content: Text('Delete "${r.position}" at ${r.company}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(employmentRepositoryProvider).deleteRecord(r.id);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (records.isEmpty) {
      return const _EmptyState(
        icon: Icons.work_outline,
        message: 'No employment records yet.\nTap "Add Job" to get started.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: records.length,
      itemBuilder: (context, i) {
        final r = records[i];
        return Dismissible(
          key: ValueKey(r.id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            decoration: BoxDecoration(
              color: AppColors.error,
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          confirmDismiss: (_) async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Delete Record'),
                content: Text('Delete "${r.position}" at ${r.company}?'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                  TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
                ],
              ),
            );
            return confirmed ?? false;
          },
          onDismissed: (_) => _delete(context, ref, r),
          child: Card(
            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          r.position,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      if (r.isCurrent)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(AppRadius.chip),
                          ),
                          child: const Text('Current',
                              style: TextStyle(
                                  color: AppColors.success,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                        ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                        onPressed: () => _delete(context, ref, r),
                        tooltip: 'Delete',
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(r.company,
                      style: TextStyle(color: Colors.grey[700], fontSize: 14)),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      _tag(Icons.calendar_today_outlined,
                          DateFormat.yMMM().format(r.dateHired)),
                      _tag(Icons.location_on_outlined, '${r.city}, ${r.country}'),
                      _tag(Icons.laptop_mac_outlined, r.workSetup.label),
                      _tag(Icons.badge_outlined, r.employmentType),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _tag(IconData icon, String text) {
    return Chip(
      avatar: Icon(icon, size: 16),
      label: Text(text, style: const TextStyle(fontSize: 12)),
      visualDensity: VisualDensity.compact,
      backgroundColor: AppColors.primaryBlue.withValues(alpha: 0.06),
      side: BorderSide.none,
    );
  }
}

class _CareerTimeline extends StatelessWidget {
  final List<CareerMilestone> milestones;
  const _CareerTimeline({required this.milestones});

  IconData _iconFor(MilestoneType type) => switch (type) {
        MilestoneType.firstJob => Icons.flag_outlined,
        MilestoneType.promotion => Icons.trending_up,
        MilestoneType.transfer => Icons.swap_horiz,
        MilestoneType.certification => Icons.workspace_premium_outlined,
        MilestoneType.award => Icons.emoji_events_outlined,
      };

  Color _colorFor(MilestoneType type) => switch (type) {
        MilestoneType.firstJob => AppColors.info,
        MilestoneType.promotion => AppColors.success,
        MilestoneType.transfer => AppColors.warning,
        MilestoneType.certification => AppColors.gold,
        MilestoneType.award => AppColors.primaryBlue,
      };

  @override
  Widget build(BuildContext context) {
    if (milestones.isEmpty) {
      return const _EmptyState(
        icon: Icons.timeline_outlined,
        message:
            'No career milestones yet.\nThey\'ll appear here as you log jobs,\npromotions, and certifications.',
      );
    }

    // Already sorted descending by date from the repository query.
    final sorted = milestones;

    return ListView.builder(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.lg),
      itemCount: sorted.length,
      itemBuilder: (context, i) {
        final m = sorted[i];
        final isLast = i == sorted.length - 1;
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _colorFor(m.type).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(_iconFor(m.type),
                        size: 18, color: _colorFor(m.type)),
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: 2,
                        color: Colors.grey[300],
                      ),
                    ),
                ],
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat.yMMMd().format(m.date),
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        m.title,
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      if (m.description != null)
                        Text(
                          m.description!,
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: Colors.grey[300]),
          const SizedBox(height: AppSpacing.md),
          Text(message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[500])),
        ],
      ),
    );
  }
}
