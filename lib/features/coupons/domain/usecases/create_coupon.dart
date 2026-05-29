import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:my_fashion_app/core/error/failures.dart';
import 'package:my_fashion_app/core/usecase/usecase.dart';
import 'package:my_fashion_app/features/coupons/domain/repositories/coupon_repository.dart';

class CreateCouponParams extends Equatable {
  final CouponInput input;
  final String adminUid;
  const CreateCouponParams({required this.input, required this.adminUid});

  @override
  List<Object?> get props => [
        input.code,
        input.type,
        input.value,
        input.expiresAt,
        adminUid,
      ];
}

class CreateCoupon implements UseCase<String, CreateCouponParams> {
  final CouponRepository repository;
  CreateCoupon(this.repository);

  @override
  Future<Either<Failure, String>> call(CreateCouponParams params) =>
      repository.createCoupon(
        input: params.input,
        adminUid: params.adminUid,
      );
}
