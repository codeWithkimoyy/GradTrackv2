import 'user_model.dart' show parseApiDate, parseApiDateOnly;

enum CertificateProvider {
  tesda,
  google,
  cisco,
  aws,
  microsoft,
  oracle,
  other,
}

extension CertificateProviderX on CertificateProvider {
  String get label => switch (this) {
        CertificateProvider.tesda => 'TESDA',
        CertificateProvider.google => 'Google',
        CertificateProvider.cisco => 'Cisco',
        CertificateProvider.aws => 'AWS',
        CertificateProvider.microsoft => 'Microsoft',
        CertificateProvider.oracle => 'Oracle',
        CertificateProvider.other => 'Other',
      };

  static CertificateProvider fromString(String value) =>
      CertificateProvider.values.firstWhere(
        (p) => p.name == value,
        orElse: () => CertificateProvider.other,
      );

  /// True when the stored string was not one of the known provider names.
  static bool isCustom(String value) =>
      CertificateProvider.values.every((p) => p.name != value);
}

class CertificateRecord {
  final String id;
  final String userId;
  final String title;
  final CertificateProvider provider;
  /// When `provider` is `other` and the alumnus typed a custom name (e.g.
  /// "Coursera"), this holds that name for display. Null otherwise.
  final String? customProvider;
  final String fileUrl;
  final String storagePath;
  final String fileType; // image or pdf
  final DateTime? issuedDate;
  final DateTime uploadedAt;

  const CertificateRecord({
    required this.id,
    required this.userId,
    required this.title,
    required this.provider,
    this.customProvider,
    required this.fileUrl,
    required this.storagePath,
    required this.fileType,
    this.issuedDate,
    required this.uploadedAt,
  });

  factory CertificateRecord.fromJson(Map<String, dynamic> map, String id) {
    final providerRaw = map['provider']?.toString() ?? 'other';
    final provider = CertificateProviderX.fromString(providerRaw);
    return CertificateRecord(
      id: id,
      userId: map['userId']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      provider: provider,
      // Preserve a custom Others name (e.g. "Coursera - UX Design") even
      // though `provider` maps to `other` for coloring/icon purposes.
      customProvider: CertificateProviderX.isCustom(providerRaw) ? providerRaw : null,
      fileUrl: map['fileUrl']?.toString() ?? '',
      storagePath: map['storagePath']?.toString() ?? '',
      fileType: map['fileType']?.toString() ?? 'image',
      issuedDate: parseApiDateOnly(map['issuedDate']),
      uploadedAt: parseApiDate(map['uploadedAt']) ?? DateTime.now(),
    );
  }

  /// Human label for cards: the custom name when present, otherwise the
  /// provider's standard label.
  String get displayProvider =>
      (customProvider != null && customProvider!.trim().isNotEmpty)
          ? customProvider!.trim()
          : provider.label;

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'title': title,
        'provider': (customProvider != null && customProvider!.trim().isNotEmpty)
            ? customProvider!.trim()
            : provider.name,
        'fileUrl': fileUrl,
        'storagePath': storagePath,
        'fileType': fileType,
        'issuedDate': issuedDate != null
            ? '${issuedDate!.year.toString().padLeft(4, '0')}-${issuedDate!.month.toString().padLeft(2, '0')}-${issuedDate!.day.toString().padLeft(2, '0')}'
            : null,
        'uploadedAt': uploadedAt.toIso8601String(),
      };
}

/// Metadata about the graduate's uploaded resume (single active file).
class ResumeRecord {
  final String fileUrl;
  final String storagePath;
  final String fileName;
  final int sizeBytes;
  final DateTime uploadedAt;

  const ResumeRecord({
    required this.fileUrl,
    required this.storagePath,
    required this.fileName,
    required this.sizeBytes,
    required this.uploadedAt,
  });

  factory ResumeRecord.fromMap(Map<String, dynamic> map) => ResumeRecord(
        fileUrl: map['fileUrl']?.toString() ?? '',
        storagePath: map['storagePath']?.toString() ?? '',
        fileName: map['fileName']?.toString() ?? '',
        sizeBytes: (map['sizeBytes'] as num?)?.toInt() ?? 0,
        uploadedAt: parseApiDate(map['uploadedAt']) ?? DateTime.now(),
      );

  Map<String, dynamic> toMap() => {
        'fileUrl': fileUrl,
        'storagePath': storagePath,
        'fileName': fileName,
        'sizeBytes': sizeBytes,
        'uploadedAt': uploadedAt.toIso8601String(),
      };
}
