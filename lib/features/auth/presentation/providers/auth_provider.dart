import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:my_fashion_app/core/error/failures.dart';
import 'package:my_fashion_app/core/usecase/usecase.dart';
import 'package:my_fashion_app/features/addresses/presentation/providers/addresses_provider.dart';
import 'package:my_fashion_app/features/auth/domain/entities/user_entity.dart';
import 'package:my_fashion_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:my_fashion_app/features/auth/domain/usecases/send_otp.dart';
import 'package:my_fashion_app/features/auth/domain/usecases/send_password_reset.dart';
import 'package:my_fashion_app/features/auth/domain/usecases/sign_in_with_email.dart';
import 'package:my_fashion_app/features/auth/domain/usecases/sign_out.dart';
import 'package:my_fashion_app/features/auth/domain/usecases/sign_up_with_email.dart';
import 'package:my_fashion_app/features/auth/domain/usecases/verify_otp.dart';
import 'package:my_fashion_app/features/auth/domain/usecases/watch_current_user.dart';
import 'package:my_fashion_app/features/cart/presentation/providers/cart_provider.dart';
import 'package:my_fashion_app/features/favorites/presentation/providers/favorites_provider.dart';
import 'package:my_fashion_app/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:my_fashion_app/features/orders/presentation/providers/orders_provider.dart';
import 'package:my_fashion_app/features/products/presentation/providers/categories_provider.dart';
import 'package:my_fashion_app/features/products/presentation/providers/products_provider.dart';

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
        } else if (!u.isLoaded) {
          // ⚠️ بيانات Firestore لم تصل بعد — نُبقي حالة "unknown" حتى
          // لا تُعرض شاشات الدور الخاطئ (إصلاح تداخل حسابات الأدمن).
          _status = AuthStatus.unknown;
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
      }, (loadedUser) {
        // ⚠️ Critical: ضع المستخدم المحمّل فوراً (لا تنتظر stream)
        // → AppShell يلتقط الدور الصحيح قبل أي navigation.
        _user = loadedUser;
        if (loadedUser.isRevoked) {
          _status = AuthStatus.revoked;
        } else {
          _status = AuthStatus.authenticated;
        }
        return true;
      });
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
      }, (loadedUser) {
        _user = loadedUser;
        _status = AuthStatus.authenticated;
        return true;
      });
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
    String? displayName,
  }) {
    return _run(() async {
      final res = await _verifyOtp(VerifyOtpParams(
        verificationId: verificationId,
        smsCode: smsCode,
        displayName: displayName,
      ));
      return res.fold((f) {
        _failure = f;
        return false;
      }, (loadedUser) {
        // ⚠️ نفس مبدأ signInWithEmail: نضع المستخدم فوراً
        _user = loadedUser;
        if (loadedUser.isRevoked) {
          _status = AuthStatus.revoked;
        } else {
          _status = AuthStatus.authenticated;
        }
        return true;
      });
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
    // ── Hard Logout ─────────────────────────────────────────────────────
    // 1) ألغِ stream subscription الحالية (تنظيف Firestore listeners)
    await _userSub?.cancel();
    _userSub = null;

    // 2) امسح state كل الـ providers الأخرى (Cart/Favorites/...)
    _resetAllUserState();

    // 3) صفّر state المحلي فوراً قبل أي async — يضمن أن AppShell ينتقل
    //    إلى LoginPage فوراً ولا يحاول render أي شاشة بحساب قديم.
    _user = null;
    _failure = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();

    // 4) Sign out من Firebase
    final res = await _signOut(const NoParams());
    res.fold((f) {
      _failure = f;
      notifyListeners();
    }, (_) => null);

    // 5) أعد تشغيل watch — اشتراك stream جديد نظيف للمستخدم التالي
    _startWatching();
  }

  /// يطلب من كل provider يحوي بيانات user-specific أن يمسحها.
  void _resetAllUserState() {
    final sl = GetIt.instance;
    void safeReset(Function() fn) {
      try {
        fn();
      } catch (_) {
        // إذا الـ provider غير مسجَّل أو فشل reset → تجاهل
      }
    }

    safeReset(() => sl<CartProvider>().clear());
    safeReset(() => sl<FavoritesProvider>().reset());
    safeReset(() => sl<AddressesProvider>().reset());
    safeReset(() => sl<NotificationsProvider>().reset());
    safeReset(() => sl<OrdersProvider>().reset());
    safeReset(() => sl<ProductsProvider>().reset());
    safeReset(() => sl<CategoriesProvider>().reset());
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
