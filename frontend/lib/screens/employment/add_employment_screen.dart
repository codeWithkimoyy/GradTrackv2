import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../constants/app_constants.dart';
import '../../models/employment_model.dart';
import '../../providers/auth_providers.dart';
import '../../providers/employment_providers.dart';
import '../../utils/app_snack_bar.dart';
import '../../utils/firebase_error_message.dart';

const _employmentTypes = [
  'Full-time',
  'Part-time',
  'Contract',
  'Internship',
  'Project-based',
];

const _salaryRanges = [
  'Below ₱15,000',
  '₱15,000 - ₱25,000',
  '₱25,001 - ₱40,000',
  '₱40,001 - ₱60,000',
  '₱60,001 - ₱100,000',
  'Above ₱100,000',
  'Prefer not to say',
];

class AddEmploymentScreen extends ConsumerStatefulWidget {
  const AddEmploymentScreen({super.key});

  @override
  ConsumerState<AddEmploymentScreen> createState() =>
      _AddEmploymentScreenState();
}

class _AddEmploymentScreenState extends ConsumerState<AddEmploymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _companyController = TextEditingController();
  final _positionController = TextEditingController();
  final _industryController = TextEditingController();
  final _countryController = TextEditingController(text: 'Philippines');
  final _provinceController = TextEditingController();
  final _cityController = TextEditingController();
  final _descriptionController = TextEditingController();

  String _employmentType = _employmentTypes.first;
  String? _salaryRange;
  WorkSetup _workSetup = WorkSetup.onSite;
  DateTime _dateHired = DateTime.now();
  bool _isCurrent = true;
  bool _saving = false;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateHired,
      firstDate: DateTime(1990),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _dateHired = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final user = ref.read(currentUserProfileProvider).value;
    if (user == null) return;

    setState(() => _saving = true);

    final record = EmploymentRecord(
      id: '', // Firestore auto-generates the doc ID
      userId: user.uid,
      company: _companyController.text.trim(),
      position: _positionController.text.trim(),
      industry: _industryController.text.trim(),
      employmentType: _employmentType,
      salaryRange: _salaryRange,
      dateHired: _dateHired,
      country: _countryController.text.trim(),
      province: _provinceController.text.trim().isEmpty
          ? null
          : _provinceController.text.trim(),
      city: _cityController.text.trim(),
      workSetup: _workSetup,
      jobDescription: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      isCurrent: _isCurrent,
      createdAt: DateTime.now(),
    );

    try {
      await ref.read(employmentRepositoryProvider).addRecord(record);
      if (mounted) {
        Navigator.of(context).pop();
        showAppSnackBar(context, 'Employment record added',
            backgroundColor: AppColors.success);
      }
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, friendlyFirebaseError(e),
            backgroundColor: AppColors.error);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Employment')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('This is my current job'),
              value: _isCurrent,
              onChanged: (v) => setState(() => _isCurrent = v),
            ),
            const SizedBox(height: AppSpacing.sm),
            _text('Company', _companyController, required: true),
            _text('Position', _positionController, required: true),
            _text('Industry', _industryController, required: true),
            DropdownButtonFormField<String>(
              initialValue: _employmentType,
              decoration: const InputDecoration(labelText: 'Employment Type'),
              isExpanded: true,
              items: _employmentTypes
                  .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                  .toList(),
              onChanged: (v) => setState(() => _employmentType = v ?? _employmentType),
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<String>(
              initialValue: _salaryRange,
              decoration: const InputDecoration(labelText: 'Salary Range'),
              isExpanded: true,
              items: _salaryRanges
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (v) => setState(() => _salaryRange = v),
            ),
            const SizedBox(height: AppSpacing.md),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Date Hired'),
              subtitle: Text(DateFormat.yMMMd().format(_dateHired)),
              trailing: const Icon(Icons.calendar_today_outlined),
              onTap: _pickDate,
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(child: _text('Country', _countryController, required: true)),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: _text('Province', _provinceController)),
              ],
            ),
            _text('City', _cityController, required: true),
            Text('Work Setup', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 8),
            SegmentedButton<WorkSetup>(
              segments: WorkSetup.values
                  .map((w) => ButtonSegment(value: w, label: Text(w.label)))
                  .toList(),
              selected: {_workSetup},
              onSelectionChanged: (s) => setState(() => _workSetup = s.first),
            ),
            const SizedBox(height: AppSpacing.md),
            _text('Job Description (optional)', _descriptionController, maxLines: 4),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton(
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Save Employment Record'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _text(String label, TextEditingController controller,
      {bool required = false, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(labelText: label),
        validator: required
            ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null
            : null,
      ),
    );
  }

  @override
  void dispose() {
    _companyController.dispose();
    _positionController.dispose();
    _industryController.dispose();
    _countryController.dispose();
    _provinceController.dispose();
    _cityController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}
