import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
      appBar: AppBar(title: const Text('Documents')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          const Text('Document Center',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'Manage your resume and certificates from one place.',
            style: TextStyle(fontSize: 14, color: Colors.black54),
          ),
          const SizedBox(height: AppSpacing.lg),
          _DocumentSection(
            title: 'Resume',
            icon: Icons.upload_file_outlined,
            description:
                'Keep your resume up to date and available for employer requests.',
            content: resumeAsync.when(
              data: (resume) => resume == null
                  ? const Text('No resume uploaded yet.')
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(resume.fileName,
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Uploaded on ${resume.uploadedAt.toLocal().toString().split(' ').first}',
                          style: const TextStyle(color: Colors.black54),
                        ),
                      ],
                    ),
              loading: () => const SizedBox(
                height: 48,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Text('Error loading resume: $e'),
            ),
            actionLabel: 'Manage Resume',
            onAction: () => context.push(AppRoutes.resume),
          ),
          _DocumentSection(
            title: 'Certificates',
            icon: Icons.workspace_premium_outlined,
            description:
                'Store your verified certificates and share them with employers.',
            content: certificatesAsync.when(
              data: (certs) => Text(
                certs.isEmpty
                    ? 'No certificates uploaded yet.'
                    : '${certs.length} certificate${certs.length == 1 ? '' : 's'} available.',
              ),
              loading: () => const SizedBox(
                height: 48,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Text('Error loading certificates: $e'),
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
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.card),
                  ),
                  padding: const EdgeInsets.all(10),
                  child: Icon(icon, color: AppColors.primaryBlue),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(title,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(description, style: const TextStyle(color: Colors.black54)),
            const SizedBox(height: AppSpacing.md),
            content,
            const SizedBox(height: AppSpacing.md),
            ElevatedButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}
