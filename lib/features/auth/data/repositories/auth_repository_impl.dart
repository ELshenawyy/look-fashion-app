import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dartz/dartz.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:my_fashion_app/core/error/exceptions.dart';
import 'package:my_fashion_app/core/error/failures.dart';
import 'package:my_fashion_app/core/network/network_info.dart';
import 'package:my_fashion_app/features/auth/data/datasources/firebase_auth_datasource.dart';
import 'package:my_fashion_app/features/auth/domain/entities/user_entity.dart';
import 'package:my_fashion_app/features/auth/domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  final FirebaseAuthDataSource remote;
  final NetworkInfo network;
  final FirebaseFirestore db;

  AuthRepositoryImpl({
    required this.remote,
    required this.network,
    required this.db,
  });

  @override
  String? get currentUid => remote.currentUid;

  @override
  Stream<UserEntity?> watchCurrentUser() => remote.watchCurrentUser();

  @override
  Future<Either<Failure, UserEntity>> signInWithEmail({
    required String email,
    required String password,
  }) async {
    if (!await network.isConnected) return const Left(NetworkFailure());
    try {
      final uid = await remote.signInWithEmail(
        email: email.trim(),
        password: password,
      );
      return await _fetchUser(uid);
    } on FirebaseAuthException catch (e) {
      return Left(AuthFailure(_mapAuthError(e.code)));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, UserEntity>> signUpWithEmail({
    required String email,
    required String password,
    required String name,
  }) async {
    if (!await network.isConnected) return const Left(NetworkFailure());
    try {
      final uid = await remote.signUpWithEmail(
        email: email.trim(),
        password: password,
        name: name.trim(),
      );
      return await _fetchUser(uid);
    } on FirebaseAuthException catch (e) {
      return Left(AuthFailure(_mapAuthError(e.code)));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, PhoneVerificationResult>> sendOtp(
      String phoneNumber) async {
    if (!await network.isConnected) return const Left(NetworkFailure());
    try {
      final id = await remote.sendOtp(phoneNumber);
      return Right(PhoneVerificationResult(id));
    } on FirebaseAuthException catch (e) {
      return Left(AuthFailure(_mapAuthError(e.code)));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, bool>> isPhoneRegistered(String phoneNumber) async {
    if (!await network.isConnected) return const Left(NetworkFailure());
    try {
      final exists = await remote.isPhoneRegistered(phoneNumber);
      return Right(exists);
    } on FirebaseAuthException catch (e) {
      return Left(AuthFailure(_mapAuthError(e.code)));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, UserEntity>> verifyOtp({
    required String verificationId,
    required String smsCode,
    String? displayName,
  }) async {
    if (!await network.isConnected) return const Left(NetworkFailure());
    try {
      final uid = await remote.verifyOtp(
        verificationId: verificationId,
        smsCode: smsCode,
        displayName: displayName,
      );
      return await _fetchUser(uid);
    } on FirebaseAuthException catch (e) {
      return Left(AuthFailure(_mapAuthError(e.code)));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> sendPasswordReset(String email) async {
    if (!await network.isConnected) return const Left(NetworkFailure());
    try {
      await remote.sendPasswordReset(email.trim());
      return const Right(null);
    } on FirebaseAuthException catch (e) {
      return Left(AuthFailure(_mapAuthError(e.code)));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> signOut() async {
    try {
      await remote.signOut();
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, void>> sendEmailVerification() async {
    if (!await network.isConnected) return const Left(NetworkFailure());
    try {
      await remote.sendEmailVerification();
      return const Right(null);
    } on FirebaseAuthException catch (e) {
      return Left(AuthFailure(_mapAuthError(e.code)));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, PhoneVerificationResult>> sendOtpForPhoneUpdate(
      String newPhoneNumber) async {
    if (!await network.isConnected) return const Left(NetworkFailure());
    try {
      final id = await remote.sendOtpForPhoneUpdate(newPhoneNumber);
      return Right(PhoneVerificationResult(id));
    } on FirebaseAuthException catch (e) {
      return Left(AuthFailure(_mapAuthError(e.code)));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> updatePhoneNumber({
    required String verificationId,
    required String smsCode,
  }) async {
    if (!await network.isConnected) return const Left(NetworkFailure());
    try {
      await remote.updatePhoneNumber(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      return const Right(null);
    } on FirebaseAuthException catch (e) {
      return Left(AuthFailure(_mapAuthError(e.code)));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> updateEmail({
    required String currentPassword,
    required String newEmail,
  }) async {
    if (!await network.isConnected) return const Left(NetworkFailure());
    try {
      await remote.updateEmail(
        currentPassword: currentPassword,
        newEmail: newEmail,
      );
      return const Right(null);
    } on FirebaseAuthException catch (e) {
      return Left(AuthFailure(_mapAuthError(e.code)));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, UserEntity?>> reloadCurrentUser() async {
    if (!await network.isConnected) return const Left(NetworkFailure());
    try {
      final model = await remote.reloadCurrentUser();
      return Right(model); // UserModel extends UserEntity
    } on FirebaseAuthException catch (e) {
      return Left(AuthFailure(_mapAuthError(e.code)));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  // ── Helpers ─────────────────────────────────────────────────────────────
  Future<Either<Failure, UserEntity>> _fetchUser(String uid) async {
    try {
      // ⚠️ Critical: ننتظر القيمة المكتملة من Firestore (isLoaded:true)
      // وليس placeholder الـ FirebaseAuth — حتى لا نرجّع دور خاطئ.
      final user = await remote
          .watchCurrentUser()
          .firstWhere(
            (u) => u != null && u.uid == uid && u.isLoaded,
            orElse: () => null,
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => null,
          );
      if (user == null) {
        return const Left(NotFoundFailure('تعذر جلب بيانات المستخدم'));
      }
      return Right(user);
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  String _mapAuthError(String code) {
    switch (code) {
      // ── البريد ───────────────────────────────────────────────────
      case 'user-not-found':
        return 'لا يوجد حساب مرتبط بهذا البريد الإلكتروني.';
      case 'wrong-password':
        return 'كلمة المرور غير صحيحة.';
      case 'invalid-email':
        return 'صيغة البريد الإلكتروني غير صحيحة.';
      case 'invalid-credential':
        return 'البريد الإلكتروني أو كلمة المرور غير صحيحة.';
      case 'email-already-in-use':
        return 'هذا البريد الإلكتروني مستخدم بالفعل.';
      case 'weak-password':
        return 'كلمة المرور ضعيفة جداً.';
      case 'requires-recent-login':
        return 'انتهت صلاحية الجلسة. أعد تسجيل الدخول.';
      case 'same-email':
        return 'البريد الجديد مطابق للحالي.';
      case 'email-account-required':
        return 'هذا الحساب مسجَّل بالهاتف فقط، لا يمكن تغيير البريد.';
      case 'user-banned':
        return 'تم حظر هذا الحساب من استخدام التطبيق.';

      // ── الهاتف ───────────────────────────────────────────────────
      case 'user-not-registered':
        return 'لا يوجد حساب مسجَّل بهذا الرقم. يرجى إنشاء حساب جديد أولاً.';
      case 'invalid-phone-number':
        return 'رقم الهاتف غير صالح. تأكد من رمز الدولة + الرقم.';
      case 'invalid-verification-code':
        return 'رمز التحقق غير صحيح.';
      case 'invalid-verification-id':
        return 'انتهت صلاحية الجلسة. اطلب رمزاً جديداً.';
      case 'missing-phone-number':
        return 'يرجى إدخال رقم الهاتف.';
      case 'session-expired':
        return 'انتهت صلاحية الجلسة. اطلب رمزاً جديداً.';
      case 'quota-exceeded':
        return 'تجاوز حد إرسال الـ SMS اليومي. حاول غداً.';
      case 'app-not-authorized':
        return 'التطبيق غير مُصرَّح له. (SHA-1/SHA-256 ناقص أو خطأ في Firebase Console).';
      case 'missing-client-identifier':
      case 'missing-app-credential':
        return 'إعداد ناقص: تأكد من تفعيل Play Integrity أو reCAPTCHA في Firebase Console.';
      case 'web-context-cancelled':
        return 'تم إلغاء عملية التحقق.';
      case 'captcha-check-failed':
        return 'فشل التحقّق الأمني. حاول مجدداً.';
      case 'billing-not-enabled':
        return 'حساب Firebase يحتاج تفعيل خطة Blaze لإرسال SMS الحقيقية.';

      // ── عام ─────────────────────────────────────────────────────
      case 'too-many-requests':
        return 'محاولات كثيرة جداً. حاول لاحقاً.';
      case 'network-request-failed':
        return 'لا يوجد اتصال بالإنترنت.';
      case 'operation-not-allowed':
        return 'طريقة التسجيل هذه غير مفعّلة في Firebase Console.';
      default:
        return 'خطأ في المصادقة ($code)';
    }
  }
}
