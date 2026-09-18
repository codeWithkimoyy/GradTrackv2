import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';
import 'auth_providers.dart';
import 'document_providers.dart';

/// Lifecycle states for the "edit my own profile" flow.
enum ProfileEditStatus { idle, editing, saving, success, error }

class ProfileEditState {
  const ProfileEditState({
    this.status = ProfileEditStatus.idle,
    this.message = '',
  });

  final ProfileEditStatus status;
  final String message;

  bool get isSaving => status == ProfileEditStatus.saving;
  bool get isEditing => status == ProfileEditStatus.editing || isSaving;

  @override
  String toString() => 'ProfileEditState($status, $message)';
}

/// Owns the edit-profile flow: photo upload, backend save, and the
/// saving/success/error states surfaced to the UI. Guards against multiple
/// concurrent saves. Users only ever write their own profile.
class ProfileEditController extends StateNotifier<ProfileEditState> {
  ProfileEditController(this._ref) : super(const ProfileEditState());

  final Ref _ref;

  void startEditing() {
    if (state.status == ProfileEditStatus.idle) {
      state = const ProfileEditState(status: ProfileEditStatus.editing);
    }
  }

  /// Saves the current user's edited profile. Returns false when another save
  /// is already running or an unexpected error occurred.
  Future<bool> save({
    required UserModel current,
    required UserModel updated,
    Uint8List? photoBytes,
    String? photoName,
  }) async {
    if (state.isSaving) return false;
    state = const ProfileEditState(status: ProfileEditStatus.saving);

    var photoUrl = updated.photoUrl;
    if (photoBytes != null) {
      try {
        final result = await _ref.read(storageServiceProvider).uploadProfilePhoto(
              userId: current.uid,
              fileName: photoName ?? 'profile_photo.jpg',
              bytes: photoBytes,
            );
        photoUrl = result.url;
      } catch (_) {
        photoUrl = current.photoUrl;
      }
    }

    final finalUser = updated.copyWith(
      photoUrl: photoUrl,
      profileCompletion: UserModel.computeCompletion(updated),
    );

    // Write only the fields the alumni is allowed to self-edit. The
    // backend rejects any alumni update that includes 'role' or 'disabled',
    // so sending them would fail the edit.
    final changes = <String, dynamic>{
      'email': finalUser.email,
      'fullName': finalUser.fullName,
      'photoUrl': finalUser.photoUrl,
      'studentNumber': finalUser.studentNumber,
      'phoneNumber': finalUser.phoneNumber,
      'currentAddress': finalUser.currentAddress,
      'permanentAddress': finalUser.permanentAddress,
      'biography': finalUser.biography,
      'socialLinks': finalUser.socialLinks.toMap(),
      'graduationYear': finalUser.graduationYear,
      'course': finalUser.course,
      'academicYearGraduated': finalUser.academicYearGraduated,
      'employmentStatus': finalUser.employmentStatus.name,
      'profileCompletion': finalUser.profileCompletion,
    };

    // Keep the legacy "Graduation Year" field in sync with the graduation
    // batch so every profile surface (Class of X, Quick Record) reflects
    // the academic year the alumni picked. "2025-2026" -> 2026.
    final batch = finalUser.academicYearGraduated?.trim();
    if (batch != null && batch.isNotEmpty) {
      final startYear = academicYearStart(batch);
      if (startYear != null) {
        changes['graduationYear'] = startYear + 1;
      }
    }

    try {
      try {
        await _ref
            .read(userRepositoryProvider)
            .updateUser(finalUser.uid, changes);
      } catch (_) {
        // Doc may not exist yet (first-time profile) — fall back to a
        // full merge write, which is allowed for self-created docs.
        await _ref.read(userRepositoryProvider).saveUser(finalUser);
      }
    } catch (e) {
      // The cloud write was rejected. Keep the change in local session
      // state (useful when offline) but report an honest failure instead of
      // pretending the profile was saved, so the user knows it did not persist.
      _ref.read(localProfileProvider.notifier).state = finalUser;
      state = const ProfileEditState(
        status: ProfileEditStatus.error,
        message:
            'Your changes were NOT saved to the cloud. Check your connection and try again.',
      );
      return false;
    }

    state = const ProfileEditState(
      status: ProfileEditStatus.success,
      message: 'Profile updated successfully.',
    );
    return true;
  }

  /// Message from the latest save attempt (success or failure detail).
  String get message => state.message;

  void reset() => state = const ProfileEditState();
}

final profileEditControllerProvider =
    StateNotifierProvider<ProfileEditController, ProfileEditState>(
  (ref) => ProfileEditController(ref),
);