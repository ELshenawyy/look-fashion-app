import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:my_fashion_app/core/error/exceptions.dart';

abstract class ProfileRemoteDataSource {
  Future<String> uploadProfileImage({
    required String userId,
    required File imageFile,
  });

  Future<void> updateDisplayName({
    required String userId,
    required String newName,
  });

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  });
}

class ProfileRemoteDataSourceImpl implements ProfileRemoteDataSource {
  final FirebaseAuth _auth;
  final FirebaseFirestore _db;
  final FirebaseStorage _storage;

  ProfileRemoteDataSourceImpl(this._auth, this._db, this._storage);

  @override
  Future<String> uploadProfileImage({
    required String userId,
    required File imageFile,
  }) async {
    try {
      // ⚠️ نستخدم timestamp في اسم الملف لضمان أن الـ URL الجديد يختلف
      // عن القديم 100% — يضمن أن CachedNetworkImage يجلب الصورة الجديدة
      // فوراً بدون cache stale.
      final ts = DateTime.now().millisecondsSinceEpoch;
      final ref = _storage.ref('profiles/$userId/avatar_$ts.jpg');
      await ref.putFile(imageFile);
      final url = await ref.getDownloadURL();

      // تحديث Firestore أولاً → يُطلق snapshot stream في AuthProvider
      // فوراً → UserAvatarWidget يلتقطه عبر Consumer ويُعاد رسمه.
      await _db.collection('users').doc(userId).update({'photoUrl': url});

      // ثم Firebase Auth (للحفاظ على التزامن).
      await _auth.currentUser?.updatePhotoURL(url);

      return url;
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? e.code);
    }
  }

  @override
  Future<void> updateDisplayName({
    required String userId,
    required String newName,
  }) async {
    try {
      final trimmed = newName.trim();
      await _auth.currentUser?.updateDisplayName(trimmed);
      await _db.collection('users').doc(userId).update({'name': trimmed});
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? e.code);
    }
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      throw const ServerException('لا يوجد مستخدم مسجَّل دخول.');
    }
    final cred = EmailAuthProvider.credential(
      email: user.email!,
      password: currentPassword,
    );
    await user.reauthenticateWithCredential(cred);
    await user.updatePassword(newPassword);
  }
}
