import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

class ProfileProvider extends ChangeNotifier {
  bool _isUploadingImage = false;
  bool _isSavingName = false;
  bool _isChangingPassword = false;
  String? _errorMessage;

  bool get isUploadingImage => _isUploadingImage;
  bool get isSavingName => _isSavingName;
  bool get isChangingPassword => _isChangingPassword;
  String? get errorMessage => _errorMessage;

  void _clearError() {
    _errorMessage = null;
  }

  // ── Upload profile image → Storage → Firestore ────────────────────────
  Future<bool> uploadProfileImage(File imageFile) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    _isUploadingImage = true;
    _clearError();
    notifyListeners();

    try {
      final ref = FirebaseStorage.instance
          .ref('profiles/${user.uid}/avatar.jpg');
      await ref.putFile(imageFile);
      final url = await ref.getDownloadURL();

      await user.updatePhotoURL(url);
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({'photoUrl': url});

      return true;
    } catch (e) {
      _errorMessage = 'فشل رفع الصورة: $e';
      return false;
    } finally {
      _isUploadingImage = false;
      notifyListeners();
    }
  }

  // ── Update display name in Auth + Firestore ───────────────────────────
  Future<bool> updateName(String newName) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    _isSavingName = true;
    _clearError();
    notifyListeners();

    try {
      await user.updateDisplayName(newName.trim());
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({'name': newName.trim()});
      return true;
    } catch (e) {
      _errorMessage = 'فشل تحديث الاسم: $e';
      return false;
    } finally {
      _isSavingName = false;
      notifyListeners();
    }
  }

  // ── Change password with reauthentication ─────────────────────────────
  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) return false;

    _isChangingPassword = true;
    _clearError();
    notifyListeners();

    try {
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPassword);
      return true;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'wrong-password':
          _errorMessage = 'كلمة المرور الحالية غير صحيحة.';
          break;
        case 'weak-password':
          _errorMessage = 'كلمة المرور الجديدة ضعيفة جداً.';
          break;
        case 'requires-recent-login':
          _errorMessage = 'يرجى تسجيل الخروج ثم الدخول مجدداً قبل تغيير كلمة المرور.';
          break;
        default:
          _errorMessage = 'فشل تغيير كلمة المرور: ${e.message}';
      }
      return false;
    } catch (e) {
      _errorMessage = 'حدث خطأ غير متوقع: $e';
      return false;
    } finally {
      _isChangingPassword = false;
      notifyListeners();
    }
  }
}
