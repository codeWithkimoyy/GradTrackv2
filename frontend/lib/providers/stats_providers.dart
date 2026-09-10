import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/stats_repository.dart';
import 'role_providers.dart';

final statsRepositoryProvider =
    Provider<StatsRepository>((ref) => StatsRepository());

/// Live staff-facing aggregate stats.
/// Admins see every role; non-admins are scoped to alumni records.
final staffStatsProvider =
    StreamProvider.autoDispose<DashboardStats>((ref) {
  final isAdmin = ref.watch(isAdminProvider);
  return ref
      .watch(statsRepositoryProvider)
      .watchStaffStats(adminScope: isAdmin);
});

/// High-performance one-shot server aggregate query
final aggregatedStaffStatsProvider =
    FutureProvider.autoDispose<DashboardStats>((ref) {
  final isAdmin = ref.watch(isAdminProvider);
  return ref
      .watch(statsRepositoryProvider)
      .fetchAggregatedStaffStats(adminScope: isAdmin);
});

/// Live survey progress for a specific alumni user.
final surveyProgressProvider =
    StreamProvider.family<SurveyProgress, String>((ref, userId) {
  return ref.watch(statsRepositoryProvider).watchSurveyProgress(userId);
});

/// Live alumni list grouped by academic year graduated (newest batch first).
final alumniBatchesProvider =
    StreamProvider.autoDispose<List<AlumniBatch>>((ref) {
  return ref.watch(statsRepositoryProvider).watchAlumniBatches();
});

/// Live announcement list (alumni view).
final announcementsProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  return ref.watch(statsRepositoryProvider).watchAnnouncements();
});

/// Live public announcement list (guest view).
final publicAnnouncementsProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  return ref
      .watch(statsRepositoryProvider)
      .watchAnnouncements(publicOnly: true);
});

/// Live pending-approval queue for the admin dashboard (newest first).
/// New registrations are auto-approved, so this stream only surfaces
/// pre-approval-era accounts and anyone an admin manually un-approves.
final pendingApprovalsProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  return ref.watch(statsRepositoryProvider).watchPendingApprovals();
});