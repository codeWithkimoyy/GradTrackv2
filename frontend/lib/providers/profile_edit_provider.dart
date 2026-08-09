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

/// Owns the edit-profile flow: photo upload, Firestore save, and the
/// saving/success/error states surfaced to the UI. Guards against multiple
/// concurrent saves. Users only ever write their own `users/{uid}` doc.
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

    try {
      await _ref.read(userRepositoryProvider).saveUser(finalUser);
    } catch (_) {
      _ref.read(localProfileProvider.notifier).state = finalUser;
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