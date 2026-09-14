import 'dart:convert';
import 'package:http/http.dart' as http;

import 'api_client.dart' show safeEnv;

/// Sends/verifies the 6-digit password-reset code through the GradTrack
/// backend, which emails the code and performs the password update.
class PasswordResetService {
  PasswordResetService({String? backendBaseUrl})
      : _backendBaseUrl = (backendBaseUrl ??
                safeEnv('BACKEND_API_URL') ??
                'http://localhost:3000')
            .replaceAll(RegExp(r'/$'), '');

  final String _backendBaseUrl;

  Future<void> sendResetCode(String email) async {
    final response = await http
        .post(
          Uri.parse('$_backendBaseUrl/api/auth/forgot-password'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email.trim()}),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw PasswordResetException(_messageFrom(response));
    }
  }

  Future<void> verifyCode({
    required String email,
    required String code,
  }) async {
    final response = await http
        .post(
          Uri.parse('$_backendBaseUrl/api/auth/verify-code'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email.trim(), 'code': code.trim()}),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw PasswordResetException(_messageFrom(response));
    }
  }

  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    final response = await http
        .post(
          Uri.parse('$_backendBaseUrl/api/auth/reset-password'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'email': email.trim(),
            'code': code.trim(),
            'newPassword': newPassword,
          }),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw PasswordResetException(_messageFrom(response));
    }
  }

  String _messageFrom(http.Response response) {
    try {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (decoded['message'] is String) {
        return decoded['message'] as String;
      }
    } catch (_) {}
    if (response.statusCode >= 500) {
      return 'The password reset service is temporarily unavailable. '
          'Please try again later.';
    }
    return 'Something went wrong. Please try again.';
  }
}

class PasswordResetException implements Exception {
  final String message;
  PasswordResetException(this.message);

  @override
  String toString() => message;
}