import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../constants/app_constants.dart';
import '../../providers/audit_log_providers.dart';
import '../../repositories/content_repository.dart';
import '../../services/auth_service.dart';
import '../../utils/app_snack_bar.dart';

const _reportTypes = [
  'CHED Employment Report',
  'Alumni Tracer Study',
  'Graduate Employment Report',
  'Institutional Report',
  'Other',
];

/// Staff editor for creating a structured report. Reports are append-only
/// (staff may create/read, admins may delete, never update), so this form
/// only supports adding a new report.
class ReportEditorScreen extends ConsumerStatefulWidget {
  const ReportEditorScreen({super.key});

  @override
  ConsumerState<ReportEditorScreen> createState() =>
      _ReportEditorScreenState();
}

class _ReportEditorScreenState extends ConsumerState<ReportEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _periodController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _type = _reportTypes.first;
  bool _saving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _periodController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    final title = _titleController.text.trim();
    final data = <String, dynamic>{
      'type': _type,
      'title': title,
      'period': _periodController.text.trim().isEmpty
          ? null
          : _periodController.text.trim(),
      'description': _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
    };

    try {
      await ref.read(contentRepositoryProvider).createItem('reports', data);
      await logAudit(
        ref,
        action: 'create',
        title: 'Report added',
        description: 'Added $_type "$title".',
        targetType: 'report',
      );
      if (mounted) {
        showAppSnackBar(context, 'Report added successfully.',
            backgroundColor: AppColors.success);
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, 'Save failed: ${AuthService.friendlyError(e)}',
            backgroundColor: AppColors.error);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        elevation: 0,
        title: const Text('Add Report'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Report title'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Report type'),
              isExpanded: true,
              items: [
                for (final t in _reportTypes)
                  DropdownMenuItem(value: t, child: Text(t)),
              ],
              onChanged: (v) => setState(() => _type = v ?? _type),
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _periodController,
              decoration: const InputDecoration(
                labelText: 'Reporting period (optional)',
                hintText: 'e.g. SY 2025-2026 · Semester 1',
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _descriptionController,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Description / summary (optional)',
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Add Report'),
            ),
          ],
        ),
      ),
    );
  }
}