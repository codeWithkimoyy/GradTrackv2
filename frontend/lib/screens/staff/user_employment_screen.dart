import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../constants/app_constants.dart';
import '../../models/employment_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_providers.dart';
import '../../providers/employment_providers.dart';
import '../../widgets/employment_record_card.dart';
import '../../widgets/empty_state_widget.dart';

/// Reads a single user's profile from the backend.
final userDocByIdProvider =
    FutureProvider.autoDispose.family<UserModel?, String>((ref, userId) {
  return ref.watch(userRepositoryProvider).fetchUser(userId);
});

/// Read-only employment history for a specific alumnus — used by admins in
/// the user directory. Alumni add record data from their Employment screen;
/// this view only streams and renders it.
class UserEmploymentScreen extends ConsumerWidget {
  final String userId;
  const UserEmploymentScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recordsAsync = ref.watch(employmentRecordsForUserProvider(userId));
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.surfaceDark : AppColors.surfaceLight;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: Text(
          'Employment Records',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : AppColors.primaryNavy,
          ),
        ),
      ),
      body: Column(
        children: [
          _UserHeader(userId: userId),
          Expanded(
            child: recordsAsync.when(
              data: (records) => _RecordsList(records: records),
              loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.primaryBlue)),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    );
  }
}

class _UserHeader extends ConsumerWidget {
  final String userId;
  const _UserHeader({required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userDocByIdProvider(userId));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return userAsync.when(
      data: (user) {
        final name =
            (user?.fullName.isEmpty ?? true) ? 'Unknown' : user!.fullName;
        final email = user?.email ?? '';
        final course = user?.course ?? AppStrings.defaultCourse;
        final year = user?.graduationYear?.toString() ?? '';
        final rawBatch = user?.academicYearGraduated;
        final batchText =
            (rawBatch == null || rawBatch.trim().isEmpty)
                ? null
                : 'S.Y. ${displayAcademicYear(rawBatch)}';
        final status = user?.employmentStatus.label ??
            EmploymentStatusX.fromString('unemployed').label;

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardDark : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? AppColors.borderDark : AppColors.borderLight,
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.primaryBlue.withValues(alpha: 0.15),
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryBlue,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppColors.primaryNavy,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      email,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$course${year.isNotEmpty ? ' ($year)' : ''}'
                      '${batchText != null ? ' • $batchText' : ''} • $status',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppColors.primaryBlue,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox(height: 96),
      error: (_, __) => const SizedBox(height: 8),
    );
  }
}

class _RecordsList extends StatelessWidget {
  final List<EmploymentRecord> records;
  const _RecordsList({required this.records});

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.work_off_outlined,
        title: 'No Employment Records',
        message: 'This alumnus has not logged any employment history yet.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: records.length,
      itemBuilder: (context, i) => EmploymentRecordCard(record: records[i]),
    );
  }
}