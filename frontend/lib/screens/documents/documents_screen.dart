import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_constants.dart';
import '../../providers/document_providers.dart';
import '../../routes/app_router.dart';

class DocumentsScreen extends ConsumerWidget {
  const DocumentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resumeAsync = ref.watch(myResumeProvider);
    final certificatesAsync = ref.watch(myCertificatesProvider);

    return Scaffold(
      backgroundColor: AppColors.surfaceDark,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceDark,
        elevation: 0,
        title: Text(
          'Document Center',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Document Vault',
            style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            'Manage your verified resume and professional certificates from one secure location.',
            style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 24),
          _DocumentSection(
            title: 'Resume & CV',
            icon: Icons.upload_file_rounded,
            description: 'Keep your professional resume updated for recruiter requests and university opportunities.',
            content: resumeAsync.when(
              data: (resume) => resume == null
                  ? Text('No resume uploaded yet.', style: GoogleFonts.poppins(color: const Color(0xFF94A3B8), fontSize: 13))
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          resume.fileName,
                          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Uploaded on ${resume.uploadedAt.toLocal().toString().split(' ').first}',
                          style: GoogleFonts.poppins(color: AppColors.tealLight, fontSize: 12),
                        ),
                      ],
                    ),
              loading: () => const SizedBox(
                height: 40,
                child: Center(child: CircularProgressIndicator(color: AppColors.primaryBlue)),
              ),
              error: (e, _) => Text('Error loading resume: $e', style: const TextStyle(color: AppColors.error)),
            ),
            actionLabel: 'Manage Resume',
            onAction: () => context.push(AppRoutes.resume),
          ),
          const SizedBox(height: 16),
          _DocumentSection(
            title: 'Certificates Gallery',
            icon: Icons.workspace_premium_rounded,
            description: 'Store and organize your verified licenses, awards, and course achievements.',
            content: certificatesAsync.when(
              data: (certs) => Text(
                certs.isEmpty
                    ? 'No certificates uploaded yet.'
                    : '${certs.length} certificate${certs.length == 1 ? '' : 's'} verified and stored.',
                style: GoogleFonts.poppins(color: const Color(0xFF94A3B8), fontSize: 13),
              ),
              loading: () => const SizedBox(
                height: 40,
                child: Center(child: CircularProgressIndicator(color: AppColors.primaryBlue)),
              ),
              error: (e, _) => Text('Error loading certificates: $e', style: const TextStyle(color: AppColors.error)),
            ),
            actionLabel: 'View Certificates',
            onAction: () => context.push(AppRoutes.certificates),
          ),
        ],
      ),
    );
  }
}

class _DocumentSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final String description;
  final Widget content;
  final String actionLabel;
  final VoidCallback onAction;

  const _DocumentSection({
    required this.title,
    required this.icon,
    required this.description,
    required this.content,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.all(12),
                child: Icon(icon, color: AppColors.secondaryBlue, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: GoogleFonts.poppins(fontSize: 12.5, color: const Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 14),
          content,
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onAction,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}
