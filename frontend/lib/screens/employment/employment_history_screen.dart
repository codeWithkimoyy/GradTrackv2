import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../constants/app_constants.dart';
import '../../models/employment_model.dart';
import '../../providers/employment_providers.dart';
import '../../widgets/empty_state_widget.dart';


class EmploymentHistoryScreen extends ConsumerWidget {
  const EmploymentHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recordsAsync = ref.watch(myEmploymentRecordsProvider);
    final milestonesAsync = ref.watch(myCareerMilestonesProvider);

    return Scaffold(
      backgroundColor: AppColors.surfaceDark,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceDark,
        elevation: 0,
        title: Text(
          'Employment & Career',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        bottom: TabBar(
          indicatorColor: AppColors.primaryBlue,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: const Color(0xFF94A3B8),
          labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13),
          tabs: const [
            Tab(text: 'Work History'),
            Tab(text: 'Career Timeline'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: Colors.white,
        onPressed: () => context.push('/employment/add'),
        icon: const Icon(Icons.add_rounded),
        label: Text('Add Job Record', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
      ),
      body: TabBarView(
        children: [
          recordsAsync.when(
            data: (records) => _HistoryList(records: records),
            loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primaryBlue)),
            error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: Colors.white))),
          ),
          milestonesAsync.when(
            data: (milestones) => _CareerTimeline(milestones: milestones),
            loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primaryBlue)),
            error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: Colors.white))),
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
      return EmptyStateWidget(
        icon: Icons.work_outline_rounded,
        title: 'No Employment Records',
        message: 'Log your current position or past work experience to keep your alumni tracer updated.',
        actionLabel: 'Add Job Record',
        onAction: () => context.push('/employment/add'),
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
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.cardDark,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.borderDark),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        r.position,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    if (r.isCurrent)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(AppRadius.chip),
                          border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          'Current Job',
                          style: GoogleFonts.poppins(
                            color: AppColors.success,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 20),
                      onPressed: () => _delete(context, ref, r),
                      tooltip: 'Delete',
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  r.company,
                  style: GoogleFonts.poppins(color: const Color(0xFF94A3B8), fontSize: 13.5),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _tag(Icons.calendar_today_outlined, DateFormat.yMMM().format(r.dateHired)),
                    _tag(Icons.location_on_outlined, '${r.city}, ${r.country}'),
                    _tag(Icons.laptop_mac_outlined, r.workSetup.label),
                    _tag(Icons.badge_outlined, r.employmentType),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _tag(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primaryBlue.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.secondaryBlue),
          const SizedBox(width: 5),
          Text(
            text,
            style: GoogleFonts.poppins(fontSize: 11.5, color: Colors.white),
          ),
        ],
      ),
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
      return const EmptyStateWidget(
        icon: Icons.timeline_rounded,
        title: 'No Career Milestones Yet',
        message: 'Your career achievements, promotions, and job milestones will automatically appear here as you update your profile.',
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
                        style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        m.title,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      if (m.description != null)
                        Text(
                          m.description!,
                          style: GoogleFonts.poppins(fontSize: 12.5, color: const Color(0xFF94A3B8)),
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
