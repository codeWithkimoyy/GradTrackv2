import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';
import 'auth_providers.dart';

final currentUserRoleProvider = Provider<UserRole?>((ref) {
  return ref.watch(currentUserProfileProvider).value?.role;
});

final isAdminProvider = Provider<bool>((ref) {
  return ref.watch(currentUserRoleProvider) == UserRole.admin;
});

final isCoordinatorProvider = Provider<bool>((ref) {
  return ref.watch(currentUserRoleProvider) == UserRole.coordinator;
});

final isStaffProvider = Provider<bool>((ref) {
  final role = ref.watch(currentUserRoleProvider);
  return role == UserRole.admin || role == UserRole.coordinator;
});

final isAlumniProvider = Provider<bool>((ref) {
  return ref.watch(currentUserRoleProvider) == UserRole.alumni;
});

final isGuestProvider = Provider<bool>((ref) {
  return ref.watch(currentUserRoleProvider) == UserRole.guest;
});
