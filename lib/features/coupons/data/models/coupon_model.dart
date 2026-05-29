import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_fashion_app/features/coupons/domain/entities/coupon_entity.dart';

class CouponModel extends CouponEntity {
  const CouponModel({
    required super.id,
    required super.code,
    required super.type,
    required super.value,
    super.minOrderValue,
    super.maxDiscount,
    super.expiresAt,
    super.usageLimit,
    super.usedCount,
    super.perUserLimit,
    super.active,
    super.createdAt,
    super.createdBy,
  });

  factory CouponModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? <String, dynamic>{};
    return CouponModel(
      id: doc.id,
      code: (d['code'] as String? ?? '').toUpperCase(),
      type: CouponTypeX.fromString(d['type'] as String?),
      value: (d['value'] as num?)?.toDouble() ?? 0,
      minOrderValue: (d['minOrderValue'] as num?)?.toDouble() ?? 0,
      maxDiscount: (d['maxDiscount'] as num?)?.toDouble() ?? 0,
      expiresAt: (d['expiresAt'] as Timestamp?)?.toDate(),
      usageLimit: (d['usageLimit'] as num?)?.toInt() ?? 0,
      usedCount: (d['usedCount'] as num?)?.toInt() ?? 0,
      perUserLimit: (d['perUserLimit'] as num?)?.toInt() ?? 0,
      active: d['active'] as bool? ?? true,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
      createdBy: d['createdBy'] as String? ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'code': code.toUpperCase(),
      'type': type.firestoreValue,
      'value': value,
      'minOrderValue': minOrderValue,
      'maxDiscount': maxDiscount,
      if (expiresAt != null) 'expiresAt': Timestamp.fromDate(expiresAt!),
      'usageLimit': usageLimit,
      'usedCount': usedCount,
      'perUserLimit': perUserLimit,
      'active': active,
      'createdBy': createdBy,
      // createdAt يُضاف عند الإنشاء بـ serverTimestamp
    };
  }
}
