import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:my_fashion_app/core/error/failures.dart';
import 'package:my_fashion_app/core/usecase/usecase.dart';
import 'package:my_fashion_app/features/addresses/presentation/providers/addresses_provider.dart';
import 'package:my_fashion_app/features/auth/domain/entities/user_entity.dart';
import 'package:my_fashion_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:my_fashion_app/features/auth/domain/usecases/is_phone_registered.dart';
import 'package:my_fashion_app/features/auth/domain/usecases/reload_user.dart';
import 'package:my_fashion_app/features/auth/domain/usecases/send_email_verification.dart';
import 'package:my_fashion_app/features/auth/domain/usecases/send_otp.dart';
import 'package:my_fashion_app/features/auth/domain/usecases/send_otp_for_phone_update.dart';
import 'package:my_fashion_app/features/auth/domain/usecases/send_password_reset.dart';
import 'package:my_fashion_app/features/auth/domain/usecases/sign_in_with_email.dart';
import 'package:my_fashion_app/features/auth/domain/usecases/sign_out.dart';
import 'package:my_fashion_app/features/auth/domain/usecases/sign_up_with_email.dart';
import 'package:my_fashion_app/features/auth/domain/usecases/update_email.dart';
import 'package:my_fashion_app/features/auth/domain/usecases/update_phone_number.dart';
import 'package:my_fashion_app/features/auth/domain/usecases/verify_otp.dart';
import 'package:my_fashion_app/features/auth/domain/usecases/watch_current_user.dart';
import 'package:my_fashion_app/features/cart/presentation/providers/cart_provider.dart';
import 'package:my_fashion_app/features/favorites/presentation/providers/favorites_provider.dart';
import 'package:my_fashion_app/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:my_fashion_app/features/orders/presentation/providers/orders_provider.dart';
import 'package:my_fashion_app/features/products/presentation/providers/categories_provider.dart';
import 'package:my_fashion_app/features/products/presentation/providers/products_provider.dart';

enum AuthStatus { unknown, authenticated, unauthenticated, revoked, banned }

class AuthProvider extends ChangeNotifier {
  final WatchCurrentUser _watchCurrentUser;
  final SignInWithEmail _signInWithEmail;
  final SignUpWithEmail _signUpWithEmail;
  final SendOtp _sendOtp;
  final IsPhoneRegistered _isPhoneRegistered;
  final VerifyOtp _verifyOtp;
  final SendPasswordReset _sendPasswordReset;
  final SignOut _signOut;
  final SendEmailVerification _sendEmailVerification;
  final ReloadUser _reloadUser;
  final SendOtpForPhoneUpdate _sendOtpForPhoneUpdate;
  final UpdatePhoneNumber _updatePhoneNumber;
  final UpdateEmail _updateEmail;

  StreamSubscription<UserEntity?>? _userSub;

  AuthStatus _status = AuthStatus.unknown;
  UserEntity? _user;
  Failure? _failure;
  bool _busy = false;
  // Cooldown لإعادة إرسال رابط التفعيل (يمنع spam Firebase)
  DateTime? _lastVerificationSentAt;
  Timer? _cooldownTicker;

  AuthProvider({
    required WatchCurrentUser watchCurrentUser,
    required SignInWithEmail signInWithEmail,
    required SignUpWithEmail signUpWithEmail,
    required SendOtp sendOtp,
    required IsPhoneRegistered isPhoneRegistered,
    required VerifyOtp verifyOtp,
    required SendPasswordReset sendPasswordReset,
    required SignOut signOut,
    required SendEmailVerification sendEmailVerification,
    required ReloadUser reloadUser,
    required SendOtpForPhoneUpdate sendOtpForPhoneUpdate,
    required UpdatePhoneNumber updatePhoneNumber,
    required UpdateEmail updateEmail,
  })  : _watchCurrentUser = watchCurrentUser,
        _signInWithEmail = signInWithEmail,
        _signUpWithEmail = signUpWithEmail,
        _sendOtp = sendOtp,
        _isPhoneRegistered = isPhoneRegistered,
        _verifyOtp = verifyOtp,
        _sendPasswordReset = sendPasswordReset,
        _signOut = signOut,
        _sendEmailVerification = sendEmailVerification,
        _reloadUser = reloadUser,
        _sendOtpForPhoneUpdate = sendOtpForPhoneUpdate,
        _updatePhoneNumber = updatePhoneNumber,
        _updateEmail = updateEmail {
    _startWatching();
  }

