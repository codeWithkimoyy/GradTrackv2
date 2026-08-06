import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class CloudinaryService {
  CloudinaryService() {
    _cloudName = dotenv.env['CLOUDINARY_CLOUD_NAME'] ?? '';
    _apiKey = dotenv.env['CLOUDINARY_API_KEY'] ?? '';
    _apiSecret = dotenv.env['CLOUDINARY_API_SECRET'] ?? '';

    if (_cloudName.isEmpty) {
      debugPrint('CLOUDINARY_CLOUD_NAME is not set in .env');
    }
  }

  late final String _cloudName;
  late final String _apiKey;
  late final String _apiSecret;

  String get cloudName => _cloudName;

  Future<({String url, String publicId})> uploadImage({
    required Uint8List bytes,
    required String fileName,
    void Function(double progress)? onProgress,
  }) async {
    return _upload(
      resourceType: 'image',
      bytes: bytes,
      fileName: fileName,
      onProgress: onProgress,
    );
  }

  Future<({String url, String publicId})> uploadRaw({
    required Uint8List bytes,
    required String fileName,
    void Function(double progress)? onProgress,
  }) async {
    return _upload(
      resourceType: 'raw',
      bytes: bytes,
      fileName: fileName,
      onProgress: onProgress,
    );
  }

  Future<({String url, String publicId})> _upload({
    required String resourceType,
    required Uint8List bytes,
    required String fileName,
    void Function(double progress)? onProgress,
  }) async {
    final timestamp = (DateTime.now().millisecondsSinceEpoch / 1000).round();
    final signature = _generateSignature({
      'timestamp': timestamp.toString(),
    });

    final uri = Uri.parse(
      'https://api.cloudinary.com/v1_1/$_cloudName/$resourceType/upload',
    );

    final request = http.MultipartRequest('POST', uri);
    request.fields['api_key'] = _apiKey;
    request.fields['timestamp'] = timestamp.toString();
    request.fields['signature'] = signature;
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
    await _destroy(resourceType: 'image', publicId: publicId);
  }

  Future<void> deleteRaw(String publicId) async {
    await _destroy(resourceType: 'raw', publicId: publicId);
  }

  Future<void> _destroy({
    required String resourceType,
    required String publicId,
  }) async {
    final timestamp = (DateTime.now().millisecondsSinceEpoch / 1000).round();
    final signature = _generateSignature({
      'public_id': publicId,
      'timestamp': timestamp.toString(),
      'type': 'upload',
    });

    final uri = Uri.parse(
      'https://api.cloudinary.com/v1_1/$_cloudName/$resourceType/destroy',
    );

    final response = await http.post(
      uri,
      body: {
        'api_key': _apiKey,
        'timestamp': timestamp.toString(),
        'signature': signature,
        'public_id': publicId,
        'type': 'upload',
      },
    );

    final result = jsonDecode(response.body) as Map<String, dynamic>;
    if (result['result'] != 'ok') {
      debugPrint('Cloudinary destroy failed for $publicId: ${response.body}');
    }
  }

  String _generateSignature(Map<String, String> params) {
    final sortedKeys = params.keys.toList()..sort();
    final signatureStr =
        sortedKeys.map((k) => '$k=${params[k]}').join('&') + _apiSecret;
    return sha1.convert(utf8.encode(signatureStr)).toString();
  }
}

class CloudinaryException implements Exception {
  final String message;
  CloudinaryException(this.message);

  @override
  String toString() => 'Cloudinary: $message';
}
