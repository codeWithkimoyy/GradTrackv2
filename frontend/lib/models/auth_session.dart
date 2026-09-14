import 'user_model.dart';

/// Authenticated session: the backend bearer token plus the signed-in profile.
/// Replaces Firebase's `User`/`UserCredential` after the MySQL migration.
class AuthSession {
  final String token;
  final UserModel user;

  const AuthSession({required this.token, required this.user});

  String get uid => user.uid;

  AuthSession copyWith({String? token, UserModel? user}) {
    return AuthSession(token: token ?? this.token, user: user ?? this.user);
  }
}
