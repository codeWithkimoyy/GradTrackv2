import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gradtracker/models/user_model.dart';
import 'package:gradtracker/providers/auth_providers.dart';
import 'package:gradtracker/providers/profile_edit_provider.dart';
import 'package:gradtracker/repositories/user_repository.dart';

class _CapturingUserRepository extends UserRepository {
  String? lastUid;
  Map<String, dynamic>? lastChanges;
  UserModel? lastSave;

  @override
  Future<void> updateUser(String uid, Map<String, dynamic> changes) async {
    lastUid = uid;
    lastChanges = changes;
  }

  @override
  Future<void> saveUser(UserModel user, {bool merge = true}) async {
    lastSave = user;
  }
}

void main() {
  test(
      'ProfileEditController.save writes academicYearGraduated and syncs graduationYear',
      () async {
    final repo = _CapturingUserRepository();
    final container = ProviderContainer(overrides: [
      userRepositoryProvider.overrideWithValue(repo),
    ]);
    addTearDown(container.dispose);

    final current = UserModel(
      uid: 'alumni1',
      email: 'alumni@example.com',
      fullName: 'Ana Reyes',
      role: UserRole.alumni,
      graduationYear: 2024,
      createdAt: DateTime.now(),
    );
    final updated = current.copyWith(
      course: 'BS Computer Science',
      academicYearGraduated: '2025-2026',
    );

    final result = await container
        .read(profileEditControllerProvider.notifier)
        .save(current: current, updated: updated);

    expect(result, isTrue);
    expect(repo.lastUid, 'alumni1');
    expect(repo.lastChanges, isNotNull);
    expect(repo.lastChanges!['course'], 'BS Computer Science');
    expect(repo.lastChanges!['academicYearGraduated'], '2025-2026');
    expect(repo.lastChanges!['graduationYear'], 2026);
    expect(repo.lastChanges!.keys, isNot(contains('role')));
  });
}