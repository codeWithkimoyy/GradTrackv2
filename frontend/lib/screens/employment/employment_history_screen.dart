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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        elevation: 0,
        title: Text(
          'Employment & Career',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : AppColors.primaryNavy,
          ),
        ),
        bottom: TabBar(
          indicatorColor: AppColors.primaryBlue,
          indicatorWeight: 3,
          labelColor: isDark ? Colors.white : AppColors.primaryNavy,
          unselectedLabelColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
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
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
          milestonesAsync.when(
            data: (milestones) => _CareerTimeline(milestones: milestones),
            loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primaryBlue)),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
      padding: const EdgeInsets.all(24),
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
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          confirmDismiss: (_) async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: isDark ? AppColors.cardDark : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                title: Text('Delete Record', style: GoogleFonts.poppins(color: isDark ? Colors.white : AppColors.primaryNavy)),
                content: Text('Delete "${r.position}" at ${r.company}?', style: GoogleFonts.poppins(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                  TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: AppColors.error))),
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
              color: isDark ? AppColors.cardDark : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isDark ? AppColors.borderDark : AppColors.borderLight,
              ),
              boxShadow: isDark
                  ? []
                  : const [
                      BoxShadow(
                        color: Color(0x0C0F172A),
                        blurRadius: 12,
                        offset: Offset(0, 2),
                      ),
                    ],
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
                          color: isDark ? Colors.white : AppColors.primaryNavy,
                        ),
                      ),
                    ),
                    if (r.isCurrent)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.15),
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
                  style: GoogleFonts.poppins(
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    fontSize: 13.5,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _tag(
                      context,
                      Icons.calendar_today_outlined,
                      r.isCurrent || r.endDate == null
                          ? '${DateFormat.yMMM().format(r.dateHired)} – Present'
                          : '${DateFormat.yMMM().format(r.dateHired)} – ${DateFormat.yMMM().format(r.endDate!)}',
                    ),
                    _tag(context, Icons.location_on_outlined, '${r.city}, ${r.country}'),
                    _tag(context, Icons.laptop_mac_outlined, r.workSetup.label),
                    _tag(context, Icons.badge_outlined, r.employmentType),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _tag(BuildContext context, IconData icon, String text) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primaryBlue.withValues(alpha: isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primaryBlue.withValues(alpha: 0.20),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.primaryBlue),
          const SizedBox(width: 5),
          Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 11.5,
              color: isDark ? Colors.white : AppColors.primaryNavy,
            ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (milestones.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.timeline_rounded,
        title: 'No Career Milestones Yet',
        message: 'Your career achievements, promotions, and job milestones will automatically appear here as you update your profile.',
      );
    }

    final sorted = milestones;

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
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
                    child: Icon(_iconFor(m.type), size: 18, color: _colorFor(m.type)),
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: 2,
                        color: isDark ? AppColors.borderDark : AppColors.borderLight,
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat.yMMMd().format(m.date),
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        m.title,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : AppColors.primaryNavy,
                        ),
                      ),
                      if (m.description != null)
                        Text(
                          m.description!,
                          style: GoogleFonts.poppins(
                            fontSize: 12.5,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
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
