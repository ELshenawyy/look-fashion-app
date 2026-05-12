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
    return _auth.authStateChanges().asyncExpand((user) {
      if (user == null) return Stream<UserModel?>.value(null);
      return _db
          .collection('users')
          .doc(user.uid)
          .snapshots()
          .map((doc) => doc.exists
              ? UserModel.fromFirestore(doc)
              : _fromFirebaseUser(user));
    });
  }

  UserModel _fromFirebaseUser(User user) => UserModel(
        uid: user.uid,
        email: user.email,
        phone: user.phoneNumber,
        displayName: user.displayName,
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
  }) async {
    final cred = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    final result = await _auth.signInWithCredential(cred);
    return result.user!.uid;
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
