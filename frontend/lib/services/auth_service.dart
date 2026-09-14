import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:google_sign_in/google_sign_in.dart';
import '../constants/app_constants.dart';
import '../models/auth_session.dart';
import '../models/user_model.dart';
import '../repositories/user_repository.dart';
import 'api_client.dart';
import 'password_reset_service.dart';

/// Session-backed auth against the GradTrack MySQL backend. Replaces the
/// Firebase Auth implementation: sign-in returns a bearer token that is
/// persisted in secure storage and restored on launch.
class AuthService {
  AuthService({
    ApiClient? api,
    UserRepository? userRepository,
    PasswordResetService? passwordResetService,
  })  : _api = api ?? ApiClient(),
        _userRepository =
            userRepository ?? UserRepository(api: api ?? ApiClient()),
        _passwordResetService = passwordResetService ??
            PasswordResetService(
                backendBaseUrl: (api ?? ApiClient()).baseUrl) {
    _controller = StreamController<AuthSession?>.broadcast(
      onListen: () {
        if (_current != null) _controller.add(_current);
      },
    );
  }

  final ApiClient _api;
  final UserRepository _userRepository;
  final PasswordResetService _passwordResetService;
  late final StreamController<AuthSession?> _controller;
  AuthSession? _current;

  static bool _googleInitDone = false;

  Stream<AuthSession?> get authStateChanges => _controller.stream;

  AuthSession? get currentSession => _current;

  UserModel? get currentUser => _current?.user;

  void _emit(AuthSession? session) {
    _current = session;
    if (!_controller.isClosed) _controller.add(session);
  }

  Future<void> dispose() => _controller.close();

  /// Restores a persisted session (if any) and validates it with the server.
  /// Returns the live session, or null when there is none / it expired.
  Future<AuthSession?> restoreSession() async {
    try {
      final saved = await _api.restoreSession();
      if (saved == null) {
        _emit(null);
        return null;
      }
      final raw = await _api.get('/api/auth/me');
      final user =
          UserModel.fromJson(Map<String, dynamic>.from(raw['user']), saved.uid);
      final session = AuthSession(token: saved.token, user: user);
      _emit(session);
      return session;
    } catch (e) {
      debugPrint('restoreSession: $e');
      await _api.clearSession();
      _emit(null);
      return null;
    }
  }

  /// Resolves the login identifier: emails are used as-is; anything else is
  /// treated as an Alumni ID and mapped to its synthesized login address.
  static String resolveIdentifier(String value) {
    final trimmed = value.trim();
    if (trimmed.contains('@')) return trimmed;
    return AppStrings.alumniEmailFromId(trimmed);
  }

  static String? alumniIdFromEmail(String? email) {
    if (email == null) return null;
    const suffix = AppStrings.alumniEmailSuffix;
    if (!email.toLowerCase().endsWith(suffix)) return null;
    final local = email.substring(0, email.length - suffix.length);
    return local.isEmpty ? null : local;
  }

  Future<AuthSession> _openSession(Map<String, dynamic> raw) async {
    final map = Map<String, dynamic>.from(raw);
    final userMap = Map<String, dynamic>.from(map['user']);
    final user = UserModel.fromJson(
        userMap, userMap['uid']?.toString() ?? '');
    final session =
        AuthSession(token: map['token']?.toString() ?? '', user: user);
    await _api.setSession(session.token, session.uid);
    _emit(session);
    return session;
  }

  Future<AuthSession> _startSession(Map<String, dynamic> body) async {
    final raw = await _api.post('/api/auth/login', body: body, auth: false);
    return _openSession(Map<String, dynamic>.from(raw));
  }

  Future<AuthSession> signInWithEmail({
    required String email,
    required String password,
  }) {
    return _startSession({
      'identifier': email.trim(),
      'password': password,
    });
  }

  /// Signs an alumni in with their Alumni ID + password.
  Future<AuthSession> signInWithAlumniId({
    required String alumniId,
    required String password,
  }) {
    return _startSession({
      'identifier': alumniId.trim(),
      'password': password,
    });
  }

