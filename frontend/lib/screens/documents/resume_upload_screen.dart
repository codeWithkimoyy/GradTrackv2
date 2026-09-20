import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../constants/app_constants.dart';
import '../../models/document_model.dart';
import '../../providers/auth_providers.dart';
import '../../providers/document_providers.dart';
import '../../services/storage_service.dart';
import '../../services/auth_service.dart';
import '../../utils/app_snack_bar.dart';
import '../../utils/navigation_utils.dart';
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
    );
    if (result.isEmpty) return;

    final picked = result.single;
    final user = ref.read(currentUserProfileProvider).value;
    if (user == null) return;

    setState(() {
      _uploading = true;
      _progress = 0;
    });

    try {
      final bytes = await picked.readAsBytes();
      final uploaded = await ref.read(storageServiceProvider).uploadResume(
            userId: user.uid,
            fileName: picked.name,
            bytes: bytes,
            onProgress: (p) => setState(() => _progress = p),
          );

      await ref.read(documentRepositoryProvider).saveResumeMetadata(
            user.uid,
            ResumeRecord(
              fileUrl: uploaded.url,
              storagePath: uploaded.path,
              fileName: picked.name,
              sizeBytes: bytes.length,
              uploadedAt: DateTime.now(),
            ),
          );

      if (mounted) {
        showAppSnackBar(context, 'Resume uploaded successfully',
            backgroundColor: AppColors.success);
      }
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, AuthService.friendlyError(e),
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
        showAppSnackBar(context, AuthService.friendlyError(e),
            backgroundColor: AppColors.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final resumeAsync = ref.watch(myResumeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: isDark ? Colors.white : AppColors.primaryNavy),
          onPressed: () => popOrGoHome(context),
        ),
        title: Text(
          'Resume & CV',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : AppColors.primaryNavy,
          ),
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
                        backgroundColor: isDark ? Colors.white.withOpacity(0.1) : AppColors.primaryBlue.withOpacity(0.1),
                        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primaryBlue),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Uploading… ${(_progress * 100).round()}%',
                        style: GoogleFonts.poppins(
                          color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
                          fontSize: 12,
                        ),
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
                    style: GoogleFonts.poppins(
                      color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
                      fontSize: 11.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primaryBlue),
          ),
          error: (e, _) => Center(
            child: Text('Error: $e'),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sizeMb = (resume.sizeBytes / (1024 * 1024)).toStringAsFixed(2);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
        boxShadow: isDark
            ? []
            : const [
                BoxShadow(
                  color: Color(0x0C0F172A),
                  blurRadius: 12,
                  offset: Offset(0, 2),
                ),
              ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.error.withOpacity(isDark ? 0.16 : 0.10),
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
                    color: isDark ? Colors.white : AppColors.primaryNavy,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '$sizeMb MB • Uploaded ${DateFormat.yMMMd().format(resume.uploadedAt)}',
                  style: GoogleFonts.poppins(
                    fontSize: 11.5,
                    color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.open_in_new_rounded, color: AppColors.primaryBlue, size: 20),
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
