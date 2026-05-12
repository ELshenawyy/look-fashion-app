import 'package:dartz/dartz.dart';
import 'package:my_fashion_app/core/error/failures.dart';
import 'package:my_fashion_app/core/usecase/usecase.dart';
import 'package:my_fashion_app/features/auth/domain/repositories/auth_repository.dart';

class SendOtp implements UseCase<PhoneVerificationResult, String> {
  final AuthRepository repository;
  SendOtp(this.repository);

  @override
  Future<Either<Failure, PhoneVerificationResult>> call(String phoneNumber) =>
      repository.sendOtp(phoneNumber);
}
