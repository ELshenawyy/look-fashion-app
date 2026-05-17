import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
    return cred.user!.uid;
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
    final uid = cred.user!.uid;
    await _db.collection('users').doc(uid).set(
          UserModel.initialFirestoreDoc(uid: uid, email: email, name: name),
        );
    return uid;
  }

  @override
  Future<String> sendOtp(String phoneNumber) {
    final completer = Completer<String>();
    _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: (PhoneAuthCredential _) {},
      verificationFailed: (FirebaseAuthException e) {
        if (!completer.isCompleted) completer.completeError(e);
      },
      codeSent: (String verificationId, int? _) {
        if (!completer.isCompleted) completer.complete(verificationId);
      },
      codeAutoRetrievalTimeout: (_) {},
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
    final uid = result.user!.uid;

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
          'phone': result.user!.phoneNumber,
          'role': 'user',
          'createdAt': FieldValue.serverTimestamp(),
        });
        try {
          await result.user!.updateDisplayName(displayName.trim());
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