  AuthStatus get status => _status;
  UserEntity? get user => _user;
  Failure? get failure => _failure;
  bool get busy => _busy;

  /// عداد تنازلي بالثواني للزر "إعادة الإرسال". 0 = جاهز للضغط.
  int get verificationCooldownSec {
    if (_lastVerificationSentAt == null) return 0;
    final elapsed =
        DateTime.now().difference(_lastVerificationSentAt!).inSeconds;
    const cooldown = 60;
    return (cooldown - elapsed).clamp(0, cooldown);
  }

  void _startWatching() {
    _userSub?.cancel();
    _userSub = _watchCurrentUser().listen(
      (u) {
        final previousUser = _user;
        _user = u;
        if (u == null) {
          _status = AuthStatus.unauthenticated;
        } else if (!u.isLoaded) {
          // ⚠️ بيانات Firestore لم تصل بعد — نُبقي حالة "unknown" حتى
          // لا تُعرض شاشات الدور الخاطئ (إصلاح تداخل حسابات الأدمن).
          _status = AuthStatus.unknown;
        } else if (u.isBanned) {
          // ⚠️ حساب محظور نهائياً (طُرد كموظف) — اطرده فوراً حتى لو كان
          // في جلسة نشطة، بصرف النظر عن دوره الحالي.
          _status = AuthStatus.banned;
        } else if (previousUser != null &&
            previousUser.isAdmin &&
            !u.isAdmin &&
            u.isRevoked) {
          // ⚠️ تنزيل صلاحيات حدث أثناء جلسة نشطة (كان أدمن والآن مستخدم
          // عادي) → اطرده من لوحة الإدارة فوراً. لا نعتمد فقط على
          // isRevoked لأن revokedAt يبقى في Firestore للأبد، وإلا
          // سيُحظر تسجيل الدخول كمستخدم عادي إلى الأبد بعد ذلك.
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
        // ملاحظة: لا نتحقق من isRevoked هنا — تسجيل الدخول الجديد
        // يُسمح به دائماً (revokedAt مجرد سجل تاريخي لإلغاء صلاحيات
        // أدمن سابق ولا يجب أن يحظر دخوله كمستخدم عادي).
        _user = loadedUser;
        _status = AuthStatus.authenticated;
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

  /// يتحقق هل الرقم مسجَّل قبل إرسال OTP.
  /// يرجع true (مسجَّل) أو false (غير مسجَّل)، و null عند الخطأ (failure مُعَيَّن).
  Future<bool?> isPhoneRegistered(String phoneNumber) async {
    _busy = true;
    _failure = null;
    notifyListeners();
    final res = await _isPhoneRegistered(phoneNumber);
    _busy = false;
    return res.fold((f) {
      _failure = f;
      notifyListeners();
      return null;
    }, (exists) {
      notifyListeners();
      return exists;
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
        // ⚠️ نفس مبدأ signInWithEmail: نضع المستخدم فوراً، ولا نتحقق
        // من isRevoked — تسجيل الدخول الجديد مسموح دائماً.
        _user = loadedUser;
        _status = AuthStatus.authenticated;
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

    safeReset(() => sl<CartProvider>().unloadForLogout());
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

  /// إعادة إرسال رابط تفعيل البريد. يفشل لو الـ cooldown نشط.
  /// يرجع true لو الإرسال نجح، false لو cooldown أو خطأ.
  Future<bool> resendVerificationEmail() async {
    if (verificationCooldownSec > 0) return false;
    final res = await _sendEmailVerification(const NoParams());
    return res.fold(
      (f) {
        _failure = f;
        notifyListeners();
        return false;
      },
      (_) {
        _lastVerificationSentAt = DateTime.now();
        notifyListeners();
        _startCooldownTicker();
        return true;
      },
    );
  }

  /// يُعيد تحميل بيانات المستخدم من Firebase (يلتقط تغيير emailVerified).
  /// يرجع true لو الإيميل فُعّل، false لو لسه.
  Future<bool> refreshCurrentUser() async {
    final res = await _reloadUser(const NoParams());
    return res.fold(
      (f) {
        _failure = f;
        notifyListeners();
        return false;
      },
      (fresh) {
        if (fresh == null) return false;
        // نُحدّث user محلياً ليلتقط emailVerified الجديد.
        // الـ user الناتج من reload يكون isLoaded=false (فقط FirebaseAuth)،
        // لذا ندمج emailVerified الجديد في الـ _user الحالي للحفاظ على الدور.
        if (_user != null) {
          _user = _user!.copyWith(emailVerified: fresh.emailVerified);
        } else {
          _user = fresh;
        }
        // لو فُعّل وكانت الحالة authenticated نُبقيها — الـ AppShell ينتقل تلقائياً
        notifyListeners();
        return fresh.emailVerified;
      },
    );
  }

  /// Timer يُحدّث الـ UI كل ثانية ليُظهر العداد التنازلي.
  void _startCooldownTicker() {
    _cooldownTicker?.cancel();
    _cooldownTicker = Timer.periodic(const Duration(seconds: 1), (t) {
      if (verificationCooldownSec <= 0) {
        t.cancel();
      }
      notifyListeners();
    });
  }

  // ── Phone Number Update (للملف الشخصي) ─────────────────────────────
  /// يرسل OTP للرقم الجديد. يرجع `PhoneVerificationResult` (verificationId)
  /// عند النجاح، أو null عند الفشل (failure مُعيَّن).
  Future<PhoneVerificationResult?> requestPhoneUpdate(
      String newPhoneNumber) async {
    _busy = true;
    _failure = null;
    notifyListeners();
    final res = await _sendOtpForPhoneUpdate(newPhoneNumber);
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

  /// يحدّث رقم الهاتف الفعلي + يُعيد تحميل المستخدم.
  /// يرجع true عند النجاح، false عند الفشل.
  Future<bool> confirmPhoneUpdate({
    required String verificationId,
    required String smsCode,
  }) async {
    _busy = true;
    _failure = null;
    notifyListeners();
    final res = await _updatePhoneNumber(UpdatePhoneNumberParams(
      verificationId: verificationId,
      smsCode: smsCode,
    ));
    _busy = false;
    return res.fold((f) {
      _failure = f;
      notifyListeners();
      return false;
    }, (_) async {
      // أعد تحميل بيانات المستخدم ليلتقط الرقم الجديد
      await refreshCurrentUser();
      notifyListeners();
      return true;
    });
  }

  // ── Email Update (للملف الشخصي — لمستخدمي البريد فقط) ─────────────
  /// يبدأ تحديث البريد. يرسل رابط تأكيد للبريد الجديد.
  /// يرجع true عند الإرسال الناجح، false عند الفشل.
  Future<bool> requestEmailUpdate({
    required String currentPassword,
    required String newEmail,
  }) async {
    _busy = true;
    _failure = null;
    notifyListeners();
    final res = await _updateEmail(UpdateEmailParams(
      currentPassword: currentPassword,
      newEmail: newEmail,
    ));
    _busy = false;
    return res.fold((f) {
      _failure = f;
      notifyListeners();
      return false;
    }, (_) {
      notifyListeners();
      return true;
    });
  }

  @override
  void dispose() {
    _userSub?.cancel();
    _cooldownTicker?.cancel();
    super.dispose();
  }
}
