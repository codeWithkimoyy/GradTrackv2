import 'dart:convert';
import 'dart:typed_data';

import 'package:excel/excel.dart' deferred as excel_pkg hide StringExt, BoolParsing;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../constants/app_constants.dart';
import '../../models/user_model.dart';
import '../../providers/audit_log_providers.dart';
import '../../providers/auth_providers.dart';
import '../../repositories/user_repository.dart';
import '../../services/auth_service.dart';
import '../../utils/app_snack_bar.dart';

/// Admin module managing the alumni registry — the pre-approved list of
/// Alumni IDs that may create accounts. Every record starts as Pending;
/// alumni activate their own ID by creating a password.
class AlumniManagementScreen extends ConsumerStatefulWidget {
  const AlumniManagementScreen({super.key});

  @override
  ConsumerState<AlumniManagementScreen> createState() =>
      _AlumniManagementScreenState();
}

class _AlumniManagementScreenState extends ConsumerState<AlumniManagementScreen> {
  bool _importing = false;
  bool _showUnassigned = false;

  /// Selection in batch view: start year of the academic-year pair (e.g.
  /// 2020 for batch "2020-2021"). Null shows the full batch grid.
  int? _selectedBatchStart;

  /// Earliest batch shown in the Alumni module.
  static const int _firstBatchYear = 2020;

  /// Batch start years to render, newest first: last finished school year
  /// down to [_firstBatchYear].
  List<int> get _batchStartYears =>
      [for (var year = (DateTime.now().year - 1); year >= _firstBatchYear; year--) year];

  /// Derives the batch (academic-year start) an entry belongs to. Legacy
  /// records with only a numeric graduation year are treated as graduating
  /// in the school year that ends that year (e.g. 2021 -> batch "2020-2021").
  int? _batchStartYearOf(AlumniRegistryEntry entry) {
    final start = academicYearStart(entry.academicYearGraduated);
    if (start != null) return start;
    final gy = entry.graduationYear;
    return gy == null ? null : gy - 1;
  }

  bool _matchesSelected(AlumniRegistryEntry entry) {
    if (_showUnassigned) return _batchStartYearOf(entry) == null;
    return _batchStartYearOf(entry) == _selectedBatchStart;
  }