  Future<AuthSession> _register(Map<String, dynamic> body) async {
    final raw = await _api.post('/api/auth/register', body: body, auth: false);
    return _openSession(Map<String, dynamic>.from(raw));
  }

  Future<AuthSession> registerWithEmail({
    required String email,
    required String password,
    required String fullName,
    required int graduationYear,
    required String course,
  }) {
    return _register({
      'email': email.trim(),
      'password': password,
      'fullName': fullName.trim(),
      'graduationYear': graduationYear,
      'course': course,
    });
  }

  /// Registers an alumni using their office-issued Alumni ID. The backend
  /// enforces the registry gate (Pending only) and activates the ID.
  Future<AuthSession> registerWithAlumniId({
    required String alumniId,
    required String password,
  }) async {
    final cleanId = alumniId.trim();
    if (cleanId.isEmpty || !AppStrings.alumniIdPattern.hasMatch(cleanId)) {
      throw StateError(
          'Alumni ID may only contain letters, numbers, hyphens and underscores.');
    }
    return _register({
      'alumniId': cleanId,
      'password': password,
    });
  }

  /// Google Sign-In backed by the MySQL database: the Google ID token is
  /// verified server-side (`POST /api/auth/google`) and linked to a
  /// GradTrack profile by verified email (created on first sign-in).
  Future<AuthSession> signInWithGoogle() async {
    final clientId = safeEnv('GOOGLE_SIGN_IN_CLIENT_ID');
    if (clientId == null) {
      throw StateError(
          'Google Sign-In is not configured. Add GOOGLE_SIGN_IN_CLIENT_ID to assets/.env.');
    }
    try {
      if (!_googleInitDone) {
        await GoogleSignIn.instance.initialize(
          clientId: clientId,
          serverClientId: clientId,
        );
        _googleInitDone = true;
      }
      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw StateError(
            'Google sign-in did not return an ID token. Please try again.');
      }
      final raw = await _api.post('/api/auth/google',
          body: {'idToken': idToken}, auth: false);
      return _openSession(Map<String, dynamic>.from(raw));
    } on GoogleSignInException catch (e) {
      // Keep the Google session clean when our backend rejects the token.
      try {
        await GoogleSignIn.instance.signOut();
      } catch (_) {}
      throw StateError(_googleErrorMessage(e));
    }
  }

  static String _googleErrorMessage(GoogleSignInException e) {
    final code = e.code.name;
    if (code == 'canceled') return 'Google sign-in was cancelled.';
    return 'Google sign-in failed ($code). Please try again.';
  }

  Future<UserModel?> ensureUserProfile(String uid) async {
    try {
      final user = await _userRepository.fetchUser(uid);
      if (user != null) return user;
    } catch (_) {
      // fall through to the session profile
    }
    return _current?.user;
  }

  /// Starts the email-code password reset flow via the backend.
  Future<void> sendPasswordResetEmail(String email) {
    return _passwordResetService.sendResetCode(email);
  }

  /// Email verification is handled at registration by the backend; kept as a
  /// no-op so existing call sites keep compiling.
  Future<void> sendEmailVerification() async {}

  /// Re-reads the profile from the server and refreshes the session.
  Future<void> reloadUser() async {
    final current = _current;
    if (current == null) return;
    final raw = await _api.get('/api/auth/me');
    final user = UserModel.fromJson(
        Map<String, dynamic>.from(raw['user']), current.uid);
    _emit(current.copyWith(user: user));
  }

  Future<void> signOut() async {
    try {
      await _api.post('/api/auth/logout');
    } catch (_) {
      // Best-effort: always clear the local session.
    }
    try {
      if (_googleInitDone) await GoogleSignIn.instance.signOut();
    } catch (_) {}
    await _api.clearSession();
    _emit(null);
  }

  Future<UserModel?> fetchUserProfile(String uid) {
    return _userRepository.fetchUser(uid);
  }

  Stream<UserModel?> watchUserProfile(String uid) {
    return _userRepository.watchUser(uid);
  }

  /// Maps exceptions to friendly, actionable, user-facing error messages.
  static String friendlyError(Object error) {
    if (error is StateError) {
      return error.message;
    }
    return ApiException.friendlyMessage(error);
  }
}
