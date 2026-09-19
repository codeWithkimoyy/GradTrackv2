import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../constants/app_constants.dart';
import '../../models/employment_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_providers.dart';
import '../../providers/employment_providers.dart';
import '../../widgets/batch_filter_widgets.dart';
import '../../widgets/employment_record_card.dart';
import '../../widgets/empty_state_widget.dart';

/// All employment records across every alumnus, newest first. Reads the
/// unified employment store (legacy records + the shared `jobs` collection),
/// so whatever alumni add in the Employment tab shows up here.
final allEmploymentRecordsProvider = StreamProvider<
    List<EmploymentRecord>>((ref) {
  return ref
      .watch(employmentRepositoryProvider)
      .watchAllRecords();
});

/// Brief user profiles (id -> profile) used to label records with alumnus
/// names. Scoped to the focus program (Computer Science); records whose
/// owner is unknown are kept since their program cannot be determined.
final usersBriefProvider =
    StreamProvider<Map<String, UserModel>>((ref) {
  return ref.watch(userRepositoryProvider).watchUsers(limit: 500).map(
      (users) => {
            for (final u in users)
              if (AppStrings.isFocusCourse(u.course)) u.uid: u
          });
});

/// Admin aggregate view of all alumni employment history — read-only. Alumni
/// keep their own records up to date from their Employment screen; this list
/// groups those records by graduation batch, then by alumnus, for the
/// university's graduate tracking.
class EmploymentHistoryAdminScreen extends ConsumerStatefulWidget {
  const EmploymentHistoryAdminScreen({super.key});

  @override
  ConsumerState<EmploymentHistoryAdminScreen> createState() =>
      _EmploymentHistoryAdminScreenState();
}

class _EmploymentHistoryAdminScreenState
    extends ConsumerState<EmploymentHistoryAdminScreen> {
  /// Selected graduation-batch filter key (`null` shows every batch).
  String? _selectedBatch;

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final recordsAsync = ref.watch(allEmploymentRecordsProvider);
    final usersAsync = ref.watch(usersBriefProvider);
    final users = usersAsync.value ?? {};
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.surfaceDark : AppColors.surfaceLight;

    final byUser = <String, List<EmploymentRecord>>{};
    for (final r in recordsAsync.value ?? []) {
      byUser.putIfAbsent(r.userId, () => []).add(r);
    }
    String batchKeyOf(String uid) {
      final user = users[uid];
      if (user == null) return '';
      return graduationBatchKey(
        academicYearGraduated: user.academicYearGraduated,
        graduationYear: user.graduationYear,
      );
    }

    // Alumni grouped by graduation batch (newest batches first,
    // unspecified last); names stay alphabetical inside each batch.
    final batchGroups = <String, List<String>>{};
    for (final uid in byUser.keys) {
      batchGroups.putIfAbsent(batchKeyOf(uid), () => []).add(uid);
    }
    for (final uids in batchGroups.values) {
      uids.sort((a, b) {
        final na = (users[a]?.fullName ?? '').toLowerCase();
        final nb = (users[b]?.fullName ?? '').toLowerCase();
        return na.compareTo(nb);
      });
    }
    final orderedBatches = batchGroups.keys.toList()
      ..sort((a, b) {
        final (aYear, _) = graduationBatchInfo(a);
        final (bYear, _) = graduationBatchInfo(b);
        if (aYear == null && bYear == null) return a.compareTo(b);
        if (aYear == null) return 1;
        if (bYear == null) return -1;
        return bYear.compareTo(aYear);
      });
    final visibleBatches = _selectedBatch == null
        ? orderedBatches
        : orderedBatches.where((k) => k == _selectedBatch).toList();
    final totalRecords =
        byUser.values.fold<int>(0, (sum, list) => sum + list.length);

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
          if (byUser.isEmpty) {
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
                '${byUser.length} alumni with employment \u2022 $totalRecords records \u2022 ${AppStrings.focusCourse}',
                style: GoogleFonts.poppins(
                  fontSize: 12.5,
                  color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String?>(
                initialValue: _selectedBatch,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Graduation Batch',
                  prefixIcon: Icon(Icons.school_outlined),
                ),
                items: [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Text('All batches (${byUser.length})'),
                  ),
                  for (final key in orderedBatches)
                    DropdownMenuItem<String?>(
                      value: key,
                      child: Text(
                          '${graduationBatchInfo(key).$2} (${batchGroups[key]!.length})'),
                    ),
                ],
                onChanged: (value) =>
                    setState(() => _selectedBatch = value),
              ),
              const SizedBox(height: 12),
              for (final batch in visibleBatches) ...[
                BatchSectionHeader(
                  label: graduationBatchInfo(batch).$2,
                  count: batchGroups[batch]!.length,
                ),
                for (final uid in batchGroups[batch]!)
                  _AlumnusSection(user: users[uid], records: byUser[uid]!),
              ],
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
  final UserModel? user;
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
    final name = (user?.fullName.isEmpty ?? true) ? 'Unknown alumnus' : user!.fullName;
    final email = user?.email ?? '';
    final rawCourse = user?.course ?? '';
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
                              : AppColors.textSecondary,
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
                      ? (isDark
                          ? AppColors.successLight
                          : AppColors.success)
                      : (isDark
                          ? AppColors.warningLight
                          : AppColors.warning),
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