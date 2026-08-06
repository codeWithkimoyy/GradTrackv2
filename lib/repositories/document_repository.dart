import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/app_constants.dart';
import '../models/document_model.dart';

class DocumentRepository {
  final FirebaseFirestore _firestore;

  DocumentRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _userDoc(String userId) =>
      _firestore.collection(FirestoreCollections.users).doc(userId);

  CollectionReference<Map<String, dynamic>> get _certificates =>
      _firestore.collection(FirestoreCollections.certificates);

  /// Resume metadata is stored as a single nested map on the user doc,
  /// since each graduate has exactly one active resume.
  Stream<ResumeRecord?> watchResume(String userId) {
    return _userDoc(userId).snapshots().map((doc) {
      final map = doc.data()?['resume'] as Map<String, dynamic>?;
      return map == null ? null : ResumeRecord.fromMap(map);
    });
  }

  Future<void> saveResumeMetadata(String userId, ResumeRecord resume) {
    return _userDoc(userId)
        .set(
          {'resume': resume.toMap()},
          SetOptions(merge: true),
        )
        .timeout(const Duration(seconds: 10));
  }

  Future<void> deleteResumeMetadata(String userId) {
    return _userDoc(userId)
        .update({'resume': FieldValue.delete()})
        .timeout(const Duration(seconds: 10));
  }

  Stream<List<CertificateRecord>> watchCertificates(String userId) {
    return _certificates
        .where('userId', isEqualTo: userId)
        .orderBy('uploadedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(CertificateRecord.fromDoc).toList());
  }

  Future<void> addCertificate(CertificateRecord cert) {
    final ref = _certificates.doc();
    return ref.set(cert.toMap()).timeout(const Duration(seconds: 10));
  }

  Future<void> deleteCertificate(String certificateId) {
    return _certificates.doc(certificateId).delete().timeout(const Duration(seconds: 10));
  }
}
