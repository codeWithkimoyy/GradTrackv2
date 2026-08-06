import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';
import '../repositories/user_repository.dart';
import '../services/auth_service.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

/// Emits the raw FirebaseAuth user (null when signed out).
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

/// Holds a locally-saved profile, updated by edit screens when Firestore is
/// unavailable. The [currentUserProfileProvider] merges this into its stream.
final localProfileProvider = StateProvider<UserModel?>((_) => null);

/// Creates a local [UserModel] from raw FirebaseAuth user data as fallback.
UserModel _localProfileFromAuth(User u) => UserModel(
      uid: u.uid,
      email: u.email ?? '',
      fullName: u.displayName ?? '',
      role: UserRole.alumni,
      photoUrl: u.photoURL,
      emailVerified: u.emailVerified,
      createdAt: DateTime.now(),
    );

final userRepositoryProvider =
    Provider<UserRepository>((ref) => UserRepository());

/// Emits the Firestore profile document for the currently signed-in user,
/// falling back to a local profile when Firestore is unavailable.
final currentUserProfileProvider = StreamProvider<UserModel?>((ref) {
  final authState = ref.watch(authStateProvider);
  ref.watch(localProfileProvider);
  return authState.when(
    data: (authUser) async* {
      if (authUser == null) {
        yield null;
        return;
      }

      final fallback = _localProfileFromAuth(authUser);
      final localProfile = ref.read(localProfileProvider);

      if (localProfile != null && localProfile.uid == authUser.uid) {
        yield localProfile;
      } else {
        yield fallback;
      }

      final authService = ref.read(authServiceProvider);
      final userRepository = ref.read(userRepositoryProvider);
      try {
        await authService.ensureUserProfile(authUser.uid);
        await for (final profile in userRepository.watchUser(authUser.uid)) {
          yield profile ?? (localProfile ?? fallback);
        }
      } catch (_) {
        // Firestore unavailable – keep current yield.
      }
    },
    loading: () => Stream.value(null),
    error: (_, __) => Stream.value(null),
  );
});

/// Convenience bool provider for guards/UI.
final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(authStateProvider).value != null;
});
