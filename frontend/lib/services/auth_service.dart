import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import '../config/firebase_options.dart';
import '../constants/app_constants.dart';
import '../models/user_model.dart';
import '../repositories/user_repository.dart';

/// Thin wrapper around FirebaseAuth + Firestore user-profile bootstrap.
/// Keeping auth transport logic separate from UI/state (Riverpod) layer.
class AuthService {
  FirebaseAuth? _auth;
  final UserRepository _userRepository;

  bool get _firebaseConfigured =>
      DefaultFirebaseOptions.isConfigured && Firebase.apps.isNotEmpty;

  FirebaseAuth get _requiredAuth {
    final auth = _auth;
    if (auth != null) return auth;
    throw StateError(
      'Firebase is not configured. Run flutterfire configure and populate assets/.env.',
    );
  }

  AuthService({
    FirebaseAuth? auth,
    UserRepository? userRepository,
  }) : _userRepository = userRepository ?? UserRepository() {
    if (_firebaseConfigured) {
      _auth = auth ?? FirebaseAuth.instance;
    }
  }

  Stream<User?> get authStateChanges {
    final auth = _auth;
    return auth?.authStateChanges() ?? Stream<User?>.value(null);
  }

  User? get currentUser => _auth?.currentUser;

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

  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final cred = await _requiredAuth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    await _ensureProfileForUser(cred.user!);
    return cred;
  }

  /// Signs an alumni in with their Alumni ID + password.
  Future<UserCredential> signInWithAlumniId({
    required String alumniId,
    required String password,
  }) {
    return signInWithEmail(
      email: AppStrings.alumniEmailFromId(alumniId.trim()),
      password: password,
    );
  }

  Future<UserCredential> registerWithEmail({
    required String email,
    required String password,
    required String fullName,
    required int graduationYear,
    required String course,
  }) async {
    final cred = await _requiredAuth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    await cred.user?.updateDisplayName(fullName);
    await cred.user?.sendEmailVerification();

    final profile = UserModel(
      uid: cred.user!.uid,
      email: email,
      fullName: fullName,
      role: UserRole.alumni,
      graduationYear: graduationYear,
      course: course,
      approved: true,
      createdAt: DateTime.now(),
    );

    await _userRepository.saveUser(profile);
    return cred;
  }

  /// Registers an alumni using their office-issued Alumni ID. The account is
  /// created against the ID's synthesized login address. Registration is only
  /// accepted for IDs the administrator added to the registry (Pending status);
  /// the account becoming Active is re-checked here so a stale verification
  /// page can never bypass the registry.
  Future<UserCredential> registerWithAlumniId({
    required String alumniId,
    required String password,
  }) async {
    final cleanId = alumniId.trim();
    if (cleanId.isEmpty || !AppStrings.alumniIdPattern.hasMatch(cleanId)) {
      throw StateError(
          'Alumni ID may only contain letters, numbers, hyphens and underscores.');
    }

    final entry = await _userRepository.fetchRegistryEntry(cleanId);
    if (entry == null) {
      throw StateError(
          'Alumni ID not found. Please contact the Tracer Study Administrator.');
    }
    if (entry.status == AlumniAccountStatus.active) {
      throw StateError(
          'This Alumni ID is already registered. Please sign in.');
    }
    if (entry.status == AlumniAccountStatus.disabled) {
      throw StateError(
          'This Alumni ID has been disabled. Please contact the Tracer Study Administrator.');
    }

    final cred = await _requiredAuth.createUserWithEmailAndPassword(
      email: AppStrings.alumniEmailFromId(cleanId),
      password: password,
    );

    await cred.user?.updateDisplayName(entry.fullName);

    final profile = UserModel(
      uid: cred.user!.uid,
      email: AppStrings.alumniEmailFromId(cleanId),
      fullName: entry.fullName,
      role: UserRole.alumni,
      alumniId: cleanId,
      course: entry.course,
      graduationYear: entry.graduationYear,
      approved: true,
      emailVerified: false,
      createdAt: DateTime.now(),
    );

    await _userRepository.saveUser(profile);
    await _userRepository.updateRegistryStatus(
      cleanId,
      AlumniAccountStatus.active,
      activatedAt: DateTime.now(),
    );
    return cred;
  }

  Future<UserModel?> ensureUserProfile(String uid) async {
    final existing = await _userRepository.fetchUser(uid);
    if (existing != null) return existing;
    final user = _auth?.currentUser;
    if (user == null) return null;
    final profile = UserModel(
      uid: uid,
      email: user.email ?? '',
      fullName: user.displayName ?? '',
      role: UserRole.alumni,
      alumniId: alumniIdFromEmail(user.email),
      photoUrl: user.photoURL,
      emailVerified: user.emailVerified,
      approved: true,
      createdAt: DateTime.now(),
    );
    await _userRepository.saveUser(profile);
    return profile;
  }

  Future<void> _ensureProfileForUser(User user) async {
    try {
      final exists = await _userRepository.userExists(user.uid);
      if (exists) {
        // Mark this sign-in so the admin batch dashboard can list alumni
        // (hasLoggedIn == true) and backfill the graduation batch year from
        // the academic year when it was never stored.
        final existing = await _userRepository.fetchUser(user.uid);
        final changes = <String, dynamic>{
          'hasLoggedIn': true,
          'lastLoginAt': FieldValue.serverTimestamp(),
        };
        if (existing?.graduationYear == null) {
          final start = academicYearStart(existing?.academicYearGraduated);
          if (start != null) changes['graduationYear'] = start;
        }
        await _userRepository.updateUser(user.uid, changes);
        return;
      }

      final profile = UserModel(
        uid: user.uid,
        email: user.email ?? '',
        fullName: user.displayName ?? '',
        role: UserRole.alumni,
        alumniId: alumniIdFromEmail(user.email),
        photoUrl: user.photoURL,
        emailVerified: user.emailVerified,
        approved: true,
        hasLoggedIn: true,
        lastLoginAt: DateTime.now(),
        createdAt: DateTime.now(),
      );
      await _userRepository.saveUser(profile);
    } catch (e) {
      debugPrint('Firestore unavailable during login: $e');
      // Allow login to continue even if Firestore is blocked.
      // The profile stream will retry when Firestore becomes available.
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    await _requiredAuth.sendPasswordResetEmail(email: email);
  }

  Future<void> sendEmailVerification() async {
    await _requiredAuth.currentUser?.sendEmailVerification();
  }

  Future<void> reloadUser() async {
    await _requiredAuth.currentUser?.reload();
  }

  Future<void> signOut() async {
    await _requiredAuth.signOut();
  }

  Future<UserModel?> fetchUserProfile(String uid) async {
    return _userRepository.fetchUser(uid);
  }

  Stream<UserModel?> watchUserProfile(String uid) {
    return _userRepository.watchUser(uid);
  }

  /// Maps exceptions to friendly, actionable, user-facing error messages.
  static String friendlyError(Object error) {
    if (error is StateError) {
      if (error.message.contains('Firebase is not configured')) {
        return 'Firebase is not configured yet. Run flutterfire configure or populate assets/.env.';
      }
      return error.message;
    }

    final String errStr = error.toString();

    if (errStr.contains('invalid-api-key') ||
        errStr.contains('api-key-not-valid')) {
      return 'Firebase API key is invalid or placeholder. Run flutterfire configure.';
    }

    if (error is FirebaseAuthException) {
      return switch (error.code) {
        'user-not-found' => 'No account found with this email.',
        'wrong-password' => 'Incorrect password. Please try again.',
        'invalid-credential' => 'Invalid email or password.',
        'email-already-in-use' => 'An account already exists for this email.',
        'weak-password' => 'Password should be at least 6 characters.',
        'invalid-email' => 'Please enter a valid email address.',
        'too-many-requests' => 'Too many attempts. Please try again later.',
        'network-request-failed' => 'Network error. Check your connection.',
        _ => error.message ?? 'Authentication error (${error.code}).',
      };
    }

    if (error is Exception) {
      final msg = error.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
      return msg.isNotEmpty ? msg : 'An error occurred during authentication.';
    }

    return error.toString();
  }
}
