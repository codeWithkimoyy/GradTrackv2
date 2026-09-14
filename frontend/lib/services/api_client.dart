import 'dart:async';
import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

/// Reads a dotenv value without throwing when dotenv was never loaded
/// (e.g. in unit tests). Returns null when unavailable or empty.
String? safeEnv(String key) {
  try {
    final value = dotenv.env[key];
    if (value == null || value.isEmpty) return null;
    return value;
  } catch (_) {
    return null;
  }
}

/// Error thrown for failed GradTrack backend requests. [code] mirrors the
/// backend `error` field (e.g. `invalid_credentials`, `not_found`).
class ApiException implements Exception {
  final int statusCode;
  final String code;
  final String message;

  const ApiException({
    required this.statusCode,
    required this.code,
    required this.message,
  });

  @override
  String toString() => message;

  /// User-facing message for the most common backend failures.
  static String friendlyMessage(Object error) {
    if (error is ApiException) {
      switch (error.code) {
        case 'invalid_credentials':
          return 'Invalid email or password.';
        case 'account_disabled':
          return 'This account has been disabled. Please contact the Tracer Study Administrator.';
        case 'already_registered':
          return 'This Alumni ID is already registered. Please sign in.';
        case 'alumni_id_not_found':
          return 'Alumni ID not found. Please contact the Tracer Study Administrator.';
        case 'alumni_id_disabled':
          return 'This Alumni ID has been disabled. Please contact the Tracer Study Administrator.';
        case 'email_in_use':
          return 'An account already exists for this email.';
        case 'weak_password':
          return 'Password should be at least 6 characters.';
        case 'invalid_email':
          return 'Please enter a valid email address.';
        case 'missing_token':
        case 'invalid_token':
          return 'Your session expired. Please sign in again.';
        case 'forbidden':
          return 'This action requires an administrator account.';
        case 'user_not_found':
        case 'no_account':
          return 'No account found with this email.';
        case 'no_code':
          return 'No reset request was found for this email. Request a new code.';
        case 'code_used':
          return 'This code has already been used. Request a new code.';
        case 'code_expired':
          return 'This code has expired. Request a new code.';
        case 'invalid_code':
          return 'That code is incorrect. Please check and try again.';
        case 'email_not_configured':
          return 'Password reset email is not configured. Contact the administrator.';
        case 'google_not_configured':
          return 'Google Sign-In is not configured on the server. Contact the administrator.';
        case 'google_unreachable':
          return 'Could not reach Google to verify the sign-in. Try again.';
        case 'email_not_verified':
          return 'Your Google account email is not verified.';
        case 'not_found':
          return error.message.isNotEmpty ? error.message : 'Not found.';
      }
      return error.message.isNotEmpty ? error.message : 'Request failed (${error.statusCode}).';
    }
    if (error is TimeoutException) {
      return 'Network error. Check your connection.';
    }
    final text = error.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
    if (text.contains('SocketException') ||
        text.contains('Connection refused') ||
        text.contains('Failed host lookup')) {
      return 'Cannot reach the GradTrack server. Check your connection.';
    }
    return text.isNotEmpty ? text : 'An unexpected error occurred.';
  }
}

/// HTTP client for the GradTrack MySQL backend. The session token is kept in
/// secure storage and attached as `Authorization: Bearer <token>`.
class ApiClient {
  ApiClient({
    String? baseUrl,
    http.Client? httpClient,
    FlutterSecureStorage? storage,
  })  : _baseUrl = (baseUrl ?? safeEnv('BACKEND_API_URL') ?? 'http://localhost:3000')
            .replaceAll(RegExp(r'/$'), ''),
        _http = httpClient ?? http.Client(),
        _storage = storage ?? const FlutterSecureStorage();

  static const String tokenKey = 'gt_session_token';
  static const String uidKey = 'gt_session_uid';
  static const Duration defaultTimeout = Duration(seconds: 20);

  final String _baseUrl;
  final http.Client _http;
  final FlutterSecureStorage _storage;

  String? _token;
  String? _currentUid;

  String get baseUrl => _baseUrl;
  String? get currentToken => _token;
  String? get currentUid => _currentUid;

  Map<String, String> _headers({bool auth = true}) {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (auth && _token != null) {
      headers['Authorization'] = 'Bearer $_token';
    }
    return headers;
  }

  Uri _uri(String path, [Map<String, String>? query]) {
    final normalized = path.startsWith('/') ? path : '/$path';
    final base = Uri.parse('$_baseUrl$normalized');
    if (query == null || query.isEmpty) return base;
    return base.replace(
      queryParameters: {...base.queryParameters, ...query},
    );
  }

