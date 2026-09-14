import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_constants.dart';
import '../models/user_model.dart';
import '../providers/auth_providers.dart';
import '../services/auth_service.dart';
import '../utils/academic_year_utils.dart';
import '../utils/app_snack_bar.dart';

/// Payload returned by [AddUserDialog].
class NewUserData {
  final String fullName;
  final String email;
  final String password;
  final String alumniId;
  final String course;
  final UserRole role;

  const NewUserData({
    required this.fullName,
    this.email = '',
    this.password = '',
    this.alumniId = '',
    this.course = AppStrings.defaultCourse,
    required this.role,
  });
}

class AddUserDialog extends StatefulWidget {
  const AddUserDialog({super.key});

  @override
  State<AddUserDialog> createState() => _AddUserDialogState();
}

class _AddUserDialogState extends State<AddUserDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _alumniId = TextEditingController();
  final _course = TextEditingController(text: AppStrings.defaultCourse);
  UserRole _role = UserRole.alumni;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _alumniId.dispose();
    _course.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      NewUserData(
        fullName: _name.text.trim(),
        email: _email.text.trim(),
        password: _password.text,
        alumniId: _alumniId.text.trim(),
        course: _course.text.trim(),
        role: _role,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAlumni = _role == UserRole.alumni;

    return AlertDialog(
      title: const Text('Add User'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Full name'),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Full name is required.'
                    : null,
              ),
              const SizedBox(height: 12),
              if (isAlumni) ...[
                TextFormField(
                  controller: _alumniId,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'Alumni ID',
                    helperText:
                        'Form one for each graduate. The alumni uses this ID '
                        'to create their account.',
                  ),
                  validator: (v) {
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
                  controller: _course,
                  decoration:
                      const InputDecoration(labelText: 'Course'),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Required.' : null,
                ),
              ] else ...[
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration:
                      const InputDecoration(labelText: 'Email address'),
                  validator: (v) {
                    final val = v?.trim() ?? '';
                    if (val.isEmpty) return 'Email is required.';
                    if (!val.contains('@') || !val.contains('.')) {
                      return 'Enter a valid email address.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _password,
                  obscureText: true,
                  decoration: const InputDecoration(
                      labelText: 'Temporary password (min 6 characters)'),
                  validator: (v) => (v == null || v.length < 6)
                      ? 'Password must be at least 6 characters.'
                      : null,
                ),
              ],
              const SizedBox(height: 12),
              DropdownButtonFormField<UserRole>(
                initialValue: _role,
                decoration: const InputDecoration(labelText: 'Role'),
                items: [
                  for (final role in UserRole.values)
                    DropdownMenuItem(value: role, child: Text(role.label)),
                ],
                onChanged: (v) => setState(() => _role = v ?? UserRole.alumni),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(onPressed: _submit, child: const Text('Create')),
      ],
    );
  }
}

class EditUserDialog extends ConsumerStatefulWidget {
  final UserModel user;
  final bool adminRoleEditing;

  const EditUserDialog({
    super.key,
    required this.user,
    required this.adminRoleEditing,
  });

  @override
  ConsumerState<EditUserDialog> createState() => _EditUserDialogState();
}

class _EditUserDialogState extends ConsumerState<EditUserDialog> {
  late final TextEditingController _name;
  late final TextEditingController _course;
  late final TextEditingController _gradYear;
  late final TextEditingController _alumniId;
  late String _role;
  late String _status;
  late bool _verified;
  late bool _approved;
  String? _academicYear;

