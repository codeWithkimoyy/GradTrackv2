import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/employment_model.dart';
import '../repositories/employment_repository.dart';
import 'auth_providers.dart';

final employmentRepositoryProvider =
    Provider<EmploymentRepository>((ref) => EmploymentRepository());

/// Live employment history for the currently signed-in user.
final myEmploymentRecordsProvider = StreamProvider<List<EmploymentRecord>>((ref) {
  final user = ref.watch(currentUserProfileProvider).value;
  if (user == null) return Stream.value([]);
  return ref.watch(employmentRepositoryProvider).watchRecords(user.uid);
});

/// Live career milestones for the currently signed-in user.
final myCareerMilestonesProvider = StreamProvider<List<CareerMilestone>>((ref) {
  final user = ref.watch(currentUserProfileProvider).value;
  if (user == null) return Stream.value([]);
  return ref.watch(employmentRepositoryProvider).watchMilestones(user.uid);
});

/// The current (isCurrent == true) job, if any, derived from the records stream.
final currentJobProvider = Provider<EmploymentRecord?>((ref) {
  final records = ref.watch(myEmploymentRecordsProvider).value ?? [];
  for (final r in records) {
    if (r.isCurrent) return r;
  }
  return records.isNotEmpty ? records.first : null;
});

/// Family provider to watch another user's records/milestones — used by
/// coordinators/admins viewing a specific alumnus's profile.
final employmentRecordsForUserProvider =
    StreamProvider.family<List<EmploymentRecord>, String>((ref, userId) {
  return ref.watch(employmentRepositoryProvider).watchRecords(userId);
});

final milestonesForUserProvider =
    StreamProvider.family<List<CareerMilestone>, String>((ref, userId) {
  return ref.watch(employmentRepositoryProvider).watchMilestones(userId);
});
