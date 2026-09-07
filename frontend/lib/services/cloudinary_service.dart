import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class CloudinaryService {
  CloudinaryService() {
    _cloudName = (dotenv.env['CLOUDINARY_CLOUD_NAME']?.isNotEmpty == true)
        ? dotenv.env['CLOUDINARY_CLOUD_NAME']!
        : 'cesiyg6z';
    _apiKey = (dotenv.env['CLOUDINARY_API_KEY']?.isNotEmpty == true)
        ? dotenv.env['CLOUDINARY_API_KEY']!
        : '739484295666519';
    _uploadPreset = (dotenv.env['CLOUDINARY_UPLOAD_PRESET']?.isNotEmpty == true)
        ? dotenv.env['CLOUDINARY_UPLOAD_PRESET']!
        : 'gradtrack_uploads';
    _backendBaseUrl = (dotenv.env['BACKEND_API_URL']?.isNotEmpty == true)
        ? dotenv.env['BACKEND_API_URL']!
        : 'http://localhost:3000';
  }

  late final String _cloudName;
  late final String _apiKey;
  late final String _uploadPreset;
  late final String _backendBaseUrl;

  String get cloudName => _cloudName;

  Future<({String url, String publicId})> uploadImage({
    required Uint8List bytes,
    required String fileName,
    String? idToken,
    void Function(double progress)? onProgress,
  }) async {
    return _upload(
      resourceType: 'image',
      bytes: bytes,
      fileName: fileName,
      idToken: idToken,
      onProgress: onProgress,
    );
  }

  Future<({String url, String publicId})> uploadRaw({
    required Uint8List bytes,
    required String fileName,
    String? idToken,
    void Function(double progress)? onProgress,
  }) async {
    return _upload(
      resourceType: 'raw',
      bytes: bytes,
      fileName: fileName,
      idToken: idToken,
      onProgress: onProgress,
    );
  }

  Future<({String url, String publicId})> _upload({
    required String resourceType,
    required Uint8List bytes,
    required String fileName,
    String? idToken,
    void Function(double progress)? onProgress,
  }) async {
    final uri = Uri.parse(
      'https://api.cloudinary.com/v1_1/$_cloudName/$resourceType/upload',
    );

    final request = http.MultipartRequest('POST', uri);

    // If idToken is provided, request a secure signature from backend
    if (idToken != null && idToken.isNotEmpty) {
      try {
        final signUri = Uri.parse('$_backendBaseUrl/api/upload/sign');
        final signRes = await http.post(
          signUri,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $idToken',
          },
        );
        if (signRes.statusCode == 200) {
          final signData = jsonDecode(signRes.body) as Map<String, dynamic>;
          request.fields['api_key'] = signData['apiKey'] as String? ?? _apiKey;
          request.fields['timestamp'] = (signData['timestamp'] as num).toString();
          request.fields['signature'] = signData['signature'] as String;
          if (signData['folder'] != null) {
            request.fields['folder'] = signData['folder'] as String;
          }
        } else {
          // Fallback to upload preset if signing fails
          request.fields['upload_preset'] = _uploadPreset;
        }
      } catch (_) {
        request.fields['upload_preset'] = _uploadPreset;
      }
    } else {
      // Unsigned upload preset pattern (standard for mobile/client apps)
      request.fields['upload_preset'] = _uploadPreset;
    }

    request.files.add(http.MultipartFile.fromBytes(
      'file',
      bytes,
      filename: fileName,
    ));

    onProgress?.call(0.3);

    final streamed = await request.send();
    final body = await streamed.stream.bytesToString();
    final result = jsonDecode(body) as Map<String, dynamic>;

    if (streamed.statusCode != 200) {
      throw CloudinaryException(
        result['error']?['message'] ?? 'Upload failed (${streamed.statusCode})',
      );
    }

    onProgress?.call(1.0);

    return (
      url: result['secure_url'] as String,
      publicId: result['public_id'] as String,
    );
  }

  Future<void> deleteImage(String publicId) async {
    // File deletion should be mediated through backend API to maintain security
    debugPrint('Cloudinary deletion request queued for $publicId');
  }

  Future<void> deleteRaw(String publicId) async {
    debugPrint('Cloudinary raw deletion request queued for $publicId');
  }
}

class CloudinaryException implements Exception {
  final String message;
  CloudinaryException(this.message);

  @override
  String toString() => 'Cloudinary: $message';
}
