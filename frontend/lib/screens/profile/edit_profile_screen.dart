import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../constants/app_constants.dart';
import '../../models/user_model.dart';
import '../../providers/auth_providers.dart';
import '../../providers/profile_edit_provider.dart';
import '../../utils/app_snack_bar.dart';
import '../../utils/avatar_utils.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _studentNumberController = TextEditingController();
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

  void _hydrate(UserModel user) {
    if (_initialized) return;
    _nameController.text = user.fullName;
    _studentNumberController.text = user.studentNumber ?? '';
    _phoneController.text = user.phoneNumber ?? '';
    _currentAddressController.text = user.currentAddress ?? '';
    _permanentAddressController.text = user.permanentAddress ?? '';
    _bioController.text = user.biography ?? '';
    _linkedInController.text = user.socialLinks.linkedIn ?? '';
    _githubController.text = user.socialLinks.github ?? '';
    _initialized = true;
    ref.read(profileEditControllerProvider.notifier).startEditing();
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

    final controller = ref.read(profileEditControllerProvider.notifier);
    final success = await controller.save(
      current: current,
      updated: current.copyWith(
        fullName: _nameController.text.trim(),
        studentNumber: _studentNumberController.text.trim(),
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
      showAppSnackBar(context, 'Failed to save profile. Please try again.',
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 5));
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

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: profileAsync.when(
        data: (user) {
          if (user == null) return const Center(child: Text('No profile'));
          _hydrate(user);

          final isGuest = user.role == UserRole.guest;

          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                Center(
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 54,
                        backgroundColor:
                            AppColors.primaryBlue.withValues(alpha: 0.1),
                        backgroundImage: _selectedPhotoBytes != null
                            ? MemoryImage(_selectedPhotoBytes!)
                                as ImageProvider<Object>
                            : (user.photoUrl != null
                                ? avatarProvider(user.photoUrl)
                                : null),
                        child: (_selectedPhotoBytes == null &&
                                user.photoUrl == null)
                            ? Text(
                                user.fullName.isNotEmpty
                                    ? user.fullName[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
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
                                : const Icon(Icons.camera_alt_outlined,
                                    size: 18, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Center(
                  child: Text(
                    'Add or change your profile photo',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                _field('Full Name', _nameController, required: true),
                if (!isGuest) ...[
                  _field('Student Number', _studentNumberController),
                ],
                _field('Phone Number', _phoneController,
                    keyboardType: TextInputType.phone),
                if (!isGuest) ...[
                  _field('Current Address', _currentAddressController),
                  _field('Permanent Address', _permanentAddressController),
                ],
                _field('Biography', _bioController, maxLines: 4),
                if (!isGuest) ...[
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
                ],
                const SizedBox(height: AppSpacing.lg),
                ElevatedButton(
                  onPressed: saving ? null : () => _save(user),
                  child: saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Save Changes'),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
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
    _phoneController.dispose();
    _currentAddressController.dispose();
    _permanentAddressController.dispose();
    _bioController.dispose();
    _linkedInController.dispose();
    _githubController.dispose();
    super.dispose();
  }
}