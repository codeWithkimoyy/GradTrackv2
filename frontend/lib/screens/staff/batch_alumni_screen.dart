import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../constants/app_constants.dart';
import '../../models/user_model.dart';
import '../../providers/audit_log_providers.dart';
import '../../providers/auth_providers.dart';
import '../../routes/app_router.dart';
import '../../services/auth_service.dart';
import '../../utils/app_snack_bar.dart';
import '../../widgets/user_dialogs.dart';

/// Alumni of a single graduation batch who have signed in to the portal.
/// Reachable from the Batch Years dashboard (Admin → Users): role == 'alumni',
/// graduationYear == [batchYear] and hasLoggedIn == true.
class BatchAlumniScreen extends ConsumerStatefulWidget {
  final int batchYear;

  const BatchAlumniScreen({super.key, required this.batchYear});

  @override
  ConsumerState<BatchAlumniScreen> createState() => _BatchAlumniScreenState();
}

class _BatchAlumniScreenState extends ConsumerState<BatchAlumniScreen> {
  void _view(UserModel user) {
    showDialog<void>(
      context: context,
      builder: (_) => _ViewAlumniDialog(user: user),
    );
  }

  Future<void> _edit(UserModel user) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => EditUserDialog(user: user, adminRoleEditing: true),
    );
    if (result == true && mounted) {
      showAppSnackBar(context, 'User updated.',
          backgroundColor: AppColors.success);
      await logAudit(
        ref,
        action: 'update',
        title: 'Alumni profile edited',
        description:
            'Edited the profile of ${user.fullName} '
            'in batch ${academicYearLabel(widget.batchYear)}.',
        targetId: user.uid,
        targetType: 'user',
      );
    }
  }

  Future<void> _delete(UserModel user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete user?'),
        content: const Text(
            'This removes the user record from the system. This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    try {
      await ref.read(userRepositoryProvider).deleteUser(user.uid);
      if (mounted) {
        showAppSnackBar(context, 'User deleted.',
            backgroundColor: AppColors.success);
      }
      await logAudit(
        ref,
        action: 'delete',
        title: 'User deleted',
        description:
            'Deleted ${user.fullName} from batch ${academicYearLabel(widget.batchYear)}.',
        targetId: user.uid,
        targetType: 'user',
      );
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, 'Delete failed: ${AuthService.friendlyError(e)}',
            backgroundColor: AppColors.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Batch ${academicYearLabel(widget.batchYear)} Alumni')),
      body: StreamBuilder<List<UserModel>>(
        stream: ref
            .watch(userRepositoryProvider)
            .watchUsers(role: 'alumni', limit: 500),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                    'Unable to load this batch.\n\n${snapshot.error}',
                    textAlign: TextAlign.center),
              ),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final users = (snapshot.data ?? const <UserModel>[])
              .where((u) =>
                  u.graduationYear == widget.batchYear && u.hasLoggedIn)
              .toList();
          final count = users.length;
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final wide = MediaQuery.sizeOf(context).width >= 900;

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => context.go(AppRoutes.adminUsers),
                  icon: const Icon(Icons.arrow_back_rounded, size: 18),
                  label: const Text('Back to Batch Years'),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              _buildHeader(context, count, isDark),
              const SizedBox(height: AppSpacing.md),
              if (count == 0)
                _buildEmptyState(context, isDark)
              else if (wide)
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: PaginatedDataTable(
                    header: Text(
                        '$count Registered Alumni in Batch ${academicYearLabel(widget.batchYear)}'),
                    rowsPerPage: count < 10 ? count : 10,
                    columns: const [
                      DataColumn(label: Text('Alumni')),
                      DataColumn(label: Text('Alumni ID')),
                      DataColumn(label: Text('Course')),
                      DataColumn(label: Text('Verification Status')),
                      DataColumn(label: Text('Actions')),
                    ],
                    source: _BatchAlumniTableSource(
                      users: users,
                      onView: _view,
                      onEdit: _edit,
                      onDelete: _delete,
                    ),
                  ),
                )
              else
                ...users.map(
                  (user) => _BatchAlumniTile(
                    user: user,
                    onView: () => _view(user),
                    onEdit: () => _edit(user),
                    onDelete: () => _delete(user),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context, int count, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.bisuBlue700.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(15),
          ),
          child:
              const Icon(Icons.school_outlined, color: AppColors.bisuBlue700, size: 24),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Batch ${academicYearLabel(widget.batchYear)} Alumni',
                style: GoogleFonts.poppins(
                  fontSize: 23,
                  fontWeight: FontWeight.w700,
                  height: 1.15,
                  color: isDark ? Colors.white : AppColors.primaryNavy,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.person_outline_rounded,
                      size: 15,
                      color: isDark ? const Color(0xFF94A3B8) : AppColors.teal),
                  const SizedBox(width: 5),
                  Text(
                    '$count registered alumni who have signed in',
                    style: GoogleFonts.poppins(
                      fontSize: 12.5,
                      color: isDark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: AppColors.bisuBlue700.withValues(alpha: .12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.school_outlined,
                size: 42, color: AppColors.bisuBlue700),
          ),
          const SizedBox(height: 18),
          Text(
            'No alumni have signed in for batch ${academicYearLabel(widget.batchYear)} yet.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : AppColors.primaryNavy,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Once a graduate logs in, they appear here automatically.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 12.5,
              color:
                  isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.length > 1) return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  return name.isEmpty ? '?' : name[0].toUpperCase();
}

Widget _verificationChip(bool verified) {
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (verified)
        const Icon(Icons.verified_rounded, size: 16, color: AppColors.success)
      else
        const Icon(Icons.pending_outlined, size: 16, color: AppColors.warning),
      const SizedBox(width: 4),
      Text(verified ? 'Verified' : 'Pending',
          style: const TextStyle(fontSize: 12)),
    ],
  );
}

class _BatchAlumniTableSource extends DataTableSource {
  final List<UserModel> users;
  final void Function(UserModel) onView;
  final void Function(UserModel) onEdit;
  final void Function(UserModel) onDelete;

  _BatchAlumniTableSource({
    required this.users,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  DataRow? getRow(int index) {
    if (index >= users.length) return null;
    final user = users[index];
    final name = user.fullName.isEmpty ? 'Unknown' : user.fullName;
    final verified = user.isVerified;

    return DataRow.byIndex(
      index: index,
      cells: [
        DataCell(Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: AppColors.bisuBlue700.withValues(alpha: .12),
              child: Text(
                _initials(name),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppColors.bisuBlue700,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        )),
        DataCell(Text(user.alumniId ?? '—')),
        DataCell(Text(
            user.course ?? AppStrings.defaultCourse)),
        DataCell(_verificationChip(verified)),
        DataCell(Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.visibility_outlined, size: 18),
              tooltip: 'View',
              onPressed: () => onView(user),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 18),
              tooltip: 'Edit',
              onPressed: () => onEdit(user),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline,
                  size: 18, color: AppColors.error),
              tooltip: 'Delete',
              onPressed: () => onDelete(user),
            ),
          ],
        )),
      ],
    );
  }

  @override
  bool get isRowCountApproximate => false;
  @override
  int get rowCount => users.length;
  @override
  int get selectedRowCount => 0;
}

class _BatchAlumniTile extends StatelessWidget {
  final UserModel user;
  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _BatchAlumniTile({
    required this.user,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final name = user.fullName.isEmpty ? 'Unknown' : user.fullName;
    final verified = user.isVerified;

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.bisuBlue700.withValues(alpha: .12),
          child: Text(_initials(name),
              style: const TextStyle(
                  color: AppColors.bisuBlue700, fontWeight: FontWeight.bold)),
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
            const SizedBox(width: 6),
            _verificationChip(verified),
          ],
        ),
        subtitle: Text(
          '${user.alumniId ?? '—'}\n'
          '${user.course ?? AppStrings.defaultCourse}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
              tooltip: 'View',
              icon: const Icon(Icons.visibility_outlined, size: 20),
              onPressed: onView,
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
              tooltip: 'Edit',
              icon: const Icon(Icons.edit_outlined, size: 20),
              onPressed: onEdit,
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.error),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

class _ViewAlumniDialog extends StatelessWidget {
  final UserModel user;

  const _ViewAlumniDialog({required this.user});

  @override
  Widget build(BuildContext context) {
    final name = user.fullName.isEmpty ? 'Unknown' : user.fullName;
    final verified = user.isVerified;
    final approved = user.approved;
    final employment = user.employmentStatus.name;

    return AlertDialog(
      title: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.bisuBlue700.withValues(alpha: .12),
            child: Text(_initials(name),
                style: const TextStyle(
                    color: AppColors.bisuBlue700,
                    fontWeight: FontWeight.w700,
                    fontSize: 17)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                _verificationChip(verified),
              ],
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _InfoRow(label: 'Alumni ID', value: user.alumniId ?? '—'),
            _InfoRow(label: 'Email', value: user.email.isEmpty ? '—' : user.email),
            _InfoRow(label: 'Course',
                value: user.course ?? AppStrings.defaultCourse),
            _InfoRow(label: 'Graduation Year',
                value: user.graduationYear?.toString() ?? '—'),
            _InfoRow(label: 'Academic Year Graduated',
                value: user.academicYearGraduated ?? '—'),
            _InfoRow(
                label: 'Employment Status',
                value: _employmentLabel(employment)),
            _InfoRow(label: 'Account Status',
                value: approved ? 'Approved' : 'Pending approval'),
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Done'),
        ),
      ],
    );
  }

  String _employmentLabel(String name) => switch (name) {
        'employed' => 'Employed',
        'selfEmployed' => 'Self-employed',
        'freelance' => 'Freelance',
        'studying' => 'Continuing Studies',
        _ => 'Unemployed',
      };
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
          ),
        ],
      ),
    );
  }
}