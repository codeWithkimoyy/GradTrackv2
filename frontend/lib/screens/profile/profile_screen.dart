import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_constants.dart';
import '../../models/user_model.dart';
import '../../providers/auth_providers.dart';
import '../../routes/app_router.dart';
import '../../utils/avatar_utils.dart';
import '../../widgets/empty_state_widget.dart';
import '../../widgets/execution_trace_button.dart';
import '../../widgets/theme_toggle_button.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentUserProfileProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: isDark ? Colors.white : AppColors.primaryNavy),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppRoutes.dashboard);
            }
          },
        ),
        title: Text(
          'My Profile',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : AppColors.primaryNavy,
          ),
        ),
        actions: [
          const ExecutionTraceButton(),
          const ThemeToggleButton(),
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: AppColors.primaryBlue),
            onPressed: () => context.push(AppRoutes.editProfile),
          ),
        ],
      ),
      body: profileAsync.when(
        data: (user) {
          if (user == null) {
            return const EmptyStateWidget(
              icon: Icons.person_off_rounded,
              title: 'No Profile Found',
              message: 'Your user profile could not be loaded.',
            );
          }
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Container(
                clipBehavior: Clip.antiAlias,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.cardDark : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isDark ? AppColors.borderDark : AppColors.borderLight,
                  ),
                  boxShadow: isDark
                      ? []
                      : const [
                          BoxShadow(
                            color: Color(0x0C0F172A),
                            blurRadius: 18,
                            offset: Offset(0, 6),
                          ),
                        ],
                ),
                child: Column(
                  children: [
                    CircleAvatar(
                          radius: 48,
                          backgroundColor: AppColors.primaryBlue.withValues(alpha: 0.15),
                          backgroundImage: user.photoUrl != null
                              ? avatarProvider(user.photoUrl)
                              : null,
                          child: user.photoUrl == null
                              ? Text(
                                  user.fullName.isNotEmpty
                                      ? user.fullName[0].toUpperCase()
                                      : '?',
                                  style: GoogleFonts.poppins(
                                    fontSize: 32,
                                    color: AppColors.primaryBlue,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          user.fullName,
                          style: GoogleFonts.poppins(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : AppColors.primaryNavy,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user.role.label,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: AppColors.teal,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.gold.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: AppColors.goldDark.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.verified_rounded,
                                  color: AppColors.goldDark, size: 16),
                              const SizedBox(width: 6),
                              Text(
                                'Verified BISU Graduate',
                                style: GoogleFonts.poppins(
                                  color: AppColors.goldDark,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
],
                    ),
                  ),
                const SizedBox(height: AppSpacing.lg),
              FilledButton.icon(
                onPressed: () => context.push(AppRoutes.editProfile),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Edit Profile'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              _InfoTile(
                  icon: Icons.email_outlined,
                  label: 'Email Address',
                  value: user.email),
              _InfoTile(
                  icon: Icons.badge_outlined,
                  label: 'Student Number',
                  value: user.studentNumber ?? 'Not provided'),
              _InfoTile(
                  icon: Icons.school_outlined,
                  label: 'Degree Program / Course',
                  value: user.course ?? AppStrings.defaultCourse),
              _InfoTile(
                  icon: Icons.school_rounded,
                  label: 'Academic Year Graduated',
                  value: (user.academicYearGraduated?.trim().isNotEmpty ??
                          false)
                      ? 'S.Y. ${displayAcademicYear(user.academicYearGraduated)}'
                      : 'Not set'),
              _InfoTile(
                  icon: Icons.calendar_today_outlined,
                  label: 'Graduation Year',
                  value: user.graduationYear?.toString() ?? 'Not set'),
              _InfoTile(
                  icon: Icons.phone_outlined,
                  label: 'Contact Phone',
                  value: user.phoneNumber ?? 'Not provided'),
              _InfoTile(
                  icon: Icons.work_outline,
                  label: 'Employment Status',
                  value: user.employmentStatus.label),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () async {
                  await ref.read(authServiceProvider).signOut();
                  if (context.mounted) context.go(AppRoutes.login);
                },
                icon: const Icon(Icons.logout_rounded, color: AppColors.error),
                label: Text(
                  'Sign Out',
                  style: GoogleFonts.poppins(
                    color: AppColors.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.error),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primaryBlue),
        ),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoTile(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
        boxShadow: isDark
            ? []
            : const [
                BoxShadow(
                  color: Color(0x0A0F172A),
                  blurRadius: 12,
                  offset: Offset(0, 2),
                ),
              ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withValues(alpha: isDark ? 0.16 : 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primaryBlue, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    fontSize: 11.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : AppColors.primaryNavy,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
