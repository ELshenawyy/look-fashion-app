import 'package:dartz/dartz.dart';
import 'package:my_fashion_app/core/error/failures.dart';
import 'package:my_fashion_app/core/usecase/usecase.dart';
import 'package:my_fashion_app/features/auth/domain/repositories/auth_repository.dart';

/// يرسل OTP للرقم الجديد قبل ربطه بالحساب (flow تعديل الهاتف من Profile).
class SendOtpForPhoneUpdate
    implements UseCase<PhoneVerificationResult, String> {
  final AuthRepository repository;
  SendOtpForPhoneUpdate(this.repository);

  @override
  Future<Either<Failure, PhoneVerificationResult>> call(
          String newPhoneNumber) =>
      repository.sendOtpForPhoneUpdate(newPhoneNumber);
}
