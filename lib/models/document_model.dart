import 'package:cloud_firestore/cloud_firestore.dart';

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

  factory CertificateRecord.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final map = doc.data() ?? {};
    return CertificateRecord(
      id: doc.id,
      userId: map['userId'] ?? '',
      title: map['title'] ?? '',
      provider: CertificateProviderX.fromString(map['provider'] ?? 'other'),
      fileUrl: map['fileUrl'] ?? '',
      storagePath: map['storagePath'] ?? '',
      fileType: map['fileType'] ?? 'image',
      issuedDate: (map['issuedDate'] as Timestamp?)?.toDate(),
      uploadedAt: (map['uploadedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'title': title,
        'provider': provider.name,
        'fileUrl': fileUrl,
        'storagePath': storagePath,
        'fileType': fileType,
        'issuedDate': issuedDate != null ? Timestamp.fromDate(issuedDate!) : null,
        'uploadedAt': Timestamp.fromDate(uploadedAt),
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
        fileUrl: map['fileUrl'] ?? '',
        storagePath: map['storagePath'] ?? '',
        fileName: map['fileName'] ?? '',
        sizeBytes: map['sizeBytes'] ?? 0,
        uploadedAt: (map['uploadedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      );

  Map<String, dynamic> toMap() => {
        'fileUrl': fileUrl,
        'storagePath': storagePath,
        'fileName': fileName,
        'sizeBytes': sizeBytes,
        'uploadedAt': Timestamp.fromDate(uploadedAt),
      };
}
