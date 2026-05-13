import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:my_fashion_app/core/error/failures.dart';

abstract class ProfileRepository {
  /// رفع صورة شخصية للمستخدم → Storage → تحديث photoUrl في Firestore + Auth
  /// يرجع URL الصورة الجديد عند النجاح.
  Future<Either<Failure, String>> uploadProfileImage({
    required String userId,
    required File imageFile,
  });

  /// تحديث الاسم في Firebase Auth + Firestore
  Future<Either<Failure, void>> updateDisplayName({
    required String userId,
    required String newName,
  });

  /// تغيير كلمة المرور (يتطلب reauthentication)
  Future<Either<Failure, void>> changePassword({
    required String currentPassword,
    required String newPassword,
  });
}
