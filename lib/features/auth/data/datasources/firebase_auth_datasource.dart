import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:my_fashion_app/core/error/exceptions.dart';
import 'package:my_fashion_app/features/auth/data/models/user_model.dart';

/// نتيجة إرسال OTP عبر Twilio Verify.
/// [verificationId] = رقم الهاتف نفسه (Twilio يعتمد الرقم كمفتاح جلسة التحقق).
/// [channel] = القناة المستخدمة فعلياً: 'whatsapp' أو 'sms'.
class OtpSendResponse {
  final String verificationId;
  final String channel;
  const OtpSendResponse({required this.verificationId, required this.channel});
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

  /// يرسل OTP عبر Cloud Function `sendPhoneOtp` (Twilio Verify — واتساب أولاً
  /// ثم SMS احتياطياً). [intent]: 'signup' | 'login' | 'update' — يفحص السيرفر
  /// حالة تسجيل الرقم حسب النية قبل الإرسال.
  Future<OtpSendResponse> sendOtp(String phoneNumber, {String intent = 'login'});

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
  Future<OtpSendResponse> sendOtpForPhoneUpdate(String newPhoneNumber);

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
  Future<OtpSendResponse> sendOtpForPhoneUpdate(String newPhoneNumber) {
    if (_auth.currentUser == null) {
      return Future.error(const ServerException('not-authenticated'));
    }
    // intent 'update' — السيرفر يتحقق أن المستخدم مصادَق وأن الرقم الجديد
    // غير مربوط بحساب آخر قبل الإرسال.
    return sendOtp(newPhoneNumber, intent: 'update');
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
    // السيرفر يتحقق من الكود لدى Twilio ثم يحدّث رقم الهاتف في
    // Firebase Auth + Firestore users/{uid}.phone بصلاحيات Admin.
    await _callOtpFunction(() => _functions
            .httpsCallable('verifyPhoneOtp')
            .call<Map<String, dynamic>>({
          'phone': verificationId, // verificationId = الرقم الجديد
          'code': smsCode,
          'intent': 'update',
        }));
    // إعادة تحميل المستخدم ليلتقط العميل الرقم الجديد من سجلّ Auth.
    await _auth.currentUser?.reload();
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

  /// أكواد الأخطاء الآلية التي يرجعها السيرفر (functions/index.js → AUTH_CODES)
  /// في حقل message — بنفس صيغة أكواد Firebase Auth ليفهمها _mapAuthError.
  static const _serverAuthCodes = {
    'phone-already-registered',
    'user-not-registered',
    'invalid-verification-code',
    'session-expired',
    'too-many-requests',
    'invalid-phone-number',
    'user-banned',
    'not-authenticated',
  };

  /// يلفّ استدعاء Cloud Function ويترجم FirebaseFunctionsException إلى
  /// FirebaseAuthException بالكود المناسب — حتى تعمل خرائط الأخطاء الحالية
  /// في AuthRepositoryImpl._mapAuthError بدون أي تعديل.
  Future<T> _callOtpFunction<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on FirebaseFunctionsException catch (e) {
      final msg = (e.message ?? '').trim();
      final String code;
      if (_serverAuthCodes.contains(msg)) {
        code = msg; // السيرفر حدّد الكود صراحةً
      } else if (e.code == 'resource-exhausted') {
        code = 'too-many-requests';
      } else if (e.code == 'unavailable' || e.code == 'deadline-exceeded') {
        code = 'network-request-failed';
      } else {
        code = 'otp-failed';
      }
      debugPrint('[otp] ❌ functions error: ${e.code} / $msg → $code');
      throw FirebaseAuthException(code: code, message: msg);
    }
  }

  @override
  Future<OtpSendResponse> sendOtp(String phoneNumber,
      {String intent = 'login'}) async {
    // ⚠ Sanity check: لازم يكون E.164 (+countryCode...). intl_phone_field
    // يعطي الـ completeNumber صحيحاً، لكن نحرص هنا قبل إرساله للسيرفر.
    if (!phoneNumber.startsWith('+')) {
      debugPrint(
          '[sendOtp] ❌ INVALID format — must start with +countryCode. got: "$phoneNumber"');
      throw FirebaseAuthException(
        code: 'invalid-phone-number',
        message: 'الرقم لازم يبدأ بـ + ثم رمز الدولة (E.164 format).',
      );
    }

    debugPrint('[sendOtp] → sendPhoneOtp($intent) for: $phoneNumber');
    final res = await _callOtpFunction(() => _functions
        .httpsCallable('sendPhoneOtp')
        .call<Map<String, dynamic>>({'phone': phoneNumber, 'intent': intent}));
    final channel = (res.data['channel'] as String?) ?? 'sms';
    debugPrint('[sendOtp] ✓ sent via $channel');
    // Twilio Verify يعتمد رقم الهاتف كمفتاح الجلسة — لا verificationId منفصل.
    return OtpSendResponse(verificationId: phoneNumber, channel: channel);
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
    // ⚠️ Security: التحقق كله server-side (functions/index.js → verifyPhoneOtp)
    // بصلاحيات Admin — السيرفر يفحص الكود لدى Twilio، يفرض قاعدة "رقم مسجَّل
    // لا يُسجَّل من جديد" (يغلق ثغرة تداخل الحسابات وTOCTOU نهائياً)، يفحص
    // الحظر، ثم يُصدر Custom Token. لا يوجد "حساب وهمي" يحتاج signOut كما في
    // النظام القديم — السيرفر يرفض قبل إصدار أي جلسة.
    final isSignup = displayName != null && displayName.trim().isNotEmpty;
    final res =
        await _callOtpFunction(() => _functions.httpsCallable('verifyPhoneOtp')
                .call<Map<String, dynamic>>({
              'phone': verificationId, // verificationId = رقم الهاتف
              'code': smsCode,
              'intent': isSignup ? 'signup' : 'login',
              if (isSignup) 'displayName': displayName.trim(),
            }));

    final token = res.data['customToken'] as String?;
    if (token == null) throw const ServerException('auth-null-token');

    final cred = await _auth.signInWithCustomToken(token);
    final uid = cred.user?.uid;
    if (uid == null) throw const ServerException('auth-null-user');

    // دفاع إضافي — السيرفر يفحص الحظر قبل إصدار الـ token، وهذا فحص ثانٍ رخيص.
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
