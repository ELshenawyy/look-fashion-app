import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:my_fashion_app/core/error/failures.dart';
import 'package:my_fashion_app/core/usecase/usecase.dart';
import 'package:my_fashion_app/features/coupons/domain/repositories/coupon_repository.dart';

class DeleteCouponParams extends Equatable {
  final String couponId;
  const DeleteCouponParams(this.couponId);

  @override
  List<Object?> get props => [couponId];
}

class DeleteCoupon implements UseCase<void, DeleteCouponParams> {
  final CouponRepository repository;
  DeleteCoupon(this.repository);

  @override
  Future<Either<Failure, void>> call(DeleteCouponParams params) =>
      repository.deleteCoupon(params.couponId);
}