  Never _throwForStatus(int status, String body) {
    String code = 'request_failed';
    String message = 'Request failed ($status).';
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        if (decoded['error'] is String) code = decoded['error'] as String;
        if (decoded['message'] is String) {
          message = decoded['message'] as String;
        }
      }
    } catch (_) {}
    throw ApiException(statusCode: status, code: code, message: message);
  }

  Future<dynamic> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
    bool auth = true,
    Duration timeout = defaultTimeout,
  }) async {
    // Retry transport-level failures (dropped connections, timeouts) —
    // never HTTP error statuses. Reads retry twice; writes retry once
    // (an orphaned write is harmless: sessions are idempotent client-side
    // and creates are user-confirmed on failure).
    final attempts = method == 'GET' ? 3 : 2;
    Object? lastError;
    for (var attempt = 0; attempt < attempts; attempt++) {
      try {
        return await _attempt(method, path,
            query: query, body: body, auth: auth, timeout: timeout);
      } on ApiException {
        rethrow;
      } catch (e) {
        lastError = e;
        if (attempt + 1 < attempts) {
          await Future<void>.delayed(
              Duration(milliseconds: 400 * (attempt + 1)));
        }
      }
    }
    throw lastError ?? const ApiException(
      statusCode: 0,
      code: 'network_error',
      message: 'Cannot reach the GradTrack server.',
    );
  }

  Future<dynamic> _attempt(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
    bool auth = true,
    Duration timeout = defaultTimeout,
  }) async {
    final request = http.Request(method, _uri(path, query))
      ..headers.addAll(_headers(auth: auth));
    if (body != null) {
      request.body = body is String ? body : jsonEncode(body);
    }
    final streamed =
        await _http.send(request).timeout(timeout);
    final text = await streamed.stream.bytesToString();
    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      _throwForStatus(streamed.statusCode, text);
    }
    if (text.isEmpty) return null;
    try {
      return jsonDecode(text);
    } catch (_) {
      return text;
    }
  }

  Future<dynamic> get(String path,
          {Map<String, String>? query, bool auth = true}) =>
      _send('GET', path, query: query, auth: auth);

  Future<dynamic> post(String path,
          {Object? body, Map<String, String>? query, bool auth = true}) =>
      _send('POST', path, query: query, body: body, auth: auth);

  Future<dynamic> patch(String path,
          {Object? body, Map<String, String>? query, bool auth = true}) =>
      _send('PATCH', path, query: query, body: body, auth: auth);

  Future<dynamic> put(String path,
          {Object? body, Map<String, String>? query, bool auth = true}) =>
      _send('PUT', path, query: query, body: body, auth: auth);

  Future<dynamic> delete(String path,
          {Object? body, Map<String, String>? query, bool auth = true}) =>
      _send('DELETE', path, query: query, body: body, auth: auth);

  Future<void> setSession(String token, String uid) async {
    _token = token;
    _currentUid = uid;
    try {
      await _storage.write(key: tokenKey, value: token);
      await _storage.write(key: uidKey, value: uid);
    } catch (_) {
      // Secure storage can be unavailable (tests, locked keychain, web
      // private mode): the in-memory session above still keeps the user
      // signed in for this launch.
    }
  }

  Future<void> clearSession() async {
    _token = null;
    _currentUid = null;
    try {
      await _storage.delete(key: tokenKey);
      await _storage.delete(key: uidKey);
    } catch (_) {}
  }

  /// Restores a persisted session (token + uid) without validating it; the
  /// caller should call `GET /api/auth/me` to confirm it is still valid.
  Future<({String token, String uid})?> restoreSession() async {
    String? token;
    String? uid;
    try {
      token = await _storage.read(key: tokenKey);
      uid = await _storage.read(key: uidKey);
    } catch (_) {
      return null;
    }
    if (token == null || token.isEmpty || uid == null || uid.isEmpty) {
      return null;
    }
    _token = token;
    _currentUid = uid;
    return (token: token, uid: uid);
  }

  /// Emits [fetch] immediately, then re-fetches every [interval]. Replaces
  /// the live Firestore streams used before the MySQL migration.
  Stream<T> poll<T>(
    Future<T> Function() fetch, {
    Duration interval = const Duration(seconds: 30),
  }) {
    return Stream<T>.multi((controller) {
      var closed = false;
      Future<void> tick() async {
        if (closed || controller.isClosed) return;
        try {
          final value = await fetch();
          if (!closed && !controller.isClosed) controller.add(value);
        } catch (e, st) {
          if (!closed && !controller.isClosed) controller.addError(e, st);
        }
      }

      unawaited(tick());
      final timer = Timer.periodic(interval, (_) => tick());
      controller.onCancel = () async {
        closed = true;
        timer.cancel();
      };
    });
  }
}
