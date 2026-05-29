import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_fashion_app/core/error/exceptions.dart';
import 'package:my_fashion_app/features/coupons/data/models/coupon_model.dart';
import 'package:my_fashion_app/features/coupons/domain/entities/coupon_entity.dart';

abstract class CouponRemoteDataSource {
  Stream<List<CouponModel>> watchCoupons();

  /// يجلب كوبون بكوده (uppercase). يرجع null إذا غير موجود.
  Future<CouponModel?> findByCode(String code);

  /// يحسب كم مرة استخدم مستخدم محدد كوبوناً محدداً.
  Future<int> countRedemptionsForUser({
    required String couponId,
    required String userId,
  });

  /// يكتب redemption + يزيد usedCount في batch atomic.
  Future<void> redeemCoupon({
    required String couponId,
    required String userId,
    required String orderId,
    required double amount,
  });

  Future<String> createCoupon(Map<String, dynamic> data);
  Future<void> deleteCoupon(String couponId);
}

class CouponRemoteDataSourceImpl implements CouponRemoteDataSource {
  final FirebaseFirestore _db;
  CouponRemoteDataSourceImpl(this._db);

  CollectionReference<Map<String, dynamic>> get _couponsRef =>
      _db.collection('coupons');

  CollectionReference<Map<String, dynamic>> get _redemptionsRef =>
      _db.collection('coupon_redemptions');

  @override
  Stream<List<CouponModel>> watchCoupons() {
    return _couponsRef
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(CouponModel.fromFirestore).toList());
  }

  @override
  Future<CouponModel?> findByCode(String code) async {
    try {
      final snap = await _couponsRef
          .where('code', isEqualTo: code.toUpperCase().trim())
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return null;
      return CouponModel.fromFirestore(snap.docs.first);
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? e.code);
    }
  }

  @override
  Future<int> countRedemptionsForUser({
    required String couponId,
    required String userId,
  }) async {
    try {
      final snap = await _redemptionsRef
          .where('couponId', isEqualTo: couponId)
          .where('userId', isEqualTo: userId)
          .count()
          .get();
      return snap.count ?? 0;
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? e.code);
    }
  }

  @override
  Future<void> redeemCoupon({
    required String couponId,
    required String userId,
    required String orderId,
    required double amount,
  }) async {
    try {
      final batch = _db.batch();
      // 1) سجّل الـ redemption
      final redemptionRef = _redemptionsRef.doc();
      batch.set(redemptionRef, {
        'couponId': couponId,
        'userId': userId,
        'orderId': orderId,
        'amount': amount,
        'redeemedAt': FieldValue.serverTimestamp(),
      });
      // 2) زِد usedCount بـ atomic increment
      batch.update(_couponsRef.doc(couponId), {
        'usedCount': FieldValue.increment(1),
      });
      await batch.commit();
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? e.code);
    }
  }

  @override
  Future<String> createCoupon(Map<String, dynamic> data) async {
    try {
      // تأكّد من unique code قبل الإنشاء
      final existing = await findByCode(data['code'] as String);
      if (existing != null) {
        throw const ServerException('already-exists');
      }
      final ref = await _couponsRef.add({
        ...data,
        'createdAt': FieldValue.serverTimestamp(),
        'usedCount': 0,
      });
      return ref.id;
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? e.code);
    }
  }

  @override
  Future<void> deleteCoupon(String couponId) async {
    try {
      await _couponsRef.doc(couponId).delete();
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? e.code);
    }
  }
}

/// Helper لتحويل CouponEntity → CouponModel (للـ Stream casting).
extension CouponModelX on CouponEntity {
  CouponModel toModel() => CouponModel(
        id: id,
        code: code,
        type: type,
        value: value,
        minOrderValue: minOrderValue,
        maxDiscount: maxDiscount,
        expiresAt: expiresAt,
        usageLimit: usageLimit,
        usedCount: usedCount,
        perUserLimit: perUserLimit,
        active: active,
        createdAt: createdAt,
        createdBy: createdBy,
      );
}
