import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gradtracker/models/auth_session.dart';
import 'package:gradtracker/models/user_model.dart';
import 'package:gradtracker/services/api_client.dart';
import 'package:gradtracker/services/auth_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, dynamic> _userJson() => {
      'uid': 'user-1',
      'email': 'alumni@gradtrack.edu.ph',
      'fullName': 'Demo Alumni',
      'role': 'alumni',
      'employmentStatus': 'unemployed',
      'isVerified': true,
      'emailVerified': true,
      'disabled': false,
      'approved': true,
      'hasLoggedIn': true,
      'lastLoginAt': '2026-09-14 12:00:00',
      'profileCompletion': 42.0,
      'createdAt': '2026-09-01 10:00:00',
      'updatedAt': '2026-09-14 12:00:00',
    };

ApiClient _clientFor(Map<String, http.Response Function(http.Request)> routes) {
  final mock = MockClient((request) async {
    final key = '${request.method} ${request.url.path}';
    final handler = routes[key];
    if (handler == null) {
      return http.Response('{"error":"not_found","message":"nope"}', 404);
    }
    return handler(request);
  });
  return ApiClient(
    baseUrl: 'http://localhost:1',
    httpClient: mock,
    storage: const FlutterSecureStorage(),
  );
}

void main() {
  group('AuthService MySQL login flow', () {
    test('signInWithEmail stores the session and emits it', () async {
      final api = _clientFor({
        'POST /api/auth/login': (request) {
          final body = jsonDecode(request.body) as Map;
          expect(body['identifier'], 'alumni@gradtrack.edu.ph');
          expect(body['password'], 'alumni123');
          return http.Response(
            jsonEncode({'token': 'tok-123', 'user': _userJson()}),
            200,
          );
        },
      });
      final auth = AuthService(api: api);
      addTearDown(auth.dispose);

      final events = <dynamic>[];
      final sub = auth.authStateChanges.listen(events.add);

      final session = await auth.signInWithEmail(
        email: 'alumni@gradtrack.edu.ph',
        password: 'alumni123',
      );

      expect(session.token, 'tok-123');
      expect(session.user, isA<UserModel>());
      expect(session.user.fullName, 'Demo Alumni');
      expect(session.user.profileCompletion, 42.0);
      expect(session.user.lastLoginAt, isNotNull);
      expect(auth.currentUser?.uid, 'user-1');
      await Future<void>.delayed(Duration.zero);
      expect(events.whereType<AuthSession>(), isNotEmpty);

      await sub.cancel();
    });

    test('signInWithEmail surfaces invalid credentials as a message',
        () async {
      final api = _clientFor({
        'POST /api/auth/login': (_) => http.Response(
              jsonEncode({
                'error': 'invalid_credentials',
                'message': 'Invalid email or password.',
              }),
              401,
            ),
      });
      final auth = AuthService(api: api);
      addTearDown(auth.dispose);

      try {
        await auth.signInWithEmail(
            email: 'nobody@example.com', password: 'wrong12');
        fail('expected an exception');
      } catch (e) {
        expect(AuthService.friendlyError(e), 'Invalid email or password.');
      }
      expect(auth.currentSession, isNull);
    });

    test('signOut clears the session and emits null', () async {
      final api = _clientFor({
        'POST /api/auth/login': (_) => http.Response(
              jsonEncode({'token': 'tok-123', 'user': _userJson()}),
              200,
            ),
        'POST /api/auth/logout': (_) => http.Response('{"message":"ok"}', 200),
      });
      final auth = AuthService(api: api);
      addTearDown(auth.dispose);

      await auth.signInWithEmail(
          email: 'alumni@gradtrack.edu.ph', password: 'alumni123');
      expect(auth.currentSession, isNotNull);

      final events = <dynamic>[];
      final sub = auth.authStateChanges.listen(events.add);
      await auth.signOut();
      await Future<void>.delayed(Duration.zero);

      expect(auth.currentSession, isNull);
      expect(events.last, isNull);
      await sub.cancel();
    });
  });
}
