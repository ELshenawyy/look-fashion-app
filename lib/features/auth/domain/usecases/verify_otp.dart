import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:my_fashion_app/core/error/failures.dart';
import 'package:my_fashion_app/core/usecase/usecase.dart';
import 'package:my_fashion_app/features/auth/domain/entities/user_entity.dart';
import 'package:my_fashion_app/features/auth/domain/repositories/auth_repository.dart';

class VerifyOtpParams extends Equatable {
  final String verificationId;
  final String smsCode;
  final String? displayName; // signup-by-phone flow

  const VerifyOtpParams({
    required this.verificationId,
    required this.smsCode,
    this.displayName,
  });

  @override
  List<Object?> get props => [verificationId, smsCode, displayName];
}

class VerifyOtp implements UseCase<UserEntity, VerifyOtpParams> {
  final AuthRepository repository;
  VerifyOtp(this.repository);

  @override
  Future<Either<Failure, UserEntity>> call(VerifyOtpParams params) =>
      repository.verifyOtp(
        verificationId: params.verificationId,
        smsCode: params.smsCode,
        displayName: params.displayName,
      );
}
