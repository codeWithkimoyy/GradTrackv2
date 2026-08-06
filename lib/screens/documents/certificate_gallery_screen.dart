import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../constants/app_constants.dart';
import '../../models/document_model.dart';
import '../../providers/auth_providers.dart';
import '../../providers/document_providers.dart';
import '../../services/storage_service.dart';
import '../../utils/app_snack_bar.dart';
import '../../utils/firebase_error_message.dart';

class CertificateGalleryScreen extends ConsumerStatefulWidget {
  const CertificateGalleryScreen({super.key});

  @override
  ConsumerState<CertificateGalleryScreen> createState() =>
      _CertificateGalleryScreenState();
}

class _CertificateGalleryScreenState
    extends ConsumerState<CertificateGalleryScreen> {
  bool _uploading = false;
  double _progress = 0;

  Future<void> _pickAndUpload() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: StorageService.certificateExtensions,
      withData: true,
    );
    if (!mounted) return;
    if (result == null || result.files.isEmpty) return;

    final picked = result.files.single;
    final user = ref.read(currentUserProfileProvider).value;
    if (user == null) return;

    final titleController = TextEditingController();
    final provider = await showDialog<CertificateProvider>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Certificate Details'),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: 'Certificate Title',
                hintText: 'e.g. AWS Certified Developer',
              ),
              autofocus: true,
            ),
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.only(left: 24),
            child:
                Text('Provider', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          ...CertificateProvider.values.map((p) => SimpleDialogOption(
                onPressed: () {
                  if (titleController.text.trim().isEmpty) {
                    showAppSnackBar(ctx, 'Please enter a title');
                    return;
                  }
                  Navigator.pop(ctx, p);
                },
                child: Text(p.label),
              )),
        ],
      ),
    );
    if (provider == null || !mounted) return;

    setState(() {
      _uploading = true;
      _progress = 0;
    });

    try {
      final uploaded = await ref.read(storageServiceProvider).uploadCertificate(
            userId: user.uid,
            fileName: picked.name,
            file: (!kIsWeb && picked.path != null) ? File(picked.path!) : null,
            bytes: picked.bytes,
            onProgress: (p) => setState(() => _progress = p),
          );

      await ref.read(documentRepositoryProvider).addCertificate(
            CertificateRecord(
              id: '',
              userId: user.uid,
              title: titleController.text.isNotEmpty
                  ? titleController.text
                  : picked.name,
              provider: provider,
              fileUrl: uploaded.url,
              storagePath: uploaded.path,
              fileType: picked.extension ?? 'image',
              uploadedAt: DateTime.now(),
            ),
          );

      if (mounted) {
        showAppSnackBar(context, 'Certificate uploaded',
            backgroundColor: AppColors.success);
      }
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, friendlyFirebaseError(e),
            backgroundColor: AppColors.error);
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _deleteCertificate(CertificateRecord cert) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Certificate'),
        content: Text('Delete "${cert.title}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(storageServiceProvider).deleteFile(cert.storagePath);
      await ref.read(documentRepositoryProvider).deleteCertificate(cert.id);
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, friendlyFirebaseError(e),
            backgroundColor: AppColors.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final certsAsync = ref.watch(myCertificatesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Certificates')),
      floatingActionButton: FloatingActionButton(
        onPressed: _uploading ? null : _pickAndUpload,
        child: _uploading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.add),
      ),
      body: Column(
        children: [
          if (_uploading) LinearProgressIndicator(value: _progress),
          Expanded(
            child: certsAsync.when(
              data: (certs) => certs.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.verified_outlined,
                              size: 64, color: Colors.grey),
                          SizedBox(height: AppSpacing.sm),
                          Text('No certificates yet',
                              style: TextStyle(color: Colors.grey)),
                          SizedBox(height: AppSpacing.xs),
                          Text('Tap + to add one',
                              style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      itemCount: certs.length,
                      itemBuilder: (context, index) {
                        final cert = certs[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor:
                                  AppColors.goldLight.withValues(alpha: 0.3),
                              child: const Icon(Icons.verified,
                                  color: AppColors.gold),
                            ),
                            title: Text(cert.title,
                                overflow: TextOverflow.ellipsis),
                            subtitle: Text(
                              '${cert.provider.label} • ${DateFormat.yMMMd().format(cert.uploadedAt)}',
                            ),
                            trailing: OverflowBar(
                              spacing: 0,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.open_in_new),
                                  onPressed: () => launchUrl(
                                      Uri.parse(cert.fileUrl),
                                      mode: LaunchMode.externalApplication),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline,
                                      color: AppColors.error),
                                  onPressed: () => _deleteCertificate(cert),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    );
  }
}
