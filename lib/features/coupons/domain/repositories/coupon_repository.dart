import 'package:dartz/dartz.dart';
import 'package:my_fashion_app/core/error/failures.dart';
import 'package:my_fashion_app/features/coupons/domain/entities/coupon_entity.dart';

/// نتيجة validation كوبون — تحوي الكوبون + قيمة الخصم المحسوبة.
class ValidatedCoupon {
  final CouponEntity coupon;
  final double discount;
  const ValidatedCoupon({required this.coupon, required this.discount});
}

/// إدخال إنشاء كوبون (للأدمن).
class CouponInput {
  final String code;
  final CouponType type;
  final double value;
  final double minOrderValue;
  final double maxDiscount;
  final DateTime? expiresAt;
  final int usageLimit;
  final int perUserLimit;
  final bool active;

  const CouponInput({
    required this.code,
    required this.type,
    required this.value,
    this.minOrderValue = 0,
    this.maxDiscount = 0,
    this.expiresAt,
    this.usageLimit = 0,
    this.perUserLimit = 0,
    this.active = true,
  });
}

abstract class CouponRepository {
  /// Stream لكل الكوبونات (للأدمن).
  Stream<List<CouponEntity>> watchCoupons();

  /// يتحقّق من كوبون بكوده + مع subtotal للسلة + userId الحالي.
  /// يرجع [ValidatedCoupon] لو صالح، أو Failure مع سبب محدد.
  Future<Either<Failure, ValidatedCoupon>> validateCoupon({
    required String code,
    required double subtotal,
    required String userId,
  });

  /// يُسجّل استخدام الكوبون (بعد placeOrder ناجح).
  /// يزيد usedCount + يكتب redemption document.
  Future<Either<Failure, void>> redeemCoupon({
    required String couponId,
    required String userId,
    required String orderId,
    required double amount,
  });

  /// إنشاء كوبون جديد (للأدمن).
  Future<Either<Failure, String>> createCoupon({
    required CouponInput input,
    required String adminUid,
  });

  /// حذف كوبون (للأدمن).
  Future<Either<Failure, void>> deleteCoupon(String couponId);
}
