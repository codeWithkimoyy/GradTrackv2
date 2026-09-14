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
}

class CertificateRecord {
  final String id;
  final String userId;
  final String title;
  final CertificateProvider provider;
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
    required this.fileUrl,
    required this.storagePath,
    required this.fileType,
    this.issuedDate,
    required this.uploadedAt,
  });

  factory CertificateRecord.fromJson(Map<String, dynamic> map, String id) {
    return CertificateRecord(
      id: id,
      userId: map['userId']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      provider: CertificateProviderX.fromString(map['provider']?.toString() ?? 'other'),
      fileUrl: map['fileUrl']?.toString() ?? '',
      storagePath: map['storagePath']?.toString() ?? '',
      fileType: map['fileType']?.toString() ?? 'image',
      issuedDate: parseApiDateOnly(map['issuedDate']),
      uploadedAt: parseApiDate(map['uploadedAt']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'title': title,
        'provider': provider.name,
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
