import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../constants/app_constants.dart';
import '../../utils/app_snack_bar.dart';

/// Public information screen for guests: about BISU Bilar Campus and
/// contact details. Contains no private data.
class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  Future<void> _mail(String address) async {
    final uri = Uri(scheme: 'mailto', path: address);
    try {
      final ok = await launchUrl(uri);
      if (!ok) throw Exception('launch failed');
    } catch (_) {
      if (!mounted) return;
      showAppSnackBar(context, 'No mail app is available on this device.',
          backgroundColor: AppColors.warning);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('About BISU Bilar')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue.withValues(alpha: .10),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.account_balance_outlined,
                        color: AppColors.primaryBlue, size: 30),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Bohol Island State University - Bilar Campus',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  const Text(
                    'GradTrack is the official Graduate Tracking and Alumni '
                    'Management System of BISU Bilar Campus. It connects '
                    'graduates with career, survey and community '
                    'opportunities, helping the university measure and '
                    'improve graduate outcomes.',
                    style: TextStyle(height: 1.5),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.email_outlined,
                      color: AppColors.primaryBlue),
                  title: const Text('Email the Alumni Office'),
                  subtitle:
                      const Text('gradtrack@bisu.edu.ph'),
                  onTap: () => _mail('gradtrack@bisu.edu.ph'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading:
                      const Icon(Icons.school_outlined, color: AppColors.primaryBlue),
                  title: const Text('BISU Bilar Campus'),
                  subtitle: const Text('Bilar, Bohol, Philippines'),
                  onTap: () => _mail('gradtrack@bisu.edu.ph'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}