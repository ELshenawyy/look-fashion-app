import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:my_fashion_app/core/error/exceptions.dart';
import 'package:my_fashion_app/features/auth/data/models/user_model.dart';

/// يستخرج رمز الدولة فقط (مثال: "+249") من رقم E.164 كامل، لتسجيل
/// معلومات تشخيصية في Crashlytics دون تخزين رقم الهاتف الكامل (PII).
String _dialCodePrefix(String e164Phone) {
  final match = RegExp(r'^\+\d{1,4}').firstMatch(e164Phone);
  return match?.group(0) ?? '+?';
}

/// يسجّل فشل OTP كحدث غير قاتل (non-fatal) في Crashlytics عشان نقدر
/// نشوف معدّلات/أكواد الفشل الحقيقية من المستخدمين في production
/// (قبل كده كانت هذه الأخطاء تُطبع فقط بـ debugPrint، وهو غير مرئي
/// في release builds).
void _recordOtpFailure({
  required String flow,
  required Object error,
  String? phone,
}) {
  final code = error is FirebaseAuthException ? error.code : 'unknown';
  final message = error is FirebaseAuthException ? error.message : error.toString();
  FirebaseCrashlytics.instance.recordError(
    error,
    null,
    fatal: false,
    reason: 'otp-failure:$flow',
    information: [
      'flow: $flow',
      'code: $code',
      'message: $message',
      if (phone != null) 'dialCode: ${_dialCodePrefix(phone)}',
    ],
  );
}

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

  /// يتحقق هل الرقم (بصيغة E.164) مسجَّل في التطبيق — عبر Cloud Function
  /// (انظر functions/index.js → isPhoneRegistered). يُستخدم قبل إرسال OTP
  /// في flow الدخول بالهاتف لمنع إرسال رمز لرقم بلا حساب.
  Future<bool> isPhoneRegistered(String phoneNumber);

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

  /// يحدّث بريد المستخدم الحالي.
  /// 1) reauthenticate بكلمة المرور الحالية (مطلوب من Firebase لحماية الحساب)
  /// 2) `verifyBeforeUpdateEmail` — يرسل رابط تأكيد للبريد **الجديد**
  /// 3) المستخدم يضغط الرابط → Firebase يحدّث الإيميل
  /// 4) Firestore `users/{uid}.email` يتحدّث في reloadCurrentUser التالية
  Future<void> updateEmail({
    required String currentPassword,
    required String newEmail,
  });

  /// يُعيد تحميل بيانات المستخدم من Firebase ويرجع UserModel جديد
  /// يعكس آخر حالة (مهم لالتقاط تحديث emailVerified بعد ضغط الرابط).
  Future<UserModel?> reloadCurrentUser();
}

class FirebaseAuthDataSourceImpl implements FirebaseAuthDataSource {
  final FirebaseAuth _auth;
  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;

  FirebaseAuthDataSourceImpl(this._auth, this._db, this._functions);

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
          debugPrint('[watchCurrentUser] Firestore error (fallback to Firebase Auth): $e');
          // لا نرسل stream error — المستخدم لا يزال مُسجَّل دخوله عبر Firebase Auth
          // نُبقيه بـ isLoaded:false حتى يتعافى Firestore تلقائياً
          if (!controller.isClosed && activeUid == user.uid) {
            controller.add(_fromFirebaseUser(user));
          }
        },
      );
    }

    controller = StreamController<UserModel?>(
      onListen: () {
        // ── Pre-populate من الـ cache المتزامن ──────────────────────────────
        // _auth.currentUser متاح فورًا بعد Firebase.initializeApp() من
        // SharedPreferences بدون انتظار network. نستخدمه لمنع الـ null
        // الكاذب اللي بيبعثه authStateChanges() قبل ما يُحمَّل الـ cache.
        final syncUser = _auth.currentUser;
        if (syncUser != null && !controller.isClosed) {
          activeUid = syncUser.uid;
          controller.add(_fromFirebaseUser(syncUser));
          subscribeToUserDoc(syncUser);
        }

        authSub = _auth.authStateChanges().listen((user) async {
          // ── Guard: تجاهل الـ null الكاذب عند Cold Start ─────────────────
          // authStateChanges() أحيانًا يبعت null لحظيًا قبل ما يُعيد
          // تحميل الـ cached user من الـ persistent storage. لو
          // currentUser لا يزال موجودًا، الـ null ده عابر وليس logout حقيقي.
          if (user == null && _auth.currentUser != null) {
            debugPrint('[watchCurrentUser] transient null ignored — currentUser still set');
            return;
          }

          // ⚠️ ألغِ subscription المستخدم القديم فوراً
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
    await _ensureNotBanned(uid);
    return uid;
  }

  /// يتحقق من أن الحساب غير محظور (banned=true في Firestore).
  /// إذا كان محظوراً → يسجّل الخروج فوراً ويرمي استثناء يمنع الدخول.
  Future<void> _ensureNotBanned(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    final banned = doc.data()?['banned'] as bool? ?? false;
    if (banned) {
      await _auth.signOut();
      throw FirebaseAuthException(
        code: 'user-banned',
        message: 'هذا الحساب محظور من استخدام التطبيق.',
      );
    }
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
    // لما يتحقق من البريد، حدّث Firestore عشان يظهر في Staff Management
    if (fresh.emailVerified) {
      try {
        await _db.collection('users').doc(fresh.uid).update({
          'emailVerified': true,
        });
      } catch (_) {
        // non-critical — التحقق اتم والـ auth state هيتحدث تلقائياً
      }
    }
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
        _recordOtpFailure(
            flow: 'sendOtpForPhoneUpdate', error: e, phone: newPhoneNumber);
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
    try {
      await user.updatePhoneNumber(cred);
    } catch (e) {
      _recordOtpFailure(flow: 'updatePhoneNumber', error: e);
      rethrow;
    }
    // تحديث Firestore users/{uid}.phone بالرقم الجديد
    final updated = _auth.currentUser;
    if (updated?.phoneNumber != null) {
      await _db.collection('users').doc(user.uid).update({
        'phone': updated!.phoneNumber,
      });
    }
  }

  @override
  Future<void> updateEmail({
    required String currentPassword,
    required String newEmail,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const ServerException('not-authenticated');
    }
    final currentEmail = user.email;
    if (currentEmail == null || currentEmail.isEmpty) {
      // مستخدم OTP لا يملك إيميل/كلمة سر — لا يمكن تغيير الإيميل
      throw FirebaseAuthException(
        code: 'email-account-required',
        message: 'هذا الحساب مسجَّل بالهاتف فقط.',
      );
    }
    final trimmed = newEmail.trim();
    if (trimmed.isEmpty) {
      throw FirebaseAuthException(
        code: 'invalid-email',
        message: 'البريد الإلكتروني الجديد مطلوب.',
      );
    }
    if (trimmed.toLowerCase() == currentEmail.toLowerCase()) {
      throw FirebaseAuthException(
        code: 'same-email',
        message: 'البريد الجديد مطابق للحالي.',
      );
    }

    // 1) Reauthenticate بكلمة المرور الحالية
    final cred = EmailAuthProvider.credential(
      email: currentEmail,
      password: currentPassword,
    );
    await user.reauthenticateWithCredential(cred);

    // 2) إرسال رابط تأكيد للبريد الجديد. الإيميل الفعلي يتغير لما اليوزر
    //    يضغط الرابط من بريده الجديد. آمن (يمنع سرقة الحسابات).
    await user.verifyBeforeUpdateEmail(trimmed);

    debugPrint('[updateEmail] ✓ verification link sent to: $trimmed');
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
        _recordOtpFailure(flow: 'sendOtp', error: e, phone: phoneNumber);
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
  Future<bool> isPhoneRegistered(String phoneNumber) async {
    final callable = _functions.httpsCallable('isPhoneRegistered');
    final res = await callable.call<Map<String, dynamic>>(
      {'phone': phoneNumber},
    );
    return res.data['registered'] == true;
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
    final UserCredential result;
    try {
      result = await _auth.signInWithCredential(cred);
    } catch (e) {
      _recordOtpFailure(flow: 'verifyOtp', error: e);
      rethrow;
    }
    final uid = result.user?.uid;
    if (uid == null) throw const ServerException('auth-null-user');

    final docRef = _db.collection('users').doc(uid);
    final doc = await docRef.get();

    // ── Phone signup flow ──────────────────────────────────────────────
    // إذا مُرَّر displayName → نتأكد من وجود مستند users/{uid}.
    // إن لم يكن موجوداً → ننشئه بدور 'user' (مستخدم جديد سجَّل بالهاتف).
    // إن كان موجوداً → لا نعدّله (احتراماً للحساب الموجود).
    if (displayName != null && displayName.trim().isNotEmpty) {
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
    } else if (!doc.exists) {
      // ── Phone login flow ────────────────────────────────────────────
      // ⚠️ Critical: signInWithCredential ينجح وينشئ حساب Firebase Auth
      // جديد تلقائياً حتى لو الرقم لم يُسجَّل في التطبيق من قبل (Firebase
      // لا يفرّق بين تسجيل دخول/حساب جديد بالهاتف). إذا لم يوجد مستند
      // Firestore → هذا الرقم لم يُسجَّل فعلياً. نُلغي الحساب الوهمي فوراً
      // (وإلا سيبقى الجهاز "مسجَّل دخول" بحساب بلا بيانات → شاشة تحميل
      // لانهائية في AppShell عند إعادة التشغيل) ونمنع الدخول.
      await _auth.signOut();
      throw FirebaseAuthException(
        code: 'user-not-registered',
        message: 'لا يوجد حساب مسجَّل بهذا الرقم.',
      );
    }

    await _ensureNotBanned(uid);
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
