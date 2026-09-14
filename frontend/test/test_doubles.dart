import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gradtracker/models/user_model.dart';
import 'package:gradtracker/providers/auth_providers.dart';
import 'package:gradtracker/repositories/user_repository.dart';
import 'package:gradtracker/services/api_client.dart';

export 'package:gradtracker/providers/auth_providers.dart'
    show userRepositoryProvider;

/// In-memory [UserRepository] stub for widget tests: no backend required.
class FakeUserRepository extends UserRepository {
  FakeUserRepository({
    this.registryResult,
    this.registryThrows = false,
    this.userResult,
  }) : super(api: ApiClient(baseUrl: 'http://localhost:1'));

  /// Returned by [fetchRegistryEntry]; null means "ID not in registry".
  final AlumniRegistryEntry? registryResult;

  /// When true, [fetchRegistryEntry] throws a connection-style error.
  final bool registryThrows;

  /// Returned by [fetchUser]/[watchUser].
  final UserModel? userResult;

  @override
  Future<AlumniRegistryEntry?> fetchRegistryEntry(String alumniId) async {
    if (registryThrows) {
      throw Exception('Connection refused');
    }
    return registryResult;
  }

  @override
  Future<UserModel?> fetchUser(String uid) async => userResult;

  @override
  Stream<UserModel?> watchUser(String uid) =>
      Stream<UserModel?>.value(userResult);

  @override
  Future<void> updateUser(String uid, Map<String, dynamic> changes) async {}

  @override
  Future<void> saveUser(UserModel user, {bool merge = true}) async {}
}

/// Pumps [child] inside a [ProviderScope] with the user repository stubbed.
Future<void> pumpWithFakeRepository(
  WidgetTester tester,
  FakeUserRepository fake,
  Widget child,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [userRepositoryProvider.overrideWithValue(fake)],
      child: MaterialApp(home: child),
    ),
  );
}