  /// The stored academic year (e.g. "2025-2026") mapped onto the dropdown's
  /// option list (en-dashes, e.g. "2025–2026"), so an existing value is
  /// shown instead of the empty "Select Academic Year" placeholder.
  String? get _academicYearDropdownValue {
    final raw = _academicYear?.trim().replaceAll('–', '-');
    if (raw == null || raw.isEmpty) return null;
    final normalized = raw.replaceAll('-', '–').toLowerCase();
    for (final option in AcademicYearUtils.options()) {
      if (option.toLowerCase() == normalized) return option;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    final user = widget.user;
    _name = TextEditingController(text: user.fullName);
    _course = TextEditingController(
        text: user.course?.trim().isNotEmpty == true
            ? user.course!
            : AppStrings.defaultCourse);
    _gradYear = TextEditingController(
        text: user.graduationYear?.toString() ?? '');
    _alumniId = TextEditingController(text: user.alumniId ?? '');
    _role = user.role.name;
    _status = user.employmentStatus.name;
    _verified = user.isVerified;
    _approved = user.approved;
    _academicYear = user.academicYearGraduated;
  }

  @override
  void dispose() {
    _name.dispose();
    _course.dispose();
    _gradYear.dispose();
    _alumniId.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final changes = <String, dynamic>{
      'fullName': _name.text.trim(),
      'course': _course.text.trim().isEmpty ? AppStrings.defaultCourse : _course.text.trim(),
      'graduationYear': int.tryParse(_gradYear.text.trim()),
      'academicYearGraduated':
          (_academicYear == null || _academicYear!.isEmpty) ? null : _academicYear,
      'employmentStatus': _status,
      'isVerified': _verified,
    };
    if (widget.adminRoleEditing) {
      changes['role'] = _role;
    }
    changes['approved'] = _approved;
    try {
      await ref
          .read(userRepositoryProvider)
          .updateUser(widget.user.uid, changes);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, 'Save failed: ${AuthService.friendlyError(e)}',
            backgroundColor: AppColors.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit User'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Full name')),
            const SizedBox(height: 12),
            if (_alumniId.text.isNotEmpty &&
                _role == 'alumni') ...[
              TextFormField(
                controller: _alumniId,
                enabled: false,
                decoration: const InputDecoration(
                  labelText: 'Alumni ID',
                  helperText:
                      'Alumni ID is linked to the account and cannot be changed here.',
                ),
              ),
              const SizedBox(height: 12),
            ],
            TextFormField(
                controller: _course,
                decoration: const InputDecoration(labelText: 'Course')),
            const SizedBox(height: 12),
            TextFormField(
                controller: _gradYear,
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(labelText: 'Graduation year')),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _academicYearDropdownValue,
              decoration: const InputDecoration(
                labelText: 'Academic Year Graduated',
                hintText: 'Select Academic Year',
              ),
              hint: const Text('Select Academic Year'),
              items: [
                for (final year in AcademicYearUtils.options())
                  DropdownMenuItem(value: year, child: Text(year)),
                const DropdownMenuItem(
                  value: '',
                  child: Text('Not specified'),
                ),
              ],
              onChanged: (v) =>
                  setState(() => _academicYear = v?.replaceAll('–', '-')),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _status,
              decoration: const InputDecoration(labelText: 'Employment status'),
              items: [
                for (final s in EmploymentStatus.values)
                  DropdownMenuItem(value: s.name, child: Text(s.label)),
              ],
              onChanged: (v) => setState(() => _status = v ?? _status),
            ),
            if (widget.adminRoleEditing) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _role,
                decoration: const InputDecoration(labelText: 'Role'),
                items: [
                  for (final role in UserRole.values)
                    DropdownMenuItem(
                        value: role.name, child: Text(role.label)),
                ],
                onChanged: (v) => setState(() => _role = v ?? _role),
              ),
            ],
            const SizedBox(height: 12),
            SwitchListTile(
              title: const Text('Verified graduate'),
              value: _verified,
              onChanged: (v) => setState(() => _verified = v),
            ),
            if (widget.adminRoleEditing)
              SwitchListTile(
                title: const Text('Account approved'),
                value: _approved,
                onChanged: (v) => setState(() => _approved = v),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel')),
        FilledButton(onPressed: _save, child: const Text('Save Changes')),
      ],
    );
  }
}