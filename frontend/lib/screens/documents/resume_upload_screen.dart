import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../constants/app_constants.dart';
import '../../models/document_model.dart';
import '../../providers/auth_providers.dart';
import '../../providers/document_providers.dart';
import '../../services/storage_service.dart';
import '../../utils/app_snack_bar.dart';
import '../../utils/firebase_error_message.dart';
import '../../widgets/empty_state_widget.dart';

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
      withData: true,
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
        showAppSnackBar(context, 'Resume uploaded successfully',
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
      backgroundColor: AppColors.surfaceDark,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Resume & CV',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: resumeAsync.when(
          data: (resume) => SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (resume != null)
                  _ResumeCard(resume: resume, onDelete: () => _deleteResume(resume)),
                if (resume == null)
                  const EmptyStateWidget(
                    icon: Icons.description_outlined,
                    title: 'No Resume Uploaded',
                    message: 'Upload your latest CV in PDF or DOCX format to make it available for alumni opportunities.',
                  ),
                const SizedBox(height: 24),
                if (_uploading)
                  Column(
                    children: [
                      LinearProgressIndicator(
                        value: _progress,
                        backgroundColor: Colors.white.withValues(alpha: 0.1),
                        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primaryBlue),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Uploading… ${(_progress * 100).round()}%',
                        style: GoogleFonts.poppins(color: const Color(0xFF94A3B8), fontSize: 12),
                      ),
                    ],
                  )
                else
                  ElevatedButton.icon(
                    onPressed: _pickAndUpload,
                    icon: const Icon(Icons.upload_file_rounded, size: 20),
                    label: Text(resume == null ? 'Upload PDF / DOCX Resume' : 'Replace Current Resume'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                const SizedBox(height: 10),
                Center(
                  child: Text(
                    'Supported formats: PDF or DOCX (Max size: 10 MB).',
                    style: GoogleFonts.poppins(color: const Color(0xFF64748B), fontSize: 11.5),
                  ),
                ),
              ],
            ),
          ),
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primaryBlue),
          ),
          error: (e, _) => Center(
            child: Text('Error: $e', style: const TextStyle(color: Colors.white)),
          ),
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
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderDark),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.picture_as_pdf_rounded, color: AppColors.error, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  resume.fileName,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '$sizeMb MB • Uploaded ${DateFormat.yMMMd().format(resume.uploadedAt)}',
                  style: GoogleFonts.poppins(fontSize: 11.5, color: const Color(0xFF94A3B8)),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.open_in_new_rounded, color: AppColors.secondaryBlue, size: 20),
            onPressed: () => launchUrl(
              Uri.parse(resume.fileUrl),
              mode: LaunchMode.externalApplication,
            ),
            tooltip: 'Open Document',
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 20),
            onPressed: onDelete,
            tooltip: 'Delete Document',
          ),
        ],
      ),
    );
  }
}
