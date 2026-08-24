import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/app_constants.dart';
import '../providers/execution_trace_provider.dart';

/// Opens the execution trace log. [floating] renders a compact glass circle
/// suited for overlaying page content (mobile).
class ExecutionTraceButton extends ConsumerWidget {
  const ExecutionTraceButton({super.key, this.floating = false});

  final bool floating;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(executionTraceProvider).length;

    Widget button(double iconSize) => IconButton(
          tooltip: 'Execution Trace',
          onPressed: () => _showTraceSheet(context, ref),
          icon: Icon(Icons.bug_report_outlined, size: iconSize),
          color: Theme.of(context).colorScheme.onSurface,
        );

    if (!floating) {
      return Badge(
        isLabelVisible: count > 0,
        label: Text('$count'),
        child: button(22),
      );
    }

    return Material(
      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.85),
      shape: const CircleBorder(),
      elevation: 3,
      child: Badge(
        isLabelVisible: count > 0,
        label: Text('$count'),
        child: button(20),
      ),
    );
  }

  Future<void> _showTraceSheet(BuildContext context, WidgetRef ref) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => const _ExecutionTraceSheet(),
    );
  }
}

class _ExecutionTraceSheet extends ConsumerWidget {
  const _ExecutionTraceSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(executionTraceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 12, 8),
            child: Row(
              children: [
                const Icon(Icons.bug_report_rounded, size: 20, color: AppColors.teal),
                const SizedBox(width: 8),
                Text(
                  'Execution Trace',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : AppColors.primaryNavy,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: entries.isEmpty
                      ? null
                      : () => ref.read(executionTraceProvider.notifier).clear(),
                  icon: const Icon(Icons.delete_outline_rounded, size: 16),
                  label: const Text('Clear'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: entries.isEmpty
                ? const _EmptyTrace()
                : ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.all(12),
                    itemCount: entries.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      return _TraceRow(entry: entry);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _EmptyTrace extends StatelessWidget {
  const _EmptyTrace();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.radar_rounded,
            size: 52,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 10),
          Text(
            'No executions recorded yet.\nInteract with the app to see async flows.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: Theme.of(context).colorScheme.outline,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _TraceRow extends StatelessWidget {
  const _TraceRow({required this.entry});

  final TraceEntry entry;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final (Color color, IconData icon) = switch (entry.phase) {
      TracePhase.start => (AppColors.info, Icons.play_arrow_rounded),
      TracePhase.loading => (AppColors.warning, Icons.hourglass_top_rounded),
      TracePhase.data => (AppColors.success, Icons.check_circle_rounded),
      TracePhase.error => (AppColors.error, Icons.error_rounded),
      TracePhase.call => (AppColors.teal, Icons.bolt_rounded),
    };

    final time =
        '${entry.time.hour.toString().padLeft(2, '0')}:${entry.time.minute.toString().padLeft(2, '0')}:${entry.time.second.toString().padLeft(2, '0')}.${entry.time.millisecond.toString().padLeft(3, '0')}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.cardDark
            : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      entry.label,
                      style: GoogleFonts.poppins(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        entry.source,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : AppColors.primaryNavy,
                        ),
                      ),
                    ),
                  ],
                ),
                if (entry.detail.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    entry.detail,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 10,
                      color: isDark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            time,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 9.5,
              color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }
}