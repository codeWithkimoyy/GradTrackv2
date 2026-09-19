import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../constants/app_constants.dart';
import '../../models/employment_model.dart';
import '../../models/notification_model.dart';
import '../../models/user_model.dart' show parseApiDate;
import '../../providers/auth_providers.dart';
import '../../providers/employment_providers.dart';
import '../../providers/notification_providers.dart';
import '../../providers/role_providers.dart';
import '../../repositories/content_repository.dart';
import '../../routes/app_router.dart';
import '../../services/auth_service.dart';
import '../../utils/app_snack_bar.dart';
import '../../utils/navigation_utils.dart';

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
];

const _visibilityOptions = ['public', 'private'];

/// Full-page editor for employment records in the unified `jobs` store.
/// Alumni log their employment from the Employment tab; staff can use the
/// same page to post opportunities. Kept as a separate page (not a pop-up)
/// so the add/edit form has room for every field.
class EmploymentFormScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? existing;

  const EmploymentFormScreen({super.key, this.existing});

  bool get isEdit => existing != null;

  @override
  ConsumerState<EmploymentFormScreen> createState() =>
      _EmploymentFormScreenState();
}

class _EmploymentFormScreenState extends ConsumerState<EmploymentFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _companyController;
  late final TextEditingController _positionController;
  late final TextEditingController _industryController;
  late final TextEditingController _locationController;
  late final TextEditingController _descriptionController;

  late String _employmentType;
  String? _salaryRange;
  WorkSetup _workSetup = WorkSetup.onSite;
  String _visibility = 'public';
  DateTime? _startDate;
  DateTime? _endDate;
  late bool _isCurrent;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final data = widget.existing ?? {};
    _companyController =
        TextEditingController(text: data['company']?.toString() ?? '');
    _positionController = TextEditingController(
        text:
            data['jobTitle']?.toString() ?? data['title']?.toString() ?? '');
    _industryController =
        TextEditingController(text: data['industry']?.toString() ?? '');
    _locationController =
        TextEditingController(text: data['location']?.toString() ?? '');
    _descriptionController =
        TextEditingController(text: data['description']?.toString() ?? '');
    final rawType = data['employmentType']?.toString();
    _employmentType = _employmentTypes.contains(rawType)
        ? rawType!
        : _employmentTypes.first;
    final rawSalary = data['salary']?.toString();
    _salaryRange = _salaryRanges.contains(rawSalary) ? rawSalary : null;
    final rawWorkSetup = data['workSetup']?.toString();
    _workSetup = WorkSetupX.fromString(rawWorkSetup ?? '');
    final rawVisibility = data['visibility']?.toString();
    _visibility =
        _visibilityOptions.contains(rawVisibility) ? rawVisibility! : 'public';
    _startDate = parseApiDate(data['startDate']);
    _endDate = parseApiDate(data['endDate']);
    _isCurrent = data['isCurrent'] == true ||
        data['isCurrent'] == 1 ||
        (data['isCurrent'] == null && data['endDate'] == null);
  }

  @override
  void dispose() {
    _companyController.dispose();
    _positionController.dispose();
    _industryController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(1970),
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
    if (picked != null) setState(() => _startDate = picked);
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? DateTime.now(),
      firstDate: _startDate ?? DateTime(1970),
      lastDate: DateTime.now().add(const Duration(days: 365)),
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
    if (picked != null) setState(() => _endDate = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_startDate == null) {
      showAppSnackBar(context, 'Start Date is required.',
          backgroundColor: AppColors.error);
      return;
    }

    setState(() => _saving = true);

    String dateOnly(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    final data = <String, dynamic>{
      'jobTitle': _positionController.text.trim(),
      'company': _companyController.text.trim(),
      'industry': _industryController.text.trim(),
      'employmentType': _employmentType,
      if (_salaryRange != null) 'salary': _salaryRange,
      'workSetup': _workSetup.name,
      'startDate': dateOnly(_startDate!),
      'isCurrent': _isCurrent,
      if (!_isCurrent && _endDate != null) 'endDate': dateOnly(_endDate!),
      if (_isCurrent) 'endDate': null,
      'location': _locationController.text.trim(),
      'description': _descriptionController.text.trim(),
      'visibility': _visibility,
    };

    try {
      final isAdmin = ref.read(isAdminProvider);
      if (isAdmin) {
        final repo = ref.read(contentRepositoryProvider);
        if (widget.isEdit) {
          await repo.updateItem(
              'jobs', widget.existing!['id']?.toString() ?? '', data);
        } else {
          await repo.createItem('jobs', data);
        }
      } else {
        final empRepo = ref.read(employmentRepositoryProvider);
        if (widget.isEdit) {
          await empRepo.updateRecord(
            widget.existing!['id']?.toString() ?? '',
            <String, dynamic>{
              'company': _companyController.text.trim(),
              'position': _positionController.text.trim(),
              'industry': _industryController.text.trim(),
              'employmentType': _employmentType,
              if (_salaryRange != null) 'salaryRange': _salaryRange,
              'dateHired': dateOnly(_startDate!),
              'workSetup': _workSetup.name,
              'isCurrent': _isCurrent,
              if (!_isCurrent && _endDate != null)
                'endDate': dateOnly(_endDate!),
              if (_isCurrent) 'endDate': null,
              'city': _locationController.text.trim(),
              'jobDescription': _descriptionController.text.trim(),
            },
          );
        } else {
          await empRepo.addRecord(EmploymentRecord(
            id: '',
            userId:
                ref.read(currentUserProfileProvider).value?.uid ?? '',
            company: _companyController.text.trim(),
            position: _positionController.text.trim(),
            industry: _industryController.text.trim(),
            employmentType: _employmentType,
            salaryRange: _salaryRange,
            dateHired: _startDate!,
            endDate: _isCurrent ? null : _endDate,
            country: '',
            province: null,
            city: _locationController.text.trim(),
            workSetup: _workSetup,
            jobDescription: _descriptionController.text.trim(),
            isCurrent: _isCurrent,
            createdAt: DateTime.now(),
          ));
        }
      }
      if (!widget.isEdit) {
        await _notifyAlumni(data);
      }
      if (mounted) {
        Navigator.of(context).pop(true);
        showAppSnackBar(
          context,
          widget.isEdit
              ? 'Employment updated successfully'
              : 'Employment added successfully',
          backgroundColor: AppColors.success,
        );
      }
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, AuthService.friendlyError(e),
            backgroundColor: AppColors.error);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Sends a bell alert to every alumnus when a new employment record is
  /// posted, matching the behaviour of the generic content editor.
  Future<void> _notifyAlumni(Map<String, dynamic> data) async {
    try {
      final service = ref.read(notificationServiceProvider);
      final title =
          data['jobTitle']?.toString() ?? 'employment';
      final detail = [data['company'], data['location']]
          .whereType<String>()
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .join(' · ');
      await service.notifyAllAlumni(
        type: NotificationType.employment,
        title: 'New job: $title',
        description: detail.isEmpty
            ? 'A new employment record has been added.'
            : detail,
        priority: NotificationPriority.medium,
        link: AppRoutes.collectionData('jobs'),
      );
    } catch (_) {
      // Best-effort: alerting must never block saving.
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? Colors.white : AppColors.primaryNavy;
    final muted =
        isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary;

    return Scaffold(
      backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded,
              color: isDark ? Colors.white : AppColors.primaryNavy),
          onPressed: () => popOrGoHome(context),
        ),
        title: Text(
          widget.isEdit ? 'Edit Employment' : 'Add Employment',
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
                subtitle: Text(
                  _isCurrent
                      ? 'Ongoing / Present (No end date required)'
                      : 'Past job or completed contract',
                  style: GoogleFonts.poppins(fontSize: 11.5, color: muted),
                ),
                value: _isCurrent,
                onChanged: (v) => setState(() {
                  _isCurrent = v;
                  if (v) _endDate = null;
                }),
              ),
            ),
            const SizedBox(height: 20),
            _text('Company / Employer Name', _companyController,
                required: true),
            _text('Job Title / Position', _positionController, required: true),
            _text('Industry Sector', _industryController, required: true),
            DropdownButtonFormField<String>(
              initialValue: _employmentType,
              dropdownColor: isDark ? AppColors.cardDark : Colors.white,
              style: GoogleFonts.poppins(color: fg, fontSize: 13.5),
              decoration: const InputDecoration(labelText: 'Employment Type'),
              isExpanded: true,
              items: _employmentTypes
                  .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                  .toList(),
              onChanged: (v) =>
                  setState(() => _employmentType = v ?? _employmentType),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _salaryRange,
              dropdownColor: isDark ? AppColors.cardDark : Colors.white,
              style: GoogleFonts.poppins(color: fg, fontSize: 13.5),
              decoration: const InputDecoration(
                labelText: 'Salary Range (Optional)',
              ),
              isExpanded: true,
              items: _salaryRanges
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (v) => setState(() => _salaryRange = v),
            ),
            const SizedBox(height: 16),
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
                foregroundColor: muted,
                backgroundColor:
                    isDark ? AppColors.cardDark : Colors.white,
              ),
              segments: WorkSetup.values
                  .map((w) => ButtonSegment(value: w, label: Text(w.label)))
                  .toList(),
              selected: {_workSetup},
              onSelectionChanged: (s) =>
                  setState(() => _workSetup = s.first),
            ),
            const SizedBox(height: 16),
            _dateTile(
              'Start Date / Date Hired',
              _startDate,
              onTap: _pickStartDate,
              required: true,
              isDark: isDark,
              fg: fg,
              muted: muted,
            ),
            if (!_isCurrent) ...[
              const SizedBox(height: 12),
              _dateTile(
                'End Date (Optional)',
                _endDate,
                onTap: _pickEndDate,
                required: false,
                isDark: isDark,
                fg: fg,
                muted: muted,
                onClear: _endDate == null
                    ? null
                    : () => setState(() => _endDate = null),
              ),
            ],
            const SizedBox(height: 16),
            _text('City / Municipality', _locationController, required: true),
            Text(
              'Visibility',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : AppColors.primaryNavy,
              ),
            ),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              style: SegmentedButton.styleFrom(
                selectedBackgroundColor: AppColors.primaryBlue,
                selectedForegroundColor: Colors.white,
                foregroundColor: muted,
                backgroundColor:
                    isDark ? AppColors.cardDark : Colors.white,
              ),
              segments: _visibilityOptions
                  .map((v) => ButtonSegment(
                        value: v,
                        label: Text(v == 'public'
                            ? 'Public'
                            : 'Private'),
                      ))
                  .toList(),
              selected: {_visibility},
              onSelectionChanged: (s) =>
                  setState(() => _visibility = s.first),
            ),
            const SizedBox(height: 16),
            _text('Description / Responsibilities (Optional)',
                _descriptionController,
                maxLines: 3),
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
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Save Employment'),
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

  Widget _dateTile(
    String label,
    DateTime? value, {
    required VoidCallback onTap,
    required bool required,
    required bool isDark,
    required Color fg,
    required Color muted,
    VoidCallback? onClear,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: onTap,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    required ? '$label *' : label,
                    style: GoogleFonts.poppins(fontSize: 11.5, color: muted),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value != null
                        ? DateFormat.yMMMd().format(value)
                        : 'Not set',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: value != null
                          ? fg
                          : (isDark
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF64748B)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (onClear != null)
            IconButton(
              icon: const Icon(Icons.clear_rounded, size: 18),
              onPressed: onClear,
              tooltip: 'Clear',
            ),
          IconButton(
            icon: const Icon(Icons.calendar_today_rounded,
                color: AppColors.primaryBlue, size: 20),
            onPressed: onTap,
            tooltip: 'Select Date',
          ),
        ],
      ),
    );
  }
}