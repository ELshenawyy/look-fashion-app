import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:my_fashion_app/core/error/failures.dart';
import 'package:my_fashion_app/features/profile/domain/usecases/change_password.dart';
import 'package:my_fashion_app/features/profile/domain/usecases/update_display_name.dart';
import 'package:my_fashion_app/features/profile/domain/usecases/upload_profile_image.dart';

/// Provider يدير حالة عمليات الـ profile (رفع صورة، تحديث اسم، تغيير كلمة مرور).
/// يستدعي use cases فقط — لا Firebase مباشرة.
class ProfileProvider extends ChangeNotifier {
  final UploadProfileImage _uploadProfileImage;
  final UpdateDisplayName _updateDisplayName;
  final ChangePassword _changePassword;

  ProfileProvider({
    required UploadProfileImage uploadProfileImage,
    required UpdateDisplayName updateDisplayName,
    required ChangePassword changePassword,
  })  : _uploadProfileImage = uploadProfileImage,
        _updateDisplayName = updateDisplayName,
        _changePassword = changePassword;

  bool _isUploadingImage = false;
  bool _isSavingName = false;
  bool _isChangingPassword = false;
  Failure? _failure;

  bool get isUploadingImage => _isUploadingImage;
  bool get isSavingName => _isSavingName;
  bool get isChangingPassword => _isChangingPassword;
  Failure? get failure => _failure;
  String? get errorMessage => _failure?.message; // backward-compat

  void clearError() {
    _failure = null;
    notifyListeners();
  }

  // ── Upload profile image ──────────────────────────────────────────────
  Future<bool> uploadProfileImage(String userId, File imageFile) async {
    _isUploadingImage = true;
    _failure = null;
    notifyListeners();

    final res = await _uploadProfileImage(UploadProfileImageParams(
      userId: userId,
      imageFile: imageFile,
    ));

    _isUploadingImage = false;
    return res.fold((f) {
      _failure = f;
      notifyListeners();
      return false;
    }, (_) {
      notifyListeners();
      return true;
    });
  }

  // ── Update display name ───────────────────────────────────────────────
  Future<bool> updateName(String userId, String newName) async {
    _isSavingName = true;
    _failure = null;
    notifyListeners();

    final res = await _updateDisplayName(UpdateDisplayNameParams(
      userId: userId,
      newName: newName,
    ));

    _isSavingName = false;
    return res.fold((f) {
      _failure = f;
      notifyListeners();
      return false;
    }, (_) {
      notifyListeners();
      return true;
    });
  }

  // ── Change password ───────────────────────────────────────────────────
  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    _isChangingPassword = true;
    _failure = null;
    notifyListeners();

    final res = await _changePassword(ChangePasswordParams(
      currentPassword: currentPassword,
      newPassword: newPassword,
    ));

    _isChangingPassword = false;
    return res.fold((f) {
      _failure = f;
      notifyListeners();
      return false;
    }, (_) {
      notifyListeners();
      return true;
    });
  }
}
