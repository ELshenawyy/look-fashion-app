import 'package:dartz/dartz.dart';
import 'package:my_fashion_app/core/error/failures.dart';
import 'package:my_fashion_app/features/auth/domain/entities/user_entity.dart';

/// نية إرسال الـ OTP — تُفرض server-side في Cloud Functions:
/// [signup] يرفض رقماً مسجَّلاً، [login] يرفض رقماً غير مسجَّل.
enum OtpIntent { signup, login }

/// نتيجة بدء التحقق من رقم الهاتف.
/// [channel] القناة المستخدمة فعلياً للإرسال: 'whatsapp' أو 'sms' (null لو
/// غير معروفة).
class PhoneVerificationResult {
  final String verificationId;
  final String? channel;
  const PhoneVerificationResult(this.verificationId, {this.channel});
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

  /// إرسال OTP لرقم الهاتف. [intent] يحدد فحص التسجيل الذي يفرضه السيرفر
  /// قبل الإرسال (signup: الرقم يجب ألا يكون مسجَّلاً، login: يجب أن يكون).
  Future<Either<Failure, PhoneVerificationResult>> sendOtp(
    String phoneNumber, {
    OtpIntent intent = OtpIntent.login,
  });

  /// هل الرقم (E.164) مسجَّل في التطبيق؟ يُستخدم قبل إرسال OTP في flow الدخول
  /// بالهاتف. true = يوجد حساب، false = لا يوجد.
  Future<Either<Failure, bool>> isPhoneRegistered(String phoneNumber);

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

  /// إعادة إرسال رابط تفعيل البريد (للمستخدم الحالي).
  Future<Either<Failure, void>> sendEmailVerification();

  /// يرسل OTP للرقم الجديد قبل ربطه بالحساب.
  Future<Either<Failure, PhoneVerificationResult>> sendOtpForPhoneUpdate(
      String newPhoneNumber);

  /// يحدّث رقم هاتف المستخدم الحالي.
  Future<Either<Failure, void>> updatePhoneNumber({
    required String verificationId,
    required String smsCode,
  });

  /// يبدأ تحديث البريد الإلكتروني: يرسل رابط تأكيد للبريد الجديد.
  /// التحديث الفعلي يتم لما اليوزر يضغط الرابط من بريده الجديد.
  Future<Either<Failure, void>> updateEmail({
    required String currentPassword,
    required String newEmail,
  });

  /// يُعيد تحميل بيانات المستخدم من Firebase ويرجع نسخة محدّثة.
  /// يُستخدم بعد تفعيل البريد لتحديث `emailVerified` في الـ state.
  Future<Either<Failure, UserEntity?>> reloadCurrentUser();
}
