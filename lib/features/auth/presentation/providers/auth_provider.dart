import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:my_fashion_app/core/error/failures.dart';
import 'package:my_fashion_app/core/usecase/usecase.dart';
import 'package:my_fashion_app/features/auth/domain/entities/user_entity.dart';
import 'package:my_fashion_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:my_fashion_app/features/auth/domain/usecases/send_otp.dart';
import 'package:my_fashion_app/features/auth/domain/usecases/send_password_reset.dart';
import 'package:my_fashion_app/features/auth/domain/usecases/sign_in_with_email.dart';
import 'package:my_fashion_app/features/auth/domain/usecases/sign_out.dart';
import 'package:my_fashion_app/features/auth/domain/usecases/sign_up_with_email.dart';
import 'package:my_fashion_app/features/auth/domain/usecases/verify_otp.dart';
import 'package:my_fashion_app/features/auth/domain/usecases/watch_current_user.dart';

enum AuthStatus { unknown, authenticated, unauthenticated, revoked }

class AuthProvider extends ChangeNotifier {
  final WatchCurrentUser _watchCurrentUser;
  final SignInWithEmail _signInWithEmail;
  final SignUpWithEmail _signUpWithEmail;
  final SendOtp _sendOtp;
  final VerifyOtp _verifyOtp;
  final SendPasswordReset _sendPasswordReset;
  final SignOut _signOut;

  StreamSubscription<UserEntity?>? _userSub;

  AuthStatus _status = AuthStatus.unknown;
  UserEntity? _user;
  Failure? _failure;
  bool _busy = false;

  AuthProvider({
    required WatchCurrentUser watchCurrentUser,
    required SignInWithEmail signInWithEmail,
    required SignUpWithEmail signUpWithEmail,
    required SendOtp sendOtp,
    required VerifyOtp verifyOtp,
    required SendPasswordReset sendPasswordReset,
    required SignOut signOut,
  })  : _watchCurrentUser = watchCurrentUser,
        _signInWithEmail = signInWithEmail,
        _signUpWithEmail = signUpWithEmail,
        _sendOtp = sendOtp,
        _verifyOtp = verifyOtp,
        _sendPasswordReset = sendPasswordReset,
        _signOut = signOut {
    _startWatching();
  }

  AuthStatus get status => _status;
  UserEntity? get user => _user;
  Failure? get failure => _failure;
  bool get busy => _busy;

  void _startWatching() {
    _userSub?.cancel();
    _userSub = _watchCurrentUser().listen(
      (u) {
        _user = u;
        if (u == null) {
          _status = AuthStatus.unauthenticated;
        } else if (u.isRevoked) {
          _status = AuthStatus.revoked;
        } else {
          _status = AuthStatus.authenticated;
        }
        notifyListeners();
      },
      onError: (e) {
        _failure = UnknownFailure(e.toString());
        notifyListeners();
      },
    );
  }

  Future<bool> signInWithEmail(String email, String password) async {
    return _run(() async {
      final res = await _signInWithEmail(
          SignInWithEmailParams(email: email, password: password));
      return res.fold((f) {
        _failure = f;
        return false;
      }, (_) => true);
    });
  }

  Future<bool> signUpWithEmail({
    required String email,
    required String password,
    required String name,
  }) async {
    return _run(() async {
      final res = await _signUpWithEmail(SignUpWithEmailParams(
        email: email,
        password: password,
        name: name,
      ));
      return res.fold((f) {
        _failure = f;
        return false;
      }, (_) => true);
    });
  }

  /// يرجع verificationId عند النجاح، null عند الفشل (failure مُعَيَّن)
  Future<PhoneVerificationResult?> sendOtp(String phoneNumber) async {
    _busy = true;
    _failure = null;
    notifyListeners();
    final res = await _sendOtp(phoneNumber);
    _busy = false;
    return res.fold((f) {
      _failure = f;
      notifyListeners();
      return null;
    }, (r) {
      notifyListeners();
      return r;
    });
  }

  Future<bool> verifyOtp({
    required String verificationId,
    required String smsCode,
  }) {
    return _run(() async {
      final res = await _verifyOtp(VerifyOtpParams(
        verificationId: verificationId,
        smsCode: smsCode,
      ));
      return res.fold((f) {
        _failure = f;
        return false;
      }, (_) => true);
    });
  }

  Future<bool> sendPasswordReset(String email) {
    return _run(() async {
      final res = await _sendPasswordReset(email);
      return res.fold((f) {
        _failure = f;
        return false;
      }, (_) => true);
    });
  }

  Future<void> signOut() async {
    final res = await _signOut(const NoParams());
    res.fold((f) {
      _failure = f;
      notifyListeners();
    }, (_) => null);
  }

  void clearFailure() {
    if (_failure != null) {
      _failure = null;
      notifyListeners();
    }
  }

  Future<bool> _run(Future<bool> Function() action) async {
    _busy = true;
    _failure = null;
    notifyListeners();
    final ok = await action();
    _busy = false;
    notifyListeners();
    return ok;
  }

  @override
  void dispose() {
    _userSub?.cancel();
    super.dispose();
  }
}
