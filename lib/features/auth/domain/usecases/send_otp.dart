import 'package:dartz/dartz.dart';
import 'package:my_fashion_app/core/error/failures.dart';
import 'package:my_fashion_app/core/usecase/usecase.dart';
import 'package:my_fashion_app/features/auth/domain/repositories/auth_repository.dart';

class SendOtpParams {
  final String phoneNumber;
  final OtpIntent intent;
  const SendOtpParams(this.phoneNumber, {this.intent = OtpIntent.login});
}

class SendOtp implements UseCase<PhoneVerificationResult, SendOtpParams> {
  final AuthRepository repository;
  SendOtp(this.repository);

  @override
  Future<Either<Failure, PhoneVerificationResult>> call(SendOtpParams params) =>
      repository.sendOtp(params.phoneNumber, intent: params.intent);
}
