import '../models/document_model.dart';
import '../services/api_client.dart';

class DocumentRepository {
  DocumentRepository({ApiClient? api}) : _api = api ?? ApiClient();

  final ApiClient _api;

  static const Duration pollInterval = Duration(seconds: 30);

  /// Resume metadata is stored as a single nested object on the user row,
  /// since each graduate has exactly one active resume.
  Stream<ResumeRecord?> watchResume(String userId) {
    return _api.poll(() => fetchResume(userId), interval: pollInterval);
  }

  Future<ResumeRecord?> fetchResume(String userId) async {
    final raw = await _api
        .get('/api/documents/resume', query: {'userId': userId});
    if (raw == null) return null;
    return ResumeRecord.fromMap(Map<String, dynamic>.from(raw));
  }

  Future<void> saveResumeMetadata(String userId, ResumeRecord resume) {
    return _api.put('/api/documents/resume', body: resume.toMap());
  }

  Future<void> deleteResumeMetadata(String userId) {
    return _api.delete('/api/documents/resume');
  }

  Stream<List<CertificateRecord>> watchCertificates(String userId) {
    return _api.poll(() => fetchCertificates(userId),
        interval: pollInterval);
  }

  Future<List<CertificateRecord>> fetchCertificates(String userId) async {
    final raw = await _api
        .get('/api/documents/certificates', query: {'userId': userId});
    return (raw as List)
        .cast<Map<String, dynamic>>()
        .map((m) => CertificateRecord.fromJson(m, m['id']?.toString() ?? ''))
        .toList();
  }

  Future<CertificateRecord> addCertificate(CertificateRecord cert) async {
    final raw =
        await _api.post('/api/documents/certificates', body: cert.toMap());
    final map = Map<String, dynamic>.from(raw);
    return CertificateRecord.fromJson(map, map['id']?.toString() ?? '');
  }

  Future<void> deleteCertificate(String certificateId) {
    return _api.delete('/api/documents/certificates/$certificateId');
  }
}
