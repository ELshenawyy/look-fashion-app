import 'package:equatable/equatable.dart';

/// نوع الكوبون: نسبة مئوية أو خصم ثابت.
enum CouponType {
  percent, // نسبة مئوية (مثلاً 20%)
  fixed, // مبلغ ثابت (مثلاً 500 ج.س)
}

extension CouponTypeX on CouponType {
  String get firestoreValue =>
      this == CouponType.percent ? 'percent' : 'fixed';

  static CouponType fromString(String? s) =>
      s == 'fixed' ? CouponType.fixed : CouponType.percent;
}

/// كيان الكوبون — لا اعتماد على Firebase.
class CouponEntity extends Equatable {
  final String id;
  final String code; // unique, uppercase (WELCOME20)
  final CouponType type;
  final double value; // النسبة أو المبلغ
  final double minOrderValue; // أقل قيمة سلة للتطبيق (0 = بلا حد)
  final double maxDiscount; // حد أقصى للخصم — للنوع percent (0 = بلا حد)
  final DateTime? expiresAt; // null = بلا انتهاء
  final int usageLimit; // العدد الكلي للاستخدامات (0 = بلا حد)
  final int usedCount; // عدد الاستخدامات الحالي
  final int perUserLimit; // أقصى استخدامات لكل مستخدم (0 = بلا حد)
  final bool active;
  final DateTime? createdAt;
  final String createdBy;

  const CouponEntity({
    required this.id,
    required this.code,
    required this.type,
    required this.value,
    this.minOrderValue = 0,
    this.maxDiscount = 0,
    this.expiresAt,
    this.usageLimit = 0,
    this.usedCount = 0,
    this.perUserLimit = 0,
    this.active = true,
    this.createdAt,
    this.createdBy = '',
  });

  /// يحسب قيمة الخصم بناءً على subtotal.
  /// لا يفحص الـ validation — استخدم ValidateCoupon لذلك.
  double calculateDiscount(double subtotal) {
    final raw = type == CouponType.percent
        ? subtotal * (value / 100)
        : value;
    final capped =
        (maxDiscount > 0 && raw > maxDiscount) ? maxDiscount : raw;
    return capped > subtotal ? subtotal : capped; // لا يتجاوز السلة
  }

  bool get isExpired =>
      expiresAt != null && expiresAt!.isBefore(DateTime.now());

  bool get hasReachedUsageLimit =>
      usageLimit > 0 && usedCount >= usageLimit;

  @override
  List<Object?> get props => [
        id,
        code,
        type,
        value,
        minOrderValue,
        maxDiscount,
        expiresAt,
        usageLimit,
        usedCount,
        perUserLimit,
        active,
        createdAt,
        createdBy,
      ];
}
