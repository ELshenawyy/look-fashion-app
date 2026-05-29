import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:my_fashion_app/core/error/failures.dart';
import 'package:my_fashion_app/features/coupons/domain/entities/coupon_entity.dart';
import 'package:my_fashion_app/features/coupons/domain/repositories/coupon_repository.dart';
import 'package:my_fashion_app/features/coupons/domain/usecases/create_coupon.dart';
import 'package:my_fashion_app/features/coupons/domain/usecases/delete_coupon.dart';
import 'package:my_fashion_app/features/coupons/domain/usecases/redeem_coupon.dart';
import 'package:my_fashion_app/features/coupons/domain/usecases/validate_coupon.dart';
import 'package:my_fashion_app/features/coupons/domain/usecases/watch_coupons.dart';

/// Provider لإدارة الكوبونات — للأدمن (CRUD) + المستخدم (apply/redeem).
class CouponsProvider extends ChangeNotifier {
  final WatchCoupons _watchCoupons;
  final CreateCoupon _createCoupon;
  final DeleteCoupon _deleteCoupon;
  final ValidateCoupon _validateCoupon;
  final RedeemCoupon _redeemCoupon;

  CouponsProvider({
    required WatchCoupons watchCoupons,
    required CreateCoupon createCoupon,
    required DeleteCoupon deleteCoupon,
    required ValidateCoupon validateCoupon,
    required RedeemCoupon redeemCoupon,
  })  : _watchCoupons = watchCoupons,
        _createCoupon = createCoupon,
        _deleteCoupon = deleteCoupon,
        _validateCoupon = validateCoupon,
        _redeemCoupon = redeemCoupon;

  // ── Admin state ─────────────────────────────────────────────────────
  StreamSubscription<List<CouponEntity>>? _sub;
  List<CouponEntity> _coupons = const [];
  bool _loading = false;
  bool _busy = false;
  Failure? _failure;

  List<CouponEntity> get coupons => List.unmodifiable(_coupons);
  bool get loading => _loading;
  bool get busy => _busy;
  Failure? get failure => _failure;

  /// يبدأ مراقبة الكوبونات (للأدمن).
  void startWatching() {
    if (_sub != null) return;
    if (_coupons.isEmpty) {
      _loading = true;
      notifyListeners();
    }
    _sub = _watchCoupons().listen(
      (list) {
        _coupons = list;
        _loading = false;
        _failure = null;
        notifyListeners();
      },
      onError: (e) {
        _failure = UnknownFailure(e.toString());
        _loading = false;
        notifyListeners();
      },
    );
  }

  Future<bool> createCoupon(
      CouponInput input, String adminUid) async {
    _busy = true;
    _failure = null;
    notifyListeners();
    final res = await _createCoupon(
        CreateCouponParams(input: input, adminUid: adminUid));
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

  Future<bool> deleteCoupon(String couponId) async {
    _busy = true;
    _failure = null;
    notifyListeners();
    final res = await _deleteCoupon(DeleteCouponParams(couponId));
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

  // ── User-side: apply في checkout ────────────────────────────────────
  /// يرجع ValidatedCoupon لو نجح، أو null + يضع _failure لو فشل.
  Future<ValidatedCoupon?> validate({
    required String code,
    required double subtotal,
    required String userId,
  }) async {
    _failure = null;
    final res = await _validateCoupon(ValidateCouponParams(
      code: code,
      subtotal: subtotal,
      userId: userId,
    ));
    return res.fold((f) {
      _failure = f;
      notifyListeners();
      return null;
    }, (v) => v);
  }

  /// يُسجّل الـ redemption (بعد placeOrder ناجح).
  Future<bool> redeem({
    required String couponId,
    required String userId,
    required String orderId,
    required double amount,
  }) async {
    final res = await _redeemCoupon(RedeemCouponParams(
      couponId: couponId,
      userId: userId,
      orderId: orderId,
      amount: amount,
    ));
    return res.fold((f) {
      _failure = f;
      notifyListeners();
      return false;
    }, (_) => true);
  }

  void clearFailure() {
    _failure = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
