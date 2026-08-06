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

class ResumeUploadScreen extends ConsumerStatefulWidget {
  const ResumeUploadScreen({super.key});

  @override
  ConsumerState<ResumeUploadScreen> createState() => _ResumeUploadScreenState();
}

class _ResumeUploadScreenState extends ConsumerState<ResumeUploadScreen> {
  bool _uploading = false;
  double _progress = 0;

  Future<void> _pickAndUpload() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: StorageService.resumeExtensions,
      withData: true, // needed for web; gives us bytes directly
    );
    if (result == null || result.files.isEmpty) return;

    final picked = result.files.single;
    final user = ref.read(currentUserProfileProvider).value;
    if (user == null) return;

    setState(() {
      _uploading = true;
      _progress = 0;
    });

    try {
      final uploaded = await ref.read(storageServiceProvider).uploadResume(
            userId: user.uid,
            fileName: picked.name,
            file: (!kIsWeb && picked.path != null) ? File(picked.path!) : null,
            bytes: picked.bytes,
            onProgress: (p) => setState(() => _progress = p),
          );

      await ref.read(documentRepositoryProvider).saveResumeMetadata(
            user.uid,
            ResumeRecord(
              fileUrl: uploaded.url,
              storagePath: uploaded.path,
              fileName: picked.name,
              sizeBytes: picked.size,
              uploadedAt: DateTime.now(),
            ),
          );

      if (mounted) {
        showAppSnackBar(context, 'Resume uploaded',
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

  Future<void> _deleteResume(ResumeRecord resume) async {
    final user = ref.read(currentUserProfileProvider).value;
    if (user == null) return;
    try {
      await ref.read(storageServiceProvider).deleteFile(resume.storagePath);
      await ref.read(documentRepositoryProvider).deleteResumeMetadata(user.uid);
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, friendlyFirebaseError(e),
            backgroundColor: AppColors.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final resumeAsync = ref.watch(myResumeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Resume')),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: resumeAsync.when(
          data: (resume) => SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (resume != null) _ResumeCard(resume: resume, onDelete: () => _deleteResume(resume)),
                if (resume == null)
                  const _EmptyResumeState(),
                const SizedBox(height: AppSpacing.lg),
                if (_uploading)
                  Column(
                    children: [
                      LinearProgressIndicator(value: _progress),
                      const SizedBox(height: AppSpacing.sm),
                      Text('Uploading… ${(_progress * 100).round()}%'),
                    ],
                  )
                else
                  ElevatedButton.icon(
                    onPressed: _pickAndUpload,
                    icon: const Icon(Icons.upload_file),
                    label: Text(resume == null ? 'Upload Resume' : 'Replace Resume'),
                  ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'PDF or DOCX, maximum 10 MB.',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
              ],
            ),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
        ),
      ),
    );
  }
}

class _ResumeCard extends StatelessWidget {
  final ResumeRecord resume;
  final VoidCallback onDelete;
  const _ResumeCard({required this.resume, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final sizeMb = (resume.sizeBytes / (1024 * 1024)).toStringAsFixed(2);
    return Card(
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: AppColors.error,
          child: Icon(Icons.picture_as_pdf_outlined, color: Colors.white),
        ),
        title: Text(resume.fileName, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          '$sizeMb MB • Uploaded ${DateFormat.yMMMd().format(resume.uploadedAt)}',
        ),
        trailing: OverflowBar(
          spacing: 0,
          children: [
            IconButton(
              icon: const Icon(Icons.open_in_new),
              onPressed: () => launchUrl(Uri.parse(resume.fileUrl),
                  mode: LaunchMode.externalApplication),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppColors.error),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyResumeState extends StatelessWidget {
  const _EmptyResumeState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        children: [
          Icon(Icons.description_outlined, size: 48, color: Colors.grey[400]),
          const SizedBox(height: AppSpacing.sm),
          Text('No resume uploaded yet',
              style: TextStyle(color: Colors.grey[600])),
        ],
      ),
    );
  }
}
