import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../constants/app_constants.dart';
import '../../models/user_model.dart';
import '../../providers/auth_providers.dart';
import '../../providers/profile_edit_provider.dart';
import '../../utils/app_snack_bar.dart';
import '../../utils/avatar_utils.dart';
import '../../widgets/empty_state_widget.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _studentNumberController = TextEditingController();
  final _courseController = TextEditingController();
  final _phoneController = TextEditingController();
  final _currentAddressController = TextEditingController();
  final _permanentAddressController = TextEditingController();
  final _bioController = TextEditingController();
  final _linkedInController = TextEditingController();
  final _githubController = TextEditingController();

  final ImagePicker _picker = ImagePicker();

  bool _initialized = false;
  Uint8List? _selectedPhotoBytes;
  String? _selectedPhotoName;
  String? _academicYear;

  void _hydrate(UserModel user) {
    if (_initialized) return;
    _nameController.text = user.fullName;
    _studentNumberController.text = user.studentNumber ?? '';
    _courseController.text =
        user.course?.trim().isNotEmpty == true ? user.course! : AppStrings.defaultCourse;
    _phoneController.text = user.phoneNumber ?? '';
    _currentAddressController.text = user.currentAddress ?? '';
    _permanentAddressController.text = user.permanentAddress ?? '';
    _bioController.text = user.biography ?? '';
    _academicYear = user.academicYearGraduated;
    _linkedInController.text = user.socialLinks.linkedIn ?? '';
    _githubController.text = user.socialLinks.github ?? '';
    _initialized = true;
    ref.read(profileEditControllerProvider.notifier).startEditing();
  }

  List<String> _academicYearOptions() {
    final currentYear = DateTime.now().year;
    final years = <String>[];
    for (var start = currentYear + 4; start >= currentYear - 10; start--) {
      years.add('$start-${start + 1}');
    }
    return years;
  }

  Future<void> _pickPhoto() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 85,
    );

    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    setState(() {
      _selectedPhotoBytes = bytes;
      _selectedPhotoName =
          picked.name.isNotEmpty ? picked.name : 'profile_photo.jpg';
    });

    if (mounted) {
      showAppSnackBar(context, 'Photo selected. Save to update your profile.');
    }
  }

  Future<void> _save(UserModel current) async {
    if (!_formKey.currentState!.validate()) return;
    if (_academicYear == null) {
      showAppSnackBar(
        context,
        'Please select your Academic Year Graduated.',
        backgroundColor: AppColors.warning,
      );
      return;
    }

    final controller = ref.read(profileEditControllerProvider.notifier);
    final success = await controller.save(
      current: current,
      updated: current.copyWith(
        fullName: _nameController.text.trim(),
        studentNumber: _studentNumberController.text.trim(),
        course: _courseController.text.trim().isEmpty
            ? AppStrings.defaultCourse
            : _courseController.text.trim(),
        academicYearGraduated: _academicYear,
        phoneNumber: _phoneController.text.trim(),
        currentAddress: _currentAddressController.text.trim(),
        permanentAddress: _permanentAddressController.text.trim(),
        biography: _bioController.text.trim(),
        socialLinks: SocialLinks(
          linkedIn: _linkedInController.text.trim(),
          github: _githubController.text.trim(),
          portfolio: current.socialLinks.portfolio,
          facebook: current.socialLinks.facebook,
        ),
      ),
      photoBytes: _selectedPhotoBytes,
      photoName: _selectedPhotoName,
    );

    if (!mounted) return;
    if (!success) {
      showAppSnackBar(
        context,
        controller.message.isEmpty
            ? 'Failed to save profile. Please try again.'
            : controller.message,
        backgroundColor: AppColors.error,
        duration: const Duration(seconds: 5),
      );
      return;
    }
    showAppSnackBar(
      context,
      controller.message.isEmpty ? 'Profile updated successfully.' : controller.message,
      backgroundColor: AppColors.success,
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentUserProfileProvider);
    final editState = ref.watch(profileEditControllerProvider);
    final saving = editState.isSaving;
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
          'Edit Profile',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : AppColors.primaryNavy,
          ),
        ),
      ),
      body: profileAsync.when(
        data: (user) {
          if (user == null) {
            return const EmptyStateWidget(
              icon: Icons.person_off_rounded,
              title: 'No Profile Found',
              message: 'Your profile could not be loaded.',
            );
          }
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _hydrate(user);
          });

          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Center(
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 54,
                        backgroundColor: AppColors.primaryBlue.withValues(alpha: 0.15),
                        backgroundImage: _selectedPhotoBytes != null
                            ? MemoryImage(_selectedPhotoBytes!) as ImageProvider<Object>
                            : (user.photoUrl != null
                                ? avatarProvider(user.photoUrl)
                                : null),
                        child: (_selectedPhotoBytes == null && user.photoUrl == null)
                            ? Text(
                                user.fullName.isNotEmpty
                                    ? user.fullName[0].toUpperCase()
                                    : '?',
                                style: GoogleFonts.poppins(
                                  fontSize: 28,
                                  color: AppColors.primaryBlue,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: InkWell(
                          onTap: saving ? null : _pickPhoto,
                          borderRadius: BorderRadius.circular(999),
                          child: CircleAvatar(
                            radius: 18,
                            backgroundColor: AppColors.primaryBlue,
                            child: saving
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.camera_alt_rounded,
                                    size: 18, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    'Add or change your official profile photo',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _field('Full Name', _nameController, required: true),
                _field('Student Number', _studentNumberController),
                _field('Course', _courseController),
                _field('Phone Number', _phoneController,
                    keyboardType: TextInputType.phone),
                _field('Current Address', _currentAddressController),
                _field('Permanent Address', _permanentAddressController),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Education',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: AppSpacing.sm),
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: FormField<String>(
                    key: ValueKey<String?>('academic-year-$_academicYear'),
                    initialValue: _academicYear,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Please select your Academic Year Graduated.'
                        : null,
                    builder: (field) => InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Academic Year Graduated',
                        errorText: field.errorText,
                      ),
                      isEmpty: field.value == null,
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          isDense: true,
                          value: field.value,
                          hint: const Text('Select Academic Year'),
                          items: [
                            for (final year in _academicYearOptions())
                              DropdownMenuItem(
                                value: year,
                                child: Text(displayAcademicYear(year)),
                              ),
                          ],
                          onChanged: (v) {
                            field.didChange(v);
                            setState(() => _academicYear = v);
                          },
                        ),
                      ),
                    ),
                  ),
                ),
                _field('Biography', _bioController, maxLines: 4),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Social Links',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: AppSpacing.sm),
                _field('LinkedIn URL', _linkedInController),
                _field('GitHub URL', _githubController),
                const SizedBox(height: AppSpacing.lg),
                ElevatedButton(
                  onPressed: saving ? null : () => _save(user),
                  child: saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Save Profile Changes'),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primaryBlue),
        ),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    bool required = false,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
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
    _nameController.dispose();
    _studentNumberController.dispose();
    _courseController.dispose();
    _phoneController.dispose();
    _currentAddressController.dispose();
    _permanentAddressController.dispose();
    _bioController.dispose();
    _linkedInController.dispose();
    _githubController.dispose();
    super.dispose();
  }
}