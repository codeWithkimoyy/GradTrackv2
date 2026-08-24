import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
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
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.primaryBlue,
              surface: AppColors.cardDark,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => _dateHired = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final user = ref.read(currentUserProfileProvider).value;
    if (user == null) return;

    setState(() => _saving = true);

    final record = EmploymentRecord(
      id: '',
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
        showAppSnackBar(context, 'Employment record added successfully',
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: isDark ? Colors.white : AppColors.primaryNavy),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Add Employment Record',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : AppColors.primaryNavy,
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? AppColors.cardDark : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                ),
              ),
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeThumbColor: AppColors.primaryBlue,
                title: Text(
                  'This is my current employment',
                  style: GoogleFonts.poppins(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : AppColors.primaryNavy,
                  ),
                ),
                value: _isCurrent,
                onChanged: (v) => setState(() => _isCurrent = v),
              ),
            ),
            const SizedBox(height: 20),
            _text('Company / Employer Name', _companyController, required: true),
            _text('Job Title / Position', _positionController, required: true),
            _text('Industry Sector', _industryController, required: true),
            DropdownButtonFormField<String>(
              initialValue: _employmentType,
              dropdownColor: isDark ? AppColors.cardDark : Colors.white,
              style: GoogleFonts.poppins(
                color: isDark ? Colors.white : AppColors.primaryNavy,
                fontSize: 13.5,
              ),
              decoration: const InputDecoration(labelText: 'Employment Type'),
              isExpanded: true,
              items: _employmentTypes
                  .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                  .toList(),
              onChanged: (v) => setState(() => _employmentType = v ?? _employmentType),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _salaryRange,
              dropdownColor: isDark ? AppColors.cardDark : Colors.white,
              style: GoogleFonts.poppins(
                color: isDark ? Colors.white : AppColors.primaryNavy,
                fontSize: 13.5,
              ),
              decoration: const InputDecoration(labelText: 'Salary Range (Optional)'),
              isExpanded: true,
              items: _salaryRanges
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (v) => setState(() => _salaryRange = v),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.cardDark : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                ),
              ),
              child: InkWell(
                onTap: _pickDate,
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Date Hired',
                            style: GoogleFonts.poppins(
                              fontSize: 11.5,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            DateFormat.yMMMd().format(_dateHired),
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : AppColors.primaryNavy,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.calendar_today_rounded, color: AppColors.primaryBlue, size: 20),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _text('Country', _countryController, required: true)),
                const SizedBox(width: 12),
                Expanded(child: _text('Province', _provinceController)),
              ],
            ),
            _text('City / Municipality', _cityController, required: true),
            Text(
              'Work Setup',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : AppColors.primaryNavy,
              ),
            ),
            const SizedBox(height: 8),
            SegmentedButton<WorkSetup>(
              style: SegmentedButton.styleFrom(
                selectedBackgroundColor: AppColors.primaryBlue,
                selectedForegroundColor: Colors.white,
                foregroundColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                backgroundColor: isDark ? AppColors.cardDark : Colors.white,
              ),
              segments: WorkSetup.values
                  .map((w) => ButtonSegment(value: w, label: Text(w.label)))
                  .toList(),
              selected: {_workSetup},
              onSelectionChanged: (s) => setState(() => _workSetup = s.first),
            ),
            const SizedBox(height: 16),
            _text('Job Description (Optional)', _descriptionController, maxLines: 3),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saving ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        style: GoogleFonts.poppins(
          color: isDark ? Colors.white : AppColors.primaryNavy,
          fontSize: 13.5,
        ),
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
