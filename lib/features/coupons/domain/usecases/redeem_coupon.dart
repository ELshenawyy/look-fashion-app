import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:my_fashion_app/core/error/failures.dart';
import 'package:my_fashion_app/core/usecase/usecase.dart';
import 'package:my_fashion_app/features/coupons/domain/repositories/coupon_repository.dart';

class RedeemCouponParams extends Equatable {
  final String couponId;
  final String userId;
  final String orderId;
  final double amount;

  const RedeemCouponParams({
    required this.couponId,
    required this.userId,
    required this.orderId,
    required this.amount,
  });

  @override
  List<Object?> get props => [couponId, userId, orderId, amount];
}

class RedeemCoupon implements UseCase<void, RedeemCouponParams> {
  final CouponRepository repository;
  RedeemCoupon(this.repository);

  @override
  Future<Either<Failure, void>> call(RedeemCouponParams params) =>
      repository.redeemCoupon(
        couponId: params.couponId,
        userId: params.userId,
        orderId: params.orderId,
        amount: params.amount,
      );
}
