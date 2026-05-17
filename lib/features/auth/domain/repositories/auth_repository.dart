import 'package:dartz/dartz.dart';
import 'package:my_fashion_app/core/error/failures.dart';
import 'package:my_fashion_app/features/auth/domain/entities/user_entity.dart';

/// نتيجة بدء التحقق من رقم الهاتف.
class PhoneVerificationResult {
  final String verificationId;
  const PhoneVerificationResult(this.verificationId);
}

abstract class AuthRepository {
  /// Stream للمستخدم الحالي مع بياناته الكاملة (الدور + revokedAt من Firestore).
  /// يُرجع null عند تسجيل الخروج.
  Stream<UserEntity?> watchCurrentUser();

  /// المستخدم الحالي (one-shot) — `uid` فقط أو null.
  String? get currentUid;

  /// تسجيل الدخول بالإيميل وكلمة المرور
  Future<Either<Failure, UserEntity>> signInWithEmail({
    required String email,
    required String password,
  });

  /// إنشاء حساب جديد بإيميل وكلمة مرور — يحفظ مستند المستخدم بدور 'user'.
  Future<Either<Failure, UserEntity>> signUpWithEmail({
    required String email,
    required String password,
    required String name,
  });

  /// إرسال OTP لرقم الهاتف
  Future<Either<Failure, PhoneVerificationResult>> sendOtp(String phoneNumber);

  /// تأكيد رمز OTP — flow الدخول العادي.
  /// [displayName] اختياري: إذا مُرَّر يفعّل flow التسجيل بالهاتف
  /// (ينشئ مستند users إن لم يكن موجوداً بدور 'user').
  Future<Either<Failure, UserEntity>> verifyOtp({
    required String verificationId,
    required String smsCode,
    String? displayName,
  });

  /// إرسال رابط استعادة كلمة المرور
  Future<Either<Failure, void>> sendPasswordReset(String email);

  /// تسجيل الخروج
  Future<Either<Failure, void>> signOut();
}
