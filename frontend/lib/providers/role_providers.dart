import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';
import 'auth_providers.dart';

final currentUserRoleProvider = Provider<UserRole?>((ref) {
  return ref.watch(currentUserProfileProvider).value?.role;
});

final isAdminProvider = Provider<bool>((ref) {
  return ref.watch(currentUserRoleProvider) == UserRole.admin;
});

final isStaffProvider = Provider<bool>((ref) {
  return ref.watch(currentUserRoleProvider) == UserRole.admin;
});

final isAlumniProvider = Provider<bool>((ref) {
  return ref.watch(currentUserRoleProvider) == UserRole.alumni;
});