  Future<void> _addAlumni() async {
    final entry = await showDialog<AlumniRegistryEntry>(
      context: context,
      builder: (_) => const _AddAlumniDialog(),
    );
    if (entry == null || !mounted) return;

    try {
      final repo = ref.read(userRepositoryProvider);
      final existing = await repo.fetchRegistryEntry(entry.alumniId);
      if (existing != null) {
        if (!mounted) return;
        showAppSnackBar(
          context,
          'Alumni ID ${entry.alumniId} already exists in the registry.',
          backgroundColor: AppColors.warning,
        );
        return;
      }
      await repo.saveRegistryEntry(entry);
      await logAudit(
        ref,
        action: 'create',
        title: 'Alumni added',
        description:
            'Added Alumni ID ${entry.alumniId} for ${entry.fullName} '
            '(${entry.course}, ${entry.graduationYear ?? '—'}).',
        targetId: entry.alumniId,
        targetType: 'alumni_registry',
      );
      if (!mounted) return;
      showAppSnackBar(context, 'Alumni ID ${entry.alumniId} added. '
          'Status: Pending.',
          backgroundColor: AppColors.success);
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, 'Could not add alumni: $e',
            backgroundColor: AppColors.error);
      }
    }
  }

  Future<void> _import() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'xlsx'],
    );
    if (result.isEmpty) return;
    final pickedBytes = await result.single.readAsBytes();
    if (pickedBytes.isEmpty) return;
    if (!mounted) return;
    setState(() => _importing = true);

    try {
      final repo = ref.read(userRepositoryProvider);
      if (result.single.name.toLowerCase().endsWith('.xlsx')) {
        // The spreadsheet parser is a deferred library: load it on demand
        // so the first paint never pays for it.
        await excel_pkg.loadLibrary();
      }
      final records = _parseFile(result.single.name, pickedBytes);

      var added = 0;
      var skipped = 0;
      var invalid = 0;
      for (final record in records) {
        if (record.alumniId.isEmpty ||
            !AppStrings.alumniIdPattern.hasMatch(record.alumniId) ||
            record.fullName.trim().isEmpty) {
          invalid++;
          continue;
        }
        final existing =
            await repo.fetchRegistryEntry(record.alumniId);
        if (existing != null) {
          skipped++;
          continue;
        }
        await repo.saveRegistryEntry(record);
        added++;
      }

      if (mounted) {
        showAppSnackBar(
          context,
          'Import finished: $added added, $skipped skipped (already exist), '
          '$invalid invalid rows.',
          backgroundColor: added > 0 ? AppColors.success : AppColors.warning,
        );
      }
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, 'Import failed: $e',
            backgroundColor: AppColors.error);
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  List<AlumniRegistryEntry> _parseFile(String name, Uint8List bytes) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.csv')) {
      return _parseCsv(utf8Decode(bytes));
    }
    if (lower.endsWith('.xlsx')) {
      return _parseXlsx(bytes);
    }
    throw Exception('Unsupported file type. Use .csv or .xlsx');
  }

  String utf8Decode(Uint8List bytes) =>
      utf8.decode(bytes, allowMalformed: true);

  List<AlumniRegistryEntry> _parseCsv(String content) {
    final entries = <AlumniRegistryEntry>[];
    final lines = content.split(RegExp(r'\r?\n'));
    for (final line in lines) {
      final cells =
          line.split(',').map((c) => c.trim()).where((c) => c.isNotEmpty).toList();
      if (cells.length < 2) continue;
      final alumniId = cells[0];
      final fullName = cells[1];
      final course = cells.length > 2 && cells[2].isNotEmpty
          ? cells[2]
          : AppStrings.defaultCourse;
      final year = cells.length > 3 ? int.tryParse(cells[3].replaceAll('"', '')) : null;
      // Skip header rows that don't look like Alumni IDs.
      if (!AppStrings.alumniIdPattern.hasMatch(alumniId) &&
          alumniId.toLowerCase().contains('alumni')) {
        continue;
      }
      entries.add(AlumniRegistryEntry(
        alumniId: alumniId,
        fullName: fullName,
        course: course,
        graduationYear: year,
      ));
    }
    return entries;
  }

  List<AlumniRegistryEntry> _parseXlsx(Uint8List bytes) {
    final workbook = excel_pkg.Excel.decodeBytes(bytes);
    final entries = <AlumniRegistryEntry>[];
    for (final table in workbook.tables.values) {
      for (final row in table.rows) {
        if (row.length < 2) continue;
        String cell(int index) =>
            row[index]?.value?.toString().trim() ?? '';
        final alumniId = cell(0);
        final fullName = cell(1);
        if (alumniId.isEmpty || fullName.isEmpty) continue;
        if (!AppStrings.alumniIdPattern.hasMatch(alumniId) &&
            alumniId.toLowerCase().contains('alumni')) {
          continue;
        }
        final course = cell(2).isNotEmpty
            ? cell(2)
            : AppStrings.defaultCourse;
        final year = int.tryParse(cell(3).replaceAll(RegExp(r'[^0-9]'), ''));
        entries.add(AlumniRegistryEntry(
          alumniId: alumniId,
          fullName: fullName,
          course: course,
          graduationYear: year,
        ));
      }
    }
    return entries;
  }

  Future<void> _edit(AlumniRegistryEntry entry) async {
    final updated = await showDialog<AlumniRegistryEntry>(
      context: context,
      builder: (_) => _AddAlumniDialog(existing: entry, isEdit: true),
    );
    if (updated == null || !mounted) return;
    try {
      await ref.read(userRepositoryProvider).saveRegistryEntry(updated);
      if (mounted) {
        showAppSnackBar(context, 'Alumni record updated.',
            backgroundColor: AppColors.success);
      }
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, 'Save failed: $e',
            backgroundColor: AppColors.error);
      }
    }
  }

  Future<void> _toggleStatus(AlumniRegistryEntry entry) async {
    final repo = ref.read(userRepositoryProvider);
    final isDisabled = entry.status == AlumniAccountStatus.disabled;
    final accountUid = await repo.findUserByAlumniId(entry.alumniId);
    final hasAccount = accountUid != null;

    final nextStatus = isDisabled
        ? (hasAccount ? AlumniAccountStatus.active : AlumniAccountStatus.pending)
        : AlumniAccountStatus.disabled;

    try {
      await repo.updateRegistryStatus(entry.alumniId, nextStatus);
      if (accountUid != null) {
        await repo.updateUser(accountUid, {'disabled': !isDisabled});
      }
      await logAudit(
        ref,
        action: 'update',
        title: isDisabled ? 'Alumni re-enabled' : 'Alumni disabled',
        description:
            '${isDisabled ? 'Re-enabled' : 'Disabled'} Alumni ID '
            '${entry.alumniId} (${entry.fullName}).',
        targetId: entry.alumniId,
        targetType: 'alumni_registry',
      );
      if (mounted) {
        showAppSnackBar(
          context,
          hasAccount
              ? 'Alumni ID ${entry.alumniId} is now ${nextStatus.label}.'
              : 'Alumni ID ${entry.alumniId} is now ${nextStatus.label}. '
                  'They can register when it is Pending.',
          backgroundColor: AppColors.success,
        );
      }
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, 'Could not update status: $e',
            backgroundColor: AppColors.error);
      }
    }
  }

  Future<void> _resetPassword(AlumniRegistryEntry entry) async {
    if (entry.status != AlumniAccountStatus.active) {
      showAppSnackBar(
        context,
        'This alumni has no account yet (status: ${entry.status.label}).',
        backgroundColor: AppColors.warning,
      );
      return;
    }

    final newPassword = await showDialog<String>(
      context: context,
      builder: (_) => const _ResetPasswordDialog(),
    );
    if (newPassword == null || !mounted) return;

    setState(() => _importing = true);
    try {
      final repo = ref.read(userRepositoryProvider);
      final accountUid = await repo.findUserByAlumniId(entry.alumniId);
      if (accountUid == null) {
        throw StateError('This alumni has no account yet.');
      }
      await repo.adminResetPassword(accountUid, newPassword);
      await logAudit(
        ref,
        action: 'update',
        title: 'Password reset',
        description:
            'Reset the password for Alumni ID ${entry.alumniId} '
            '(${entry.fullName}).',
        targetId: entry.alumniId,
        targetType: 'alumni_registry',
      );
      if (!mounted) return;
      showAppSnackBar(
        context,
        'Password for ${entry.alumniId} was updated. Share the new password with the alumni.',
        backgroundColor: AppColors.success,
        duration: const Duration(seconds: 12),
      );
    } catch (e) {
      if (mounted) {
        showAppSnackBar(
          context,
          'Could not reset password: ${AuthService.friendlyError(e)}',
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 10),
        );
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _delete(AlumniRegistryEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Delete Alumni Record'),
        content: Text(
          'Remove Alumni ID "${entry.alumniId}" for ${entry.fullName}? '
          'If this alumni has an account, their sign-in access will also be '
          'disabled.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      final repo = ref.read(userRepositoryProvider);
      final accountUid = await repo.findUserByAlumniId(entry.alumniId);
      await repo.removeRegistryEntry(entry.alumniId);
      if (accountUid != null) {
        await repo.updateUser(accountUid, {'disabled': true});
      }
      await logAudit(
        ref,
        action: 'delete',
        title: 'Alumni record deleted',
        description:
            'Deleted Alumni ID ${entry.alumniId} (${entry.fullName}).',
        targetId: entry.alumniId,
        targetType: 'alumni_registry',
      );
      if (mounted) {
        showAppSnackBar(context, 'Alumni record deleted.',
            backgroundColor: AppColors.success);
      }
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, 'Delete failed: $e',
            backgroundColor: AppColors.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(userRepositoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Alumni Management')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _importing ? null : _addAlumni,
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Add Alumni'),
      ),
      body: StreamBuilder<List<AlumniRegistryEntry>>(
        stream: repo.watchRegistry(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'Could not load the alumni registry.\n\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final entries = snapshot.data ?? const <AlumniRegistryEntry>[];
          final pending =
              entries.where((e) => e.status == AlumniAccountStatus.pending).length;
          final active =
              entries.where((e) => e.status == AlumniAccountStatus.active).length;
          final disabled = entries
              .where((e) => e.status == AlumniAccountStatus.disabled)
              .length;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _StatChip(label: 'Total', value: entries.length,
                        color: AppColors.primaryBlue),
                    _StatChip(label: 'Pending', value: pending,
                        color: AppColors.warning),
                    _StatChip(label: 'Active', value: active,
                        color: AppColors.success),
                    _StatChip(label: 'Disabled', value: disabled,
                        color: AppColors.error),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: _importing ? null : _import,
                      icon: _importing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.upload_file_outlined, size: 18),
                      label: Text(_importing ? 'Importing…' : 'Import CSV / Excel'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: entries.isEmpty
                    ? _buildEmptyState()
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          if (_showUnassigned ||
                              _selectedBatchStart != null) {
                            return _buildBatchDetail(entries);
                          }
                          if (constraints.maxWidth >= 900) {
                            return _buildBatchGrid(entries);
                          }
                          return _buildBatchGrid(entries);
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBatchGrid(List<AlumniRegistryEntry> entries) {
    final counts = <int, int>{for (final y in _batchStartYears) y: 0};
    var unassigned = 0;
    for (final entry in entries) {
      final start = _batchStartYearOf(entry);
      if (start == null) {
        unassigned++;
      } else if (counts.containsKey(start)) {
        counts[start] = counts[start]! + 1;
      }
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
      children: [
        Text(
          'ALUMNI BY BATCH',
          style: GoogleFonts.poppins(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.3,
            color: AppColors.teal,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          'Registered alumni in the registry, grouped by school year',
          style: GoogleFonts.poppins(
            fontSize: 12.5,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _batchStartYears.length + 1,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: 108,
          ),
          itemBuilder: (context, index) {
            if (index == _batchStartYears.length) {
              return _BatchCard(
                title: 'Not Assigned',
                subtitle: 'Alumni without a batch',
                count: unassigned,
                color: AppColors.warning,
                icon: Icons.help_outline_rounded,
                onTap: () => setState(() {
                  _selectedBatchStart = null;
                  _showUnassigned = true;
                }),
              );
            }
            final startYear = _batchStartYears[index];
            return _BatchCard(
              title: academicYearLabel(startYear),
              subtitle: 'S.Y. batch',
              count: counts[startYear] ?? 0,
              color: AppColors.bisuBlue700,
              icon: Icons.school_outlined,
              onTap: () => setState(() {
                _showUnassigned = false;
                _selectedBatchStart = startYear;
              }),
            );
          },
        ),
      ],
    );
  }

  Widget _buildBatchDetail(List<AlumniRegistryEntry> entries) {
    final filtered = entries.where(_matchesSelected).toList();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final batchTitle = _showUnassigned
        ? 'Unassigned Alumni'
        : 'S.Y. $_selectedBatchStart\u2013${_selectedBatchStart! + 1}';

    return LayoutBuilder(
      builder: (context, constraints) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Back to batches',
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: () => setState(() {
                      _selectedBatchStart = null;
                      _showUnassigned = false;
                    }),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          batchTitle,
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : AppColors.primaryNavy,
                          ),
                        ),
                        Text(
                          '${filtered.length} alumni record(s)',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        'No alumni in this batch yet.',
                        style: GoogleFonts.poppins(color: AppColors.textSecondary),
                      ),
                    )
                  : (constraints.maxWidth >= 900
                      ? _buildTable(filtered)
                      : _buildCards(filtered)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.school_outlined,
              size: 56, color: AppColors.primaryBlue.withValues(alpha: 0.4)),
          const SizedBox(height: 12),
          Text(
            'No alumni in the registry yet.',
            style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            'Add alumni individually or import a CSV/Excel file. '
            'Every added ID starts as Pending.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
                fontSize: 12.5, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildTable(List<AlumniRegistryEntry> entries) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        clipBehavior: Clip.antiAlias,
        elevation: 0,
        color: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: BorderSide(color: Theme.of(context).dividerColor),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowHeight: 50,
            dataRowMinHeight: 52,
            dataRowMaxHeight: 72,
            columns: const [
              DataColumn(label: Text('Alumni ID')),
              DataColumn(label: Text('Name')),
              DataColumn(label: Text('Course')),
              DataColumn(label: Text('Graduation Year')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Actions')),
            ],
            rows: [
              for (final entry in entries)
                DataRow(cells: [
                  DataCell(Text(entry.alumniId,
                      style: const TextStyle(fontWeight: FontWeight.w600))),
                  DataCell(Text(entry.fullName)),
                  DataCell(Text(entry.course)),
                  DataCell(Text(entry.graduationYear?.toString() ?? '—')),
                  DataCell(_StatusChip(status: entry.status)),
                  DataCell(_RowActions(
                    entry: entry,
                    onEdit: () => _edit(entry),
                    onToggleStatus: () => _toggleStatus(entry),
                    onResetPassword: () => _resetPassword(entry),
                    onDelete: () => _delete(entry),
                  )),
                ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCards(List<AlumniRegistryEntry> entries) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
      children: [
        for (final entry in entries)
          Card(
            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor:
                    AppColors.primaryBlue.withValues(alpha: .12),
                child: const Icon(Icons.school_outlined, color: AppColors.primaryBlue),
              ),
              title: Row(
                children: [
                  Flexible(
                    child: Text(entry.alumniId,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 8),
                  _StatusChip(status: entry.status),
                ],
              ),
              subtitle: Text(
                '${entry.fullName}\n'
                '${entry.course} · ${entry.graduationYear ?? '—'}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              trailing: _RowActions(
                entry: entry,
                onEdit: () => _edit(entry),
                onToggleStatus: () => _toggleStatus(entry),
                onResetPassword: () => _resetPassword(entry),
                onDelete: () => _delete(entry),
              ),
            ),
          ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value, required this.color});

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$value ',
              style: GoogleFonts.poppins(
                  color: color, fontWeight: FontWeight.w800, fontSize: 14)),
          Text(label,
              style: GoogleFonts.poppins(
                  color: color.withValues(alpha: 0.85), fontSize: 12.5)),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final AlumniAccountStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      AlumniAccountStatus.pending => AppColors.warning,
      AlumniAccountStatus.active => AppColors.success,
      AlumniAccountStatus.disabled => AppColors.error,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        status.label,
        style: GoogleFonts.poppins(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _RowActions extends StatelessWidget {
  const _RowActions({
    required this.entry,
    required this.onEdit,
    required this.onToggleStatus,
    required this.onResetPassword,
    required this.onDelete,
  });

  final AlumniRegistryEntry entry;
  final VoidCallback onEdit;
  final VoidCallback onToggleStatus;
  final VoidCallback onResetPassword;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final isDisabled = entry.status == AlumniAccountStatus.disabled;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          visualDensity: VisualDensity.compact,
          tooltip: 'Edit',
          icon: const Icon(Icons.edit_outlined, size: 18),
          onPressed: onEdit,
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          tooltip: isDisabled ? 'Re-enable' : 'Disable',
          icon: Icon(
            isDisabled ? Icons.lock_open_rounded : Icons.lock_outline,
            size: 18,
            color: isDisabled ? AppColors.success : AppColors.warning,
          ),
          onPressed: onToggleStatus,
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          tooltip: 'Reset Password',
          icon: const Icon(Icons.password_rounded, size: 18),
          onPressed: onResetPassword,
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          tooltip: 'Delete',
          icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.error),
          onPressed: onDelete,
        ),
      ],
    );
  }
}

class _AddAlumniDialog extends StatefulWidget {
  const _AddAlumniDialog({this.existing, this.isEdit = false});

  final AlumniRegistryEntry? existing;
  final bool isEdit;

  @override
  State<_AddAlumniDialog> createState() => _AddAlumniDialogState();
}

class _AddAlumniDialogState extends State<_AddAlumniDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _alumniId;
  late final TextEditingController _fullName;
  late final TextEditingController _course;
  String? _batch;

  static const int _firstBatchYear = 2020;

  /// Batch choices, newest first. Kept in the stored "YYYY-YYYY" (hyphen)
  /// format and always includes the current [_batch] so the dropdown can
  /// display an existing value even when it falls outside the range or was
  /// stored with a different separator.
  List<String> get _batchOptions {
    final years = <String>{};
    for (var year = (DateTime.now().year - 1); year >= _firstBatchYear; year--) {
      years.add('$year-${year + 1}');
    }
    final stored = _batch?.trim().replaceAll('–', '-');
    if (stored != null && stored.isNotEmpty) years.add(stored);
    final list = years.toList()
      ..sort((a, b) => (academicYearStart(b) ?? 0)
          .compareTo(academicYearStart(a) ?? 0));
    return list;
  }

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _alumniId = TextEditingController(text: existing?.alumniId ?? '');
    _fullName = TextEditingController(text: existing?.fullName ?? '');
    _course = TextEditingController(
        text: existing?.course ?? AppStrings.defaultCourse);
    final storedBatch = existing?.academicYearGraduated ??
        (existing?.graduationYear == null
            ? null
            : academicYearLabel(existing!.graduationYear! - 1));
    _batch = storedBatch?.trim().replaceAll('–', '-');
  }

  @override
  void dispose() {
    _alumniId.dispose();
    _fullName.dispose();
    _course.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final base = widget.existing;
    final selected = (_batch == null || _batch!.isEmpty) ? null : _batch;
    final startYear = selected == null ? null : academicYearStart(selected);
    Navigator.pop(
      context,
      AlumniRegistryEntry(
        alumniId: _alumniId.text.trim(),
        fullName: _fullName.text.trim(),
        course: _course.text.trim().isEmpty
            ? AppStrings.defaultCourse
            : _course.text.trim(),
        academicYearGraduated: selected,
        graduationYear: startYear == null ? null : startYear + 1,
        status: base?.status ?? AlumniAccountStatus.pending,
        activatedAt: base?.activatedAt,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.isEdit;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(isEdit ? 'Edit Alumni' : 'Add Alumni'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _alumniId,
                readOnly: isEdit,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: 'Alumni ID',
                  helperText: isEdit
                      ? 'The Alumni ID is permanent and cannot be changed.'
                      : null,
                ),
                validator: (v) {
                  if (isEdit) return null;
                  final val = v?.trim() ?? '';
                  if (val.isEmpty) return 'Alumni ID is required.';
                  if (val.contains(' ')) {
                    return 'Alumni ID must not contain spaces.';
                  }
                  if (!AppStrings.alumniIdPattern.hasMatch(val)) {
                    return 'Letters, numbers, hyphens and underscores only.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _fullName,
                decoration: const InputDecoration(labelText: 'Full Name'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Full name is required.' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _course,
                decoration: const InputDecoration(labelText: 'Course'),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Course is required.' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _batch,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Batch / School Year',
                  helperText: 'e.g. S.Y. 2020\u20132021',
                ),
                items: [
                  const DropdownMenuItem<String>(
                    value: '',
                    child: Text('Not Specified'),
                  ),
                  for (final option in _batchOptions)
                    DropdownMenuItem<String>(
                      value: option,
                      child: Text('S.Y. $option'),
                    ),
                ],
                onChanged: (value) => setState(() => _batch = value),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _submit,
            child: Text(isEdit ? 'Save Changes' : 'Add Alumni')),
      ],
    );
  }
}

class _ResetPasswordDialog extends StatefulWidget {
  const _ResetPasswordDialog();

  @override
  State<_ResetPasswordDialog> createState() => _ResetPasswordDialogState();
}

class _ResetPasswordDialogState extends State<_ResetPasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.pop(context, _passwordController.text);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Text('Reset Alumni Password'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Set a new password for this alumni. Share the temporary '
              'password with them and ask them to change it after signing in.',
              style: GoogleFonts.poppins(fontSize: 12.5, height: 1.4),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _passwordController,
              obscureText: _obscure,
              decoration: InputDecoration(
                labelText: 'New Temporary Password',
                suffixIcon: IconButton(
                  icon: Icon(_obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              validator: (v) =>
                  (v == null || v.length < 6) ? 'Minimum 6 characters' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _confirmController,
              obscureText: _obscure,
              decoration: const InputDecoration(labelText: 'Confirm Password'),
              validator: (v) => v != _passwordController.text
                  ? 'Passwords do not match'
                  : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _submit, child: const Text('Reset Password')),
      ],
    );
  }
}

class _BatchCard extends StatelessWidget {
  const _BatchCard({
    required this.title,
    required this.subtitle,
    required this.count,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final int count;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.card),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark
              ? Theme.of(context).colorScheme.surface
              : Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(
            color: color.withValues(alpha: 0.3),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$count alumni · $subtitle',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 11.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: color.withValues(alpha: 0.7)),
          ],
        ),
      ),
    );
  }
}