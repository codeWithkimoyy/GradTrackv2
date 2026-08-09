import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../config/firebase_options.dart';
import '../models/user_model.dart';
import '../repositories/user_repository.dart';

/// Thin wrapper around FirebaseAuth + Firestore user-profile bootstrap.
/// Keeping auth transport logic separate from UI/state (Riverpod) layer.
class AuthService {
  FirebaseAuth? _auth;
  GoogleSignIn? _googleSignIn;
  final UserRepository _userRepository;

  bool get _firebaseConfigured => DefaultFirebaseOptions.isConfigured;

  FirebaseAuth get _requiredAuth {
    final auth = _auth;
    if (auth != null) return auth;
    throw StateError(
      'Firebase is not configured. Run flutterfire configure and populate assets/.env.',
    );
  }

  GoogleSignIn get _requiredGoogleSignIn {
    final googleSignIn = _googleSignIn;
    if (googleSignIn != null) return googleSignIn;
    throw StateError(
      'Firebase is not configured. Run flutterfire configure and populate assets/.env.',
    );
  }

  AuthService({
    FirebaseAuth? auth,
    GoogleSignIn? googleSignIn,
    UserRepository? userRepository,
  }) : _userRepository = userRepository ?? UserRepository() {
    if (_firebaseConfigured) {
      _auth = auth ?? FirebaseAuth.instance;
      _googleSignIn = googleSignIn ??
          GoogleSignIn(
            scopes: ['email'],
            clientId: kIsWeb ? dotenv.env['GOOGLE_SIGN_IN_CLIENT_ID'] : null,
          );
    }
  }

  Stream<User?> get authStateChanges {
    final auth = _auth;
    return auth?.authStateChanges() ?? Stream<User?>.value(null);
  }

  User? get currentUser => _auth?.currentUser;

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
      createdAt: DateTime.now(),
    );

    await _userRepository.saveUser(profile);
    return cred;
  }

  Future<UserCredential?> signInWithGoogle() async {
    if (!_firebaseConfigured) {
      throw StateError(
        'Firebase is not configured. Run flutterfire configure and populate assets/.env.',
      );
    }

    final googleSignIn = _requiredGoogleSignIn;

    if (kIsWeb) {
      final provider = GoogleAuthProvider();
      final userCred = await _requiredAuth.signInWithPopup(provider);
      await _ensureProfileForUser(userCred.user!);
      return userCred;
    }

    GoogleSignInAccount? googleUser;

    try {
      googleUser = await googleSignIn.signInSilently();
    } catch (_) {}

    googleUser ??= await googleSignIn.signIn();
    if (googleUser == null) return null;

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final userCred = await _requiredAuth.signInWithCredential(credential);
    await _ensureProfileForUser(userCred.user!);
    return userCred;
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
      photoUrl: user.photoURL,
      emailVerified: user.emailVerified,
      createdAt: DateTime.now(),
    );
    await _userRepository.saveUser(profile);
    return profile;
  }

  Future<void> _ensureProfileForUser(User user) async {
    try {
      final exists = await _userRepository.userExists(user.uid);
      if (exists) return;

      final profile = UserModel(
        uid: user.uid,
        email: user.email ?? '',
        fullName: user.displayName ?? '',
        role: UserRole.alumni,
        photoUrl: user.photoURL,
        emailVerified: user.emailVerified,
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
    await Future.wait([
      _requiredAuth.signOut(),
      _requiredGoogleSignIn.signOut(),
    ]);
  }

  Future<UserModel?> fetchUserProfile(String uid) async {
    return _userRepository.fetchUser(uid);
  }

  Stream<UserModel?> watchUserProfile(String uid) {
    return _userRepository.watchUser(uid);
  }

  /// Maps FirebaseAuthException codes to friendly, user-facing messages.
  static String friendlyError(Object error) {
    if (error is StateError &&
        error.message.contains('Firebase is not configured')) {
      return 'Firebase is not configured yet. Add the real project values to assets/.env or run flutterfire configure.';
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
        _ => error.message ?? 'Something went wrong. Please try again.',
      };
    }
    return 'Something went wrong. Please try again.';
  }
}
