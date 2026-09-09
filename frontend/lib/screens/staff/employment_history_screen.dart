import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../constants/app_constants.dart';
import '../../models/employment_model.dart';
import '../../widgets/employment_record_card.dart';
import '../../widgets/empty_state_widget.dart';

/// All employment records across every alumnus, newest first.
final allEmploymentRecordsProvider = StreamProvider<
    List<EmploymentRecord>>((ref) {
  return FirebaseFirestore.instance
      .collection(FirestoreCollections.employment)
      .snapshots()
      .map((snap) => snap.docs
          .map(EmploymentRecord.fromDoc)
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt)));
});

/// Brief user profiles (id -> data) used to label records with alumnus names.
final usersBriefProvider = StreamProvider<Map<String, Map<String, dynamic>>>(
    (ref) {
  return FirebaseFirestore.instance
      .collection(FirestoreCollections.users)
      .snapshots()
      .map((snap) => {for (final d in snap.docs) d.id: d.data()});
});

/// Admin aggregate view of all alumni employment history — read-only. Alumni
/// keep their own records up to date from their Employment screen; this list
/// groups those records by alumnus for the university's graduate tracking.
class EmploymentHistoryAdminScreen extends ConsumerWidget {
  const EmploymentHistoryAdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recordsAsync = ref.watch(allEmploymentRecordsProvider);
    final usersAsync = ref.watch(usersBriefProvider);
    final users = usersAsync.value ?? {};
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.surfaceDark : AppColors.surfaceLight;

    final grouped = <String, List<EmploymentRecord>>{};
    for (final r in recordsAsync.value ?? []) {
      grouped.putIfAbsent(r.userId, () => []).add(r);
    }
    final entries = grouped.entries.toList()
      ..sort((a, b) {
        final na = (users[a.key]?['fullName'] ?? '').toString().toLowerCase();
        final nb = (users[b.key]?['fullName'] ?? '').toString().toLowerCase();
        return na.compareTo(nb);
      });

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: Text(
          'Employment History',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : AppColors.primaryNavy,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(allEmploymentRecordsProvider),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: recordsAsync.when(
        data: (_) {
          if (entries.isEmpty) {
            return const EmptyStateWidget(
              icon: Icons.work_history_outlined,
              title: 'No Employment History Yet',
              message:
                  'Employment records shared by alumni will appear here for graduate tracking.',
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              Text(
                '${entries.length} alumni with employment \u2022 ${grouped.values.fold<int>(0, (s, l) => s + l.length)} records',
                style: GoogleFonts.poppins(
                  fontSize: 12.5,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 12),
              for (final entry in entries)
                _AlumnusSection(user: users[entry.key], records: entry.value),
              if (usersAsync.isLoading || usersAsync.hasError)
                const SizedBox(height: 12),
            ],
          );
        },
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primaryBlue)),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _AlumnusSection extends StatelessWidget {
  final Map<String, dynamic>? user;
  final List<EmploymentRecord> records;
  const _AlumnusSection({required this.user, required this.records});

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length > 1) return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    return name.isEmpty ? '?' : name[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final name = user?['fullName']?.toString() ?? 'Unknown alumnus';
    final email = user?['email']?.toString() ?? '';
    final rawCourse = user?['course']?.toString() ?? '';
    final course = rawCourse.trim().isEmpty ? AppStrings.defaultCourse : rawCourse;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => context.push('/staff/users/employment?userId=${records.first.userId}'),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withValues(alpha: isDark ? 0.15 : 0.07),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.primaryBlue.withValues(alpha: 0.20),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: AppColors.primaryBlue,
                  child: Text(
                    _initials(name),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : AppColors.primaryNavy,
                        ),
                      ),
                      Text(
                        [email, if (course.isNotEmpty) course]
                            .whereType<Object>()
                            .join(' • '),
                        style: GoogleFonts.poppins(
                          fontSize: 11.5,
                          color: isDark
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF64748B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(
                  records.any((r) => r.isCurrent)
                      ? Icons.work_rounded
                      : Icons.work_history_outlined,
                  size: 18,
                  color: records.any((r) => r.isCurrent)
                      ? AppColors.success
                      : AppColors.warning,
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right_rounded, size: 18),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        for (final r in records) EmploymentRecordCard(record: r),
        const SizedBox(height: 8),
      ],
    );
  }
}