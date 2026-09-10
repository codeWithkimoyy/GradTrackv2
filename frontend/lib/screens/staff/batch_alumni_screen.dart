import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../constants/app_constants.dart';
import '../../models/user_model.dart';
import '../../providers/audit_log_providers.dart';
import '../../routes/app_router.dart';
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
  CollectionReference<Map<String, dynamic>> get _users =>
      FirebaseFirestore.instance.collection(FirestoreCollections.users);

  void _view(DocumentSnapshot<Map<String, dynamic>> doc) {
    showDialog<void>(
      context: context,
      builder: (_) => _ViewAlumniDialog(doc: doc),
    );
  }

  Future<void> _edit(DocumentSnapshot<Map<String, dynamic>> doc) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => EditUserDialog(doc: doc, adminRoleEditing: true),
    );
    if (result == true && mounted) {
      showAppSnackBar(context, 'User updated.',
          backgroundColor: AppColors.success);
      await logAudit(
        ref,
        action: 'update',
        title: 'Alumni profile edited',
        description:
            'Edited the profile of ${doc.data()?['fullName']?.toString() ?? doc.id} '
            'in batch ${academicYearLabel(widget.batchYear)}.',
        targetId: doc.id,
        targetType: 'user',
      );
    }
  }

  Future<void> _delete(DocumentSnapshot<Map<String, dynamic>> doc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete user?'),
        content: const Text(
            'This removes the user record from Firebase. This cannot be undone.'),
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
    final data = doc.data() ?? {};
    try {
      await _users.doc(doc.id).delete();
      if (mounted) {
        showAppSnackBar(context, 'User deleted.',
            backgroundColor: AppColors.success);
      }
      await logAudit(
        ref,
        action: 'delete',
        title: 'User deleted',
        description:
            'Deleted ${data['fullName']?.toString() ?? doc.id} from batch ${academicYearLabel(widget.batchYear)}.',
        targetId: doc.id,
        targetType: 'user',
      );
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, 'Delete failed: $e',
            backgroundColor: AppColors.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Batch ${academicYearLabel(widget.batchYear)} Alumni')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _users
            .where('role', isEqualTo: 'alumni')
            .where('graduationYear', isEqualTo: widget.batchYear)
            .where('hasLoggedIn', isEqualTo: true)
            .snapshots(),
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

          final docs = snapshot.data!.docs;
          final count = docs.length;
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
                      docs: docs,
                      onView: _view,
                      onEdit: _edit,
                      onDelete: _delete,
                    ),
                  ),
                )
              else
                ...docs.map(
                  (doc) => _BatchAlumniTile(
                    doc: doc,
                    onView: () => _view(doc),
                    onEdit: () => _edit(doc),
                    onDelete: () => _delete(doc),
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
  final List<DocumentSnapshot<Map<String, dynamic>>> docs;
  final void Function(DocumentSnapshot<Map<String, dynamic>>) onView;
  final void Function(DocumentSnapshot<Map<String, dynamic>>) onEdit;
  final void Function(DocumentSnapshot<Map<String, dynamic>>) onDelete;

  _BatchAlumniTableSource({
    required this.docs,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  DataRow? getRow(int index) {
    if (index >= docs.length) return null;
    final doc = docs[index];
    final data = doc.data() ?? {};
    final name = data['fullName']?.toString() ?? 'Unknown';
    final verified = data['isVerified'] == true;

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
        DataCell(Text(data['alumniId']?.toString() ?? '—')),
        DataCell(Text(
            data['course']?.toString() ?? AppStrings.defaultCourse)),
        DataCell(_verificationChip(verified)),
        DataCell(Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.visibility_outlined, size: 18),
              tooltip: 'View',
              onPressed: () => onView(doc),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 18),
              tooltip: 'Edit',
              onPressed: () => onEdit(doc),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline,
                  size: 18, color: AppColors.error),
              tooltip: 'Delete',
              onPressed: () => onDelete(doc),
            ),
          ],
        )),
      ],
    );
  }

  @override
  bool get isRowCountApproximate => false;
  @override
  int get rowCount => docs.length;
  @override
  int get selectedRowCount => 0;
}

class _BatchAlumniTile extends StatelessWidget {
  final DocumentSnapshot<Map<String, dynamic>> doc;
  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _BatchAlumniTile({
    required this.doc,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final data = doc.data() ?? {};
    final name = data['fullName']?.toString() ?? 'Unknown';
    final verified = data['isVerified'] == true;

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
          '${data['alumniId']?.toString() ?? '—'}\n'
          '${data['course']?.toString() ?? AppStrings.defaultCourse}',
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
  final DocumentSnapshot<Map<String, dynamic>> doc;

  const _ViewAlumniDialog({required this.doc});

  @override
  Widget build(BuildContext context) {
    final data = doc.data() ?? {};
    final name = data['fullName']?.toString() ?? 'Unknown';
    final verified = data['isVerified'] == true;
    final approved = data['approved'] == true;
    final employment =
        data['employmentStatus']?.toString() ?? 'unemployed';

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
            _InfoRow(label: 'Alumni ID', value: data['alumniId']?.toString() ?? '—'),
            _InfoRow(label: 'Email', value: data['email']?.toString() ?? '—'),
            _InfoRow(label: 'Course',
                value: data['course']?.toString() ?? AppStrings.defaultCourse),
            _InfoRow(label: 'Graduation Year',
                value: data['graduationYear']?.toString() ?? '—'),
            _InfoRow(label: 'Academic Year Graduated',
                value: data['academicYearGraduated']?.toString() ?? '—'),
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