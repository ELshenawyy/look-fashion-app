import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:my_fashion_app/core/error/exceptions.dart';
import 'package:my_fashion_app/features/auth/data/models/user_model.dart';

abstract class FirebaseAuthDataSource {
  Stream<UserModel?> watchCurrentUser();
  String? get currentUid;

  Future<String> signInWithEmail({
    required String email,
    required String password,
  });

  Future<String> signUpWithEmail({
    required String email,
    required String password,
    required String name,
  });

  Future<String> sendOtp(String phoneNumber);

  Future<String> verifyOtp({
    required String verificationId,
    required String smsCode,
    String? displayName, // إذا مُرَّر → flow التسجيل بالهاتف (ينشئ مستند users إن لم يكن موجوداً)
  });

  Future<void> sendPasswordReset(String email);
  Future<void> signOut();

  /// إعادة إرسال رابط تفعيل البريد للمستخدم الحالي.
  /// لا يفعل شيئاً لو المستخدم مُفعَّل بالفعل.
  Future<void> sendEmailVerification();

  /// يرسل OTP للرقم الجديد (للتحقق منه قبل ربطه بالحساب).
  /// يُستخدم في flow تعديل رقم الهاتف من Profile.
  /// يرجع verificationId.
  Future<String> sendOtpForPhoneUpdate(String newPhoneNumber);

  /// يحدّث رقم الهاتف الفعلي للمستخدم الحالي + يحدّث Firestore.
  /// يجب أن يُسبَق بـ sendOtpForPhoneUpdate ثم إدخال المستخدم الـ OTP.
  Future<void> updatePhoneNumber({
    required String verificationId,
    required String smsCode,
  });

  /// يُعيد تحميل بيانات المستخدم من Firebase ويرجع UserModel جديد
  /// يعكس آخر حالة (مهم لالتقاط تحديث emailVerified بعد ضغط الرابط).
  Future<UserModel?> reloadCurrentUser();
}

class FirebaseAuthDataSourceImpl implements FirebaseAuthDataSource {
  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  FirebaseAuthDataSourceImpl(this._auth, this._db);

  @override
  String? get currentUid => _auth.currentUser?.uid;

  @override
  Stream<UserModel?> watchCurrentUser() {
    // ⚠️ Critical: نستخدم StreamController يدوي مع stream switching صحيح،
    // لأن `async*` + `yield*` لا تُلغي اشتراك Firestore عند تغيير
    // المستخدم → كان يحتفظ ببيانات الحساب القديم بعد تسجيل خروج/دخول.
    late StreamController<UserModel?> controller;
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? userDocSub;
    StreamSubscription<User?>? authSub;
    String? activeUid;

    Future<void> closeUserDocSub() async {
      await userDocSub?.cancel();
      userDocSub = null;
    }

    void subscribeToUserDoc(User user) {
      userDocSub = _db
          .collection('users')
          .doc(user.uid)
          .snapshots()
          .listen(
        (doc) {
          // تحقق إضافي: إذا تغيّر uid أثناء وصول snapshot قديم، تجاهل
          if (controller.isClosed || activeUid != user.uid) return;
          if (!doc.exists) {
            controller.add(_fromFirebaseUser(user));
          } else {
            controller.add(UserModel.fromFirestore(
              doc,
              emailVerified: user.emailVerified,
            ));
          }
        },
        onError: (Object e) {
          if (!controller.isClosed) controller.addError(e);
        },
      );
    }

    controller = StreamController<UserModel?>(
      onListen: () {
        authSub = _auth.authStateChanges().listen((user) async {
          // ⚠️ ألغِ subscription المستخدم القديم فوراً (root cause fix)
          await closeUserDocSub();
          activeUid = user?.uid;

          if (user == null) {
            if (!controller.isClosed) controller.add(null);
            return;
          }

          // 1) placeholder فوري بـ isLoaded:false → AuthProvider يبقى loading
          if (!controller.isClosed) {
            controller.add(_fromFirebaseUser(user));
          }

          // 2) اشتراك جديد للمستخدم الحالي
          subscribeToUserDoc(user);
        });
      },
      onCancel: () async {
        await closeUserDocSub();
        await authSub?.cancel();
        authSub = null;
      },
    );

    return controller.stream;
  }

  /// placeholder بـ `isLoaded:false` — يستخدمه AuthProvider للبقاء في
  /// حالة "loading" حتى يصل الدور الفعلي من Firestore.
  UserModel _fromFirebaseUser(User user) => UserModel(
        uid: user.uid,
        email: user.email,
        phone: user.phoneNumber,
        displayName: user.displayName,
        emailVerified: user.emailVerified,
        isLoaded: false,
      );

