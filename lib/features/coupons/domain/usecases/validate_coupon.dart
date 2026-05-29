import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:my_fashion_app/core/error/failures.dart';
import 'package:my_fashion_app/core/usecase/usecase.dart';
import 'package:my_fashion_app/features/coupons/domain/repositories/coupon_repository.dart';

class ValidateCouponParams extends Equatable {
  final String code;
  final double subtotal;
  final String userId;

  const ValidateCouponParams({
    required this.code,
    required this.subtotal,
    required this.userId,
  });

  @override
  List<Object?> get props => [code, subtotal, userId];
}

class ValidateCoupon implements UseCase<ValidatedCoupon, ValidateCouponParams> {
  final CouponRepository repository;
  ValidateCoupon(this.repository);

  @override
  Future<Either<Failure, ValidatedCoupon>> call(
          ValidateCouponParams params) =>
      repository.validateCoupon(
        code: params.code,
        subtotal: params.subtotal,
        userId: params.userId,
      );
}
