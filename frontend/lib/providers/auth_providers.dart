import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/auth_session.dart';
import '../models/user_model.dart';
import '../repositories/user_repository.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

final authServiceProvider = Provider<AuthService>((ref) {
  final service = AuthService(api: ref.watch(apiClientProvider));
  ref.onDispose(() => unawaited(service.dispose()));
  return service;
});

/// Emits the current session (null when signed out).
final authStateProvider = StreamProvider<AuthSession?>((ref) {
  final service = ref.watch(authServiceProvider);
  service.ensureInitialState();
  return service.authStateChanges;
});

/// Holds a locally-saved profile, updated by edit screens when the backend
/// is unavailable. The profile stream merges this into its result.
final localProfileProvider = StateProvider<UserModel?>((_) => null);

UserModel _localProfileFromSession(UserModel user) => UserModel(
      uid: user.uid,
      email: user.email,
      fullName: user.fullName,
      role: UserRole.alumni,
      photoUrl: user.photoUrl,
      emailVerified: user.emailVerified,
      approved: true,
      createdAt: DateTime.now(),
    );

final userRepositoryProvider =
    Provider<UserRepository>((ref) => UserRepository(api: ref.watch(apiClientProvider)));

/// Emits the profile for the signed-in user: the session profile first, then
/// server refreshes on a short poll. A local profile keeps role routing
/// usable during temporary backend/network failures.
final currentUserProfileProvider = StreamProvider<UserModel?>((ref) {
  final authState = ref.watch(authStateProvider);
  ref.watch(localProfileProvider);

  final session = authState.valueOrNull;
  if (session == null) return Stream<UserModel?>.value(null);

  final repo = ref.watch(userRepositoryProvider);
  return Stream<UserModel?>.multi((controller) {
    var closed = false;

    Future<void> refresh({bool bootstrap = false}) async {
      if (closed || controller.isClosed) return;
      try {
        final profile = await repo.fetchUser(session.uid);
        if (closed || controller.isClosed) return;
        if (profile != null) {
          controller.add(profile);
        } else if (bootstrap) {
          // Server has no row (yet): fall back to the session profile so
          // routing never strands a signed-in user on a blank screen.
          final local = ref.read(localProfileProvider);
          controller.add(
            (local != null && local.uid == session.uid)
                ? local
                : _localProfileFromSession(session.user),
          );
        }
      } catch (_) {
        if (bootstrap && !closed && !controller.isClosed) {
          final local = ref.read(localProfileProvider);
          controller.add(
            (local != null && local.uid == session.uid)
                ? local
                : _localProfileFromSession(session.user),
          );
        }
      }
    }

    // Emit the best data we already have immediately so the UI never
    // blocks on a slow or unreachable backend connection.
    final local = ref.read(localProfileProvider);
    controller.add(
      (local != null && local.uid == session.uid)
          ? local
          : session.user,
    );
    unawaited(refresh(bootstrap: true));
    final timer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => refresh(),
    );
    controller.onCancel = () {
      closed = true;
      timer.cancel();
    };
  });
});

final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(authStateProvider).value != null;
});
