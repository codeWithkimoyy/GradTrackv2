import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/firebase_options.dart';
import '../models/user_model.dart';
import '../repositories/user_repository.dart';
import '../services/auth_service.dart';

final firebaseConfiguredProvider = Provider<bool>((_) {
  return DefaultFirebaseOptions.isConfigured && Firebase.apps.isNotEmpty;
});

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

/// Emits the raw FirebaseAuth user (null when signed out).
final authStateProvider = StreamProvider<User?>((ref) {
  if (!ref.watch(firebaseConfiguredProvider)) {
    return Stream<User?>.value(null);
  }
  return ref.watch(authServiceProvider).authStateChanges;
});

/// Holds a locally-saved profile, updated by edit screens when Firestore is
/// unavailable. The profile stream merges this into its result.
final localProfileProvider = StateProvider<UserModel?>((_) => null);

UserModel _localProfileFromAuth(User user) => UserModel(
      uid: user.uid,
      email: user.email ?? '',
      fullName: user.displayName ?? '',
      role: UserRole.alumni,
      photoUrl: user.photoURL,
      emailVerified: user.emailVerified,
      approved: false,
      createdAt: DateTime.now(),
    );

final userRepositoryProvider =
    Provider<UserRepository>((ref) => UserRepository());

/// Emits the Firestore profile for the signed-in user. A local profile keeps
/// role routing usable during temporary Firestore/network failures.
final currentUserProfileProvider = StreamProvider<UserModel?>((ref) {
  if (!ref.watch(firebaseConfiguredProvider)) {
    return Stream<UserModel?>.value(null);
  }

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
      final authService = ref.read(authServiceProvider);
      final userRepository = ref.read(userRepositoryProvider);

      // Emit the best data we already have immediately so the UI never
      // blocks on a slow or unreachable Firestore connection.
      yield (localProfile != null && localProfile.uid == authUser.uid)
          ? localProfile
          : fallback;

      // Best-effort profile bootstrap; never blocks the stream.
      authService.ensureUserProfile(authUser.uid).then(
            (_) {},
            onError: (_) {},
          );

      try {
        await for (final profile in userRepository.watchUser(authUser.uid)) {
          yield profile ?? fallback;
        }
      } catch (_) {
        // A single failed read (network blip / transient rule sync) used to
        // strand users on the pending-approval screen, so retry a few times
        // against the authoritative document before falling back.
        for (var attempt = 0; attempt < 3; attempt++) {
          await Future<void>.delayed(const Duration(seconds: 1) * (attempt + 1));
          try {
            final profile = await userRepository.fetchUser(authUser.uid);
            if (profile != null) {
              yield profile;
              return;
            }
          } catch (_) {
            // keep retrying
          }
        }
        yield fallback;
      }
    },
    loading: () => Stream.value(null),
    error: (_, __) => Stream.value(null),
  );
});

final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(authStateProvider).value != null;
});
