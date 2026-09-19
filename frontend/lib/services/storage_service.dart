import 'dart:convert';
import 'dart:typed_data';
import 'api_client.dart';
import 'cloudinary_service.dart';

class FileTooLargeException implements Exception {
  final int maxBytes;
  FileTooLargeException(this.maxBytes);
  @override
  String toString() =>
      'File exceeds the ${(maxBytes / (1024 * 1024)).toStringAsFixed(0)}MB limit.';
}

class UnsupportedFileTypeException implements Exception {
  final List<String> allowedExtensions;
  UnsupportedFileTypeException(this.allowedExtensions);
  @override
  String toString() =>
      'Unsupported file type. Allowed: ${allowedExtensions.join(', ')}';
}

/// Stores files via Cloudinary (free plan) with a base64 data-URI fallback
/// for profile photos (persisted on the MySQL user row).
class StorageService {
  final ApiClient _api;
  final CloudinaryService _cloudinary;

  StorageService({
    ApiClient? api,
    CloudinaryService? cloudinary,
  })  : _api = api ?? ApiClient(),
        _cloudinary = cloudinary ?? CloudinaryService();

  static const int maxResumeBytes = 10 * 1024 * 1024;
  static const int maxCertificateBytes = 10 * 1024 * 1024;
  static const int maxPhotoBytes = 5 * 1024 * 1024;
  static const int maxChatImageBytes = 5 * 1024 * 1024;

  static const resumeExtensions = ['pdf', 'docx'];
  static const certificateExtensions = ['pdf', 'jpg', 'jpeg', 'png'];
  static const photoExtensions = ['jpg', 'jpeg', 'png'];
  static const chatImageExtensions = ['jpg', 'jpeg', 'png'];

  String _extensionOf(String fileName) =>
      fileName.split('.').last.toLowerCase();

  void _validate({
    required String fileName,
    required int sizeBytes,
    required int maxBytes,
    required List<String> allowedExtensions,
  }) {
    if (sizeBytes > maxBytes) throw FileTooLargeException(maxBytes);
    final ext = _extensionOf(fileName);
    if (!allowedExtensions.contains(ext)) {
      throw UnsupportedFileTypeException(allowedExtensions);
    }
  }

  bool get _cloudinaryConfigured =>
      _cloudinary.cloudName.isNotEmpty;

  /// Uploads a profile photo via Cloudinary, falling back to a base64
  /// data-URI on the user row if Cloudinary is not configured.
  Future<({String url, String path})> uploadProfilePhoto({
    required String userId,
    required String fileName,
    Uint8List? bytes,
    void Function(double progress)? onProgress,
  }) async {
    final size = bytes?.length ?? 0;
    _validate(
      fileName: fileName,
      sizeBytes: size,
      maxBytes: maxPhotoBytes,
      allowedExtensions: photoExtensions,
    );
    if (bytes == null) throw ArgumentError('bytes must be provided');

    if (_cloudinaryConfigured) {
      onProgress?.call(0.1);
      final result = await _cloudinary.uploadImage(
        bytes: bytes,
        fileName: fileName,
        idToken: _api.currentToken,
        onProgress: onProgress,
      );

      await _api.patch('/api/profile', body: {'photoUrl': result.url});

      return (url: result.url, path: result.publicId);
    }

    // Fallback: store as base64 data-URI on the user row.
    onProgress?.call(0.5);
    final b64 = base64Encode(bytes);
    final dataUri =
        'data:image/${_extensionOf(fileName) == 'png' ? 'png' : 'jpeg'};base64,$b64';

    await _api.patch('/api/profile', body: {'photoUrl': dataUri});

    onProgress?.call(1.0);
    return (url: dataUri, path: 'users/$userId/photo');
  }

  /// Uploads a resume file via Cloudinary.
  Future<({String url, String path})> uploadResume({
    required String userId,
    required String fileName,
    Object? file,
    Uint8List? bytes,
    void Function(double progress)? onProgress,
  }) async {
    final size = bytes?.length ?? 0;
    _validate(
      fileName: fileName,
      sizeBytes: size,
      maxBytes: maxResumeBytes,
      allowedExtensions: resumeExtensions,
    );

    if (!_cloudinaryConfigured) {
      throw UnsupportedError(
        'Cloudinary not configured. Add CLOUDINARY_CLOUD_NAME to .env',
      );
    }

    onProgress?.call(0.1);
    final result = await _cloudinary.uploadRaw(
      bytes: bytes!,
      fileName: fileName,
      idToken: _api.currentToken,
      onProgress: onProgress,
    );

    return (url: result.url, path: result.publicId);
  }

  /// Uploads a certificate file via Cloudinary.
  Future<({String url, String path})> uploadCertificate({
    required String userId,
    required String fileName,
    Object? file,
    Uint8List? bytes,
    void Function(double progress)? onProgress,
  }) async {
    final size = bytes?.length ?? 0;
    _validate(
      fileName: fileName,
      sizeBytes: size,
      maxBytes: maxCertificateBytes,
      allowedExtensions: certificateExtensions,
    );

    if (!_cloudinaryConfigured) {
      throw UnsupportedError(
        'Cloudinary not configured. Add CLOUDINARY_CLOUD_NAME to .env',
      );
    }

    onProgress?.call(0.1);

    final ext = _extensionOf(fileName);
    final isImage = ['jpg', 'jpeg', 'png'].contains(ext);
    final result = isImage
        ? await _cloudinary.uploadImage(
            bytes: bytes!,
            fileName: fileName,
            idToken: _api.currentToken,
            onProgress: onProgress,
          )
        : await _cloudinary.uploadRaw(
            bytes: bytes!,
            fileName: fileName,
            idToken: _api.currentToken,
            onProgress: onProgress,
          );

    return (url: result.url, path: result.publicId);
  }

  /// Uploads a chat image via Cloudinary. Images are stored as hosted URLs
  /// (persisted in MySQL `messages.image_url`) so both alumni and admin apps
  /// can load them without an admin account.
  Future<({String url, String path})> uploadChatImage({
    required String fileName,
    required Uint8List bytes,
    void Function(double progress)? onProgress,
  }) async {
    _validate(
      fileName: fileName,
      sizeBytes: bytes.length,
      maxBytes: maxChatImageBytes,
      allowedExtensions: chatImageExtensions,
    );

    if (!_cloudinaryConfigured) {
      throw UnsupportedError(
        'Image upload is not configured. Add CLOUDINARY_CLOUD_NAME to .env',
      );
    }

    onProgress?.call(0.1);
    final result = await _cloudinary.uploadImage(
      bytes: bytes,
      fileName: fileName,
      idToken: _api.currentToken,
      onProgress: onProgress,
    );

    return (url: result.url, path: result.publicId);
  }

  /// Deletes a file from Cloudinary by its public ID.
  Future<void> deleteFile(String storagePath) async {
    if (!_cloudinaryConfigured) return;
    if (storagePath.startsWith('users/') || storagePath.startsWith('data:')) {
      return;
    }
    try {
      await _cloudinary.deleteImage(storagePath);
    } catch (_) {
      try {
        await _cloudinary.deleteRaw(storagePath);
      } catch (_) {
        // ignore failures on delete
      }
    }
  }
}
