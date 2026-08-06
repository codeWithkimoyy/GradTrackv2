import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/document_model.dart';
import '../repositories/document_repository.dart';
import '../services/storage_service.dart';
import 'auth_providers.dart';

final storageServiceProvider = Provider<StorageService>((ref) => StorageService());

final documentRepositoryProvider = Provider<DocumentRepository>((ref) => DocumentRepository());

final myResumeProvider = StreamProvider<ResumeRecord?>((ref) {
  final user = ref.watch(currentUserProfileProvider).value;
  if (user == null) return const Stream.empty();
  return ref.watch(documentRepositoryProvider).watchResume(user.uid);
});

final myCertificatesProvider = StreamProvider<List<CertificateRecord>>((ref) {
  final user = ref.watch(currentUserProfileProvider).value;
  if (user == null) return const Stream.empty();
  return ref.watch(documentRepositoryProvider).watchCertificates(user.uid);
});
