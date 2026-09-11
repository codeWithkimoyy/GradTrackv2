import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../constants/app_constants.dart';
import '../../models/alumni_message.dart';
import '../../models/user_model.dart';
import '../../providers/auth_providers.dart';
import '../../providers/stats_providers.dart';
import '../../routes/app_router.dart';
import '../../utils/app_snack_bar.dart';
import '../../widgets/empty_state_widget.dart';

/// Lets alumni contact the Alumni Office — typically to share a hiring
/// opportunity so admins can post it as an announcement.
class MessageAdminScreen extends ConsumerStatefulWidget {
  const MessageAdminScreen({super.key});

  @override
  ConsumerState<MessageAdminScreen> createState() => _MessageAdminScreenState();
}

class _MessageAdminScreenState extends ConsumerState<MessageAdminScreen> {
  final _formKey = GlobalKey<FormState>();
  final _companyController = TextEditingController();
  final _positionController = TextEditingController();
  final _detailsController = TextEditingController();
  MessageSubject _subject = MessageSubject.hiring;
  bool _sending = false;

  @override
  void dispose() {
    _companyController.dispose();
    _positionController.dispose();
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _send(UserModel user) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _sending = true);
    try {
      await ref.read(statsRepositoryProvider).sendMessage(
            senderId: user.uid,
            senderName: user.fullName,
            senderAlumniId: user.alumniId,
            senderEmail: user.email,
            subject: _subject,
            company: _companyController.text.trim().isEmpty
                ? null
                : _companyController.text.trim(),
            position: _positionController.text.trim().isEmpty
                ? null
                : _positionController.text.trim(),
            details: _detailsController.text.trim(),
          );
      if (!mounted) return;
      showAppSnackBar(
        context,
        'Message sent to the Alumni Office.',
        backgroundColor: AppColors.success,
        icon: Icons.check_circle_outline,
      );
      context.go(AppRoutes.alumniDashboard);
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      showAppSnackBar(
        context,
        'Failed to send your message: $e',
        backgroundColor: AppColors.error,
        icon: Icons.error_outline,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppColors.primaryNavy;

    return Scaffold(
      backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      appBar: AppBar(
        backgroundColor:
            isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        elevation: 0,
        title: Text(
          'Message Admin',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : AppColors.primaryNavy,
          ),
        ),
      ),
      body: ref.watch(currentUserProfileProvider).when(
        data: (user) {
          if (user == null) {
            return const EmptyStateWidget(
              icon: Icons.person_off_rounded,
              title: 'No Profile Found',
              message: 'Your user profile could not be loaded.',
            );
          }
          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                _buildInfoBanner(context, isDark),
                const SizedBox(height: AppSpacing.md),
                _buildField(
                  label: 'Subject',
                  child: DropdownButtonFormField<MessageSubject>(
                    initialValue: _subject,
                    isExpanded: true,
                    decoration: const InputDecoration(),
                    items: [
                      for (final s in MessageSubject.values)
                        DropdownMenuItem(
                          value: s,
                          child: Text(
                            s.label,
                            style: GoogleFonts.poppins(fontSize: 13.5),
                          ),
                        ),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _subject = v);
                    },
                  ),
                ),
                _field(
                  'Company Name',
                  _companyController,
                  isDark,
                  helperText: 'Optional — helpful for hiring leads',
                ),
                _field(
                  'Your Position',
                  _positionController,
                  isDark,
                  helperText: 'Optional — e.g. HR Manager, Team Lead',
                ),
                _field(
                  'Message Details',
                  _detailsController,
                  isDark,
                  maxLines: 5,
                  required: true,
                  hintText: _subject == MessageSubject.hiring
                      ? 'Tell us about the role, requirements, and how alumni can apply.'
                      : 'Describe what you would like announced or your question for the Alumni Office.',
                ),
                const SizedBox(height: AppSpacing.md),
                FilledButton(
                  onPressed: _sending ? null : () => _send(user),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: _sending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Text(
                          'Send Message',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Your Alumni Office receives this directly and may post '
                  'hiring opportunities or announcements for fellow alumni.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 11.5,
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primaryBlue),
        ),
        error: (e, _) =>
            Center(child: Text('Error: $e', style: TextStyle(color: textColor))),
      ),
    );
  }

  Widget _buildInfoBanner(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryBlue.withValues(alpha: isDark ? 0.14 : 0.08),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
          color: AppColors.primaryBlue.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.campaign_outlined, color: AppColors.primaryBlue),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Holding a recruitment or HR position? Share hiring '
              'opportunities with the Alumni Office so they can publish '
              'them as announcements for fellow alumni.',
              style: GoogleFonts.poppins(
                fontSize: 12.5,
                height: 1.5,
                color: isDark ? Colors.white : AppColors.primaryNavy,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField({
    required String label,
    required Widget child,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: AppSpacing.sm),
          child,
        ],
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController controller,
    bool isDark, {
    bool required = false,
    int maxLines = 1,
    String? helperText,
    String? hintText,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        style: GoogleFonts.poppins(
          color: isDark ? Colors.white : AppColors.primaryNavy,
          fontSize: 13.5,
        ),
        decoration: InputDecoration(
          labelText: label,
          helperText: helperText,
          hintText: hintText,
        ),
        validator: required
            ? (v) =>
                (v == null || v.trim().isEmpty) ? 'This field is required' : null
            : null,
      ),
    );
  }
}