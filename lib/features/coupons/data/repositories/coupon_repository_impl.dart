import 'package:dartz/dartz.dart';
import 'package:my_fashion_app/core/error/exceptions.dart';
import 'package:my_fashion_app/core/error/failures.dart';
import 'package:my_fashion_app/core/network/network_info.dart';
import 'package:my_fashion_app/features/coupons/data/datasources/coupon_remote_datasource.dart';
import 'package:my_fashion_app/features/coupons/data/models/coupon_model.dart';
import 'package:my_fashion_app/features/coupons/domain/entities/coupon_entity.dart';
import 'package:my_fashion_app/features/coupons/domain/repositories/coupon_repository.dart';

class CouponRepositoryImpl implements CouponRepository {
  final CouponRemoteDataSource remote;
  final NetworkInfo network;

  CouponRepositoryImpl({required this.remote, required this.network});

  @override
  Stream<List<CouponEntity>> watchCoupons() => remote.watchCoupons();

  @override
  Future<Either<Failure, ValidatedCoupon>> validateCoupon({
    required String code,
    required double subtotal,
    required String userId,
  }) async {
    if (!await network.isConnected) return const Left(NetworkFailure());
    try {
      final coupon = await remote.findByCode(code);
      if (coupon == null) {
        return const Left(ServerFailure('كوبون غير صحيح'));
      }
      if (!coupon.active) {
        return const Left(ServerFailure('هذا الكوبون معطّل حالياً'));
      }
      if (coupon.isExpired) {
        return const Left(ServerFailure('انتهت صلاحية هذا الكوبون'));
      }
      if (coupon.hasReachedUsageLimit) {
        return const Left(
            ServerFailure('تم استنفاد عدد الاستخدامات لهذا الكوبون'));
      }
      if (subtotal < coupon.minOrderValue) {
        return Left(ServerFailure(
            'الحد الأدنى للطلب ${coupon.minOrderValue.toStringAsFixed(0)} ج.س'));
      }
      // فحص perUserLimit (لو محدّد)
      if (coupon.perUserLimit > 0) {
        final used = await remote.countRedemptionsForUser(
          couponId: coupon.id,
          userId: userId,
        );
        if (used >= coupon.perUserLimit) {
          return const Left(
              ServerFailure('استخدمت هذا الكوبون من قبل'));
        }
      }
      final discount = coupon.calculateDiscount(subtotal);
      if (discount <= 0) {
        return const Left(ServerFailure('قيمة الخصم غير صالحة'));
      }
      return Right(ValidatedCoupon(coupon: coupon, discount: discount));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> redeemCoupon({
    required String couponId,
    required String userId,
    required String orderId,
    required double amount,
  }) async {
    if (!await network.isConnected) return const Left(NetworkFailure());
    try {
      await remote.redeemCoupon(
        couponId: couponId,
        userId: userId,
        orderId: orderId,
        amount: amount,
      );
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, String>> createCoupon({
    required CouponInput input,
    required String adminUid,
  }) async {
    if (!await network.isConnected) return const Left(NetworkFailure());
    try {
      // Validation أساسية
      if (input.code.trim().isEmpty) {
        return const Left(ServerFailure('الكوبون لا يمكن أن يكون فارغاً'));
      }
      if (input.value <= 0) {
        return const Left(ServerFailure('قيمة الخصم يجب أن تكون أكبر من 0'));
      }
      if (input.type == CouponType.percent && input.value > 100) {
        return const Left(
            ServerFailure('النسبة المئوية لا تتجاوز 100%'));
      }

      final model = CouponModel(
        id: '',
        code: input.code.toUpperCase().trim(),
        type: input.type,
        value: input.value,
        minOrderValue: input.minOrderValue,
        maxDiscount: input.maxDiscount,
        expiresAt: input.expiresAt,
        usageLimit: input.usageLimit,
        perUserLimit: input.perUserLimit,
        active: input.active,
        createdBy: adminUid,
      );
      final id = await remote.createCoupon(model.toFirestore());
      return Right(id);
    } on ServerException catch (e) {
      if (e.message == 'already-exists') {
        return const Left(ServerFailure('هذا الكوبون موجود بالفعل'));
      }
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> deleteCoupon(String couponId) async {
    if (!await network.isConnected) return const Left(NetworkFailure());
    try {
      await remote.deleteCoupon(couponId);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }
}