  @override
  Future<String> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    final uid = cred.user?.uid;
    if (uid == null) throw const ServerException('auth-null-user');
    return uid;
  }

  @override
  Future<String> signUpWithEmail({
    required String email,
    required String password,
    required String name,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final uid = cred.user?.uid;
    if (uid == null) throw const ServerException('auth-null-user');
    await _db.collection('users').doc(uid).set(
          UserModel.initialFirestoreDoc(uid: uid, email: email, name: name),
        );
    // إرسال رابط التفعيل تلقائياً (غير قاتل لو فشل — يقدر يطلب resend لاحقاً)
    try {
      await cred.user?.sendEmailVerification();
    } catch (e) {
      // ignore — Firebase rate-limit أو شبكة. الـ verification screen
      // ستوفّر زر إعادة الإرسال.
    }
    return uid;
  }

  @override
  Future<void> sendEmailVerification() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const ServerException('not-authenticated');
    }
    if (user.emailVerified) return; // مفعَّل بالفعل
    await user.sendEmailVerification();
  }

  @override
  Future<UserModel?> reloadCurrentUser() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    await user.reload();
    final fresh = _auth.currentUser;
    if (fresh == null) return null;
    return _fromFirebaseUser(fresh);
  }

  @override
  Future<String> sendOtpForPhoneUpdate(String newPhoneNumber) {
    // نفس منطق sendOtp لكن مع validation وlogging مختلف للسياق
    if (!newPhoneNumber.startsWith('+')) {
      return Future.error(FirebaseAuthException(
        code: 'invalid-phone-number',
        message: 'الرقم الجديد لازم يبدأ بـ + ثم رمز الدولة.',
      ));
    }
    debugPrint(
        '[sendOtpForPhoneUpdate] → verifyPhoneNumber for: $newPhoneNumber');
    final completer = Completer<String>();
    _auth.verifyPhoneNumber(
      phoneNumber: newPhoneNumber,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (PhoneAuthCredential _) {
        debugPrint('[sendOtpForPhoneUpdate] ✓ auto-verified');
      },
      verificationFailed: (FirebaseAuthException e) {
        debugPrint(
            '[sendOtpForPhoneUpdate] ❌ failed: code=${e.code} msg=${e.message}');
        if (!completer.isCompleted) completer.completeError(e);
      },
      codeSent: (String verificationId, int? resendToken) {
        debugPrint('[sendOtpForPhoneUpdate] ✓ codeSent');
        if (!completer.isCompleted) completer.complete(verificationId);
      },
      codeAutoRetrievalTimeout: (String _) {},
    );
    return completer.future;
  }

  @override
  Future<void> updatePhoneNumber({
    required String verificationId,
    required String smsCode,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const ServerException('not-authenticated');
    }
    final cred = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    // قد يرمي 'requires-recent-login' إذا الجلسة قديمة (>5 دقائق).
    await user.updatePhoneNumber(cred);
    // تحديث Firestore users/{uid}.phone بالرقم الجديد
    final updated = _auth.currentUser;
    if (updated?.phoneNumber != null) {
      await _db.collection('users').doc(user.uid).update({
        'phone': updated!.phoneNumber,
      });
    }
  }

  @override
  Future<String> sendOtp(String phoneNumber) {
    // ⚠ Sanity check: لازم يكون E.164 (+countryCode...). intl_phone_field
    // يعطي الـ completeNumber صحيحاً، لكن نحرص هنا قبل إرساله لـ Firebase.
    if (!phoneNumber.startsWith('+')) {
      debugPrint(
          '[sendOtp] ❌ INVALID format — must start with +countryCode. got: "$phoneNumber"');
      return Future.error(FirebaseAuthException(
        code: 'invalid-phone-number',
        message: 'الرقم لازم يبدأ بـ + ثم رمز الدولة (E.164 format).',
      ));
    }

    debugPrint('[sendOtp] → verifyPhoneNumber for: $phoneNumber');
    final completer = Completer<String>();
    _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (PhoneAuthCredential _) {
        // Auto-retrieval على بعض أجهزة Android (يقرأ SMS تلقائياً).
        // لا نحتاج عمل شيء هنا — verifyOtp اللاحق يستخدم verificationId.
        debugPrint('[sendOtp] ✓ verificationCompleted (auto-retrieval)');
      },
      verificationFailed: (FirebaseAuthException e) {
        // ⚠ Critical: نطبع كل التفاصيل عشان نقدر نشخّص لماذا فشل
        debugPrint('═══════ [sendOtp] ❌ verificationFailed ═══════');
        debugPrint('  code:    ${e.code}');
        debugPrint('  message: ${e.message}');
        debugPrint('  plugin:  ${e.plugin}');
        debugPrint('  details: ${e.toString()}');
        debugPrint('══════════════════════════════════════════════');
        if (!completer.isCompleted) completer.completeError(e);
      },
      codeSent: (String verificationId, int? resendToken) {
        debugPrint(
            '[sendOtp] ✓ codeSent. verificationId=${verificationId.substring(0, 8)}... resendToken=$resendToken');
        if (!completer.isCompleted) completer.complete(verificationId);
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        debugPrint('[sendOtp] ⏱ codeAutoRetrievalTimeout');
      },
    );
    return completer.future;
  }

  @override
  Future<String> verifyOtp({
    required String verificationId,
    required String smsCode,
    String? displayName,
  }) async {
    final cred = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    final result = await _auth.signInWithCredential(cred);
    final uid = result.user?.uid;
    if (uid == null) throw const ServerException('auth-null-user');

    // ── Phone signup flow ──────────────────────────────────────────────
    // إذا مُرَّر displayName → نتأكد من وجود مستند users/{uid}.
    // إن لم يكن موجوداً → ننشئه بدور 'user' (مستخدم جديد سجَّل بالهاتف).
    // إن كان موجوداً → لا نعدّله (احتراماً للحساب الموجود).
    if (displayName != null && displayName.trim().isNotEmpty) {
      final docRef = _db.collection('users').doc(uid);
      final doc = await docRef.get();
      if (!doc.exists) {
        await docRef.set({
          'uid': uid,
          'name': displayName.trim(),
          'phone': result.user?.phoneNumber,
          'role': 'user',
          'createdAt': FieldValue.serverTimestamp(),
        });
        try {
          await result.user?.updateDisplayName(displayName.trim());
        } catch (_) {
          // غير حرج
        }
      }
    }

    return uid;
  }

  @override
  Future<void> sendPasswordReset(String email) {
    return _auth.sendPasswordResetEmail(email: email);
  }

  @override
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      throw ServerException(e.toString());
    }
  }
}
