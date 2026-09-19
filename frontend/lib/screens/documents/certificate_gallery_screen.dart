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
    );
    if (!mounted) return;
    if (result.isEmpty) return;

    final picked = result.single;
    final user = ref.read(currentUserProfileProvider).value;
    if (user == null) return;

    final titleController = TextEditingController();
    final otherProviderController = TextEditingController();
    CertificateProvider? provider;
    String? customProvider;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final isOther = provider == CertificateProvider.other;
          return AlertDialog(
            backgroundColor: AppColors.cardDark,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(
              'Certificate Details',
              style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: titleController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Certificate Title',
                      hintText: 'e.g. AWS Certified Developer',
                    ),
                    autofocus: true,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Issuing Provider',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: CertificateProvider.values.map((p) {
                      final selected = provider == p;
                      return ChoiceChip(
                        label: Text(p.label,
                            style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: selected ? Colors.white : AppColors.primaryBlue)),
                        selected: selected,
                        selectedColor: AppColors.primaryBlue,
                        backgroundColor: Colors.white.withOpacity(0.12),
                        onSelected: (_) => setDialogState(() => provider = p),
                      );
                    }).toList(),
                  ),
                  if (isOther) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: otherProviderController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'What kind of certificate?',
                        hintText: 'e.g. Coursera, Udemy, DICT',
                      ),
                      autofocus: true,
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  if (titleController.text.trim().isEmpty) {
                    showAppSnackBar(ctx, 'Please enter a title');
                    return;
                  }
                  if (provider == null) {
                    showAppSnackBar(ctx, 'Select a provider');
                    return;
                  }
                  if (provider == CertificateProvider.other &&
                      otherProviderController.text.trim().isEmpty) {
                    showAppSnackBar(ctx, 'Tell us what kind of certificate this is');
                    return;
                  }
                  customProvider = provider == CertificateProvider.other
                      ? otherProviderController.text.trim()
                      : null;
                  Navigator.pop(ctx);
                },
                child: const Text('Continue'),
              ),
            ],
          );
        },
      ),
    );
    if (provider == null || !mounted) return;

    setState(() {
      _uploading = true;
      _progress = 0;
    });

    try {
      final bytes = await picked.readAsBytes();
      final uploaded = await ref.read(storageServiceProvider).uploadCertificate(
            userId: user.uid,
            fileName: picked.name,
            bytes: bytes,
            onProgress: (p) => setState(() => _progress = p),
          );

      await ref.read(documentRepositoryProvider).addCertificate(
            CertificateRecord(
              id: '',
              userId: user.uid,
              title: titleController.text.isNotEmpty
                  ? titleController.text
                  : picked.name,
              provider: provider!,
              customProvider: customProvider,
              fileUrl: uploaded.url,
              storagePath: uploaded.path,
              fileType: picked.extension ?? 'image',
              uploadedAt: DateTime.now(),
            ),
          );

      if (mounted) {
        showAppSnackBar(context, 'Certificate added successfully',
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

  Future<void> _deleteCertificate(CertificateRecord cert) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete Certificate', style: GoogleFonts.poppins(color: Colors.white)),
        content: Text('Delete "${cert.title}"?', style: GoogleFonts.poppins(color: const Color(0xFF94A3B8))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Delete', style: GoogleFonts.poppins(color: AppColors.error))),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(storageServiceProvider).deleteFile(cert.storagePath);
      await ref.read(documentRepositoryProvider).deleteCertificate(cert.id);
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, AuthService.friendlyError(e),
            backgroundColor: AppColors.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final certsAsync = ref.watch(myCertificatesProvider);
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
          'Certificates Gallery',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : AppColors.primaryNavy,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: Colors.white,
        onPressed: _uploading ? null : _pickAndUpload,
        icon: _uploading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.add_rounded),
        label: Text('Add Certificate', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
      ),
      body: Column(
        children: [
          if (_uploading)
            LinearProgressIndicator(
              value: _progress,
              backgroundColor: isDark ? Colors.white.withOpacity(0.1) : AppColors.primaryBlue.withOpacity(0.1),
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primaryBlue),
            ),
          Expanded(
            child: certsAsync.when(
              data: (certs) => certs.isEmpty
                  ? EmptyStateWidget(
                      icon: Icons.workspace_premium_rounded,
                      title: 'No Certificates Yet',
                      message: 'Upload your verified licenses, awards, and course credentials.',
                      actionLabel: 'Add Certificate',
                      onAction: _pickAndUpload,
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(24),
                      itemCount: certs.length,
                      itemBuilder: (context, index) {
                        final cert = certs[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.cardDark : Colors.white,
                            borderRadius: BorderRadius.circular(18),
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
                                width: 44,
                                height: 44,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: AppColors.gold.withOpacity(isDark ? 0.16 : 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(Icons.verified_rounded,
                                    color: isDark
                                        ? AppColors.gold
                                        : AppColors.goldDeep,
                                    size: 22),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      cert.title,
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
                                      '${cert.displayProvider} • ${DateFormat.yMMMd().format(cert.uploadedAt)}',
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
                                  Uri.parse(cert.fileUrl),
                                  mode: LaunchMode.externalApplication,
                                ),
                                tooltip: 'Open Document',
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 20),
                                onPressed: () => _deleteCertificate(cert),
                                tooltip: 'Delete Document',
                              ),
                            ],
                          ),
                        );
                      },
                    ),
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.primaryBlue),
              ),
              error: (e, _) => Center(
                child: Text('Error: $e'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
