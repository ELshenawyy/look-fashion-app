import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:my_fashion_app/core/error/failures.dart';
import 'package:my_fashion_app/core/usecase/usecase.dart';
import 'package:my_fashion_app/features/auth/domain/repositories/auth_repository.dart';

class UpdatePhoneNumberParams extends Equatable {
  final String verificationId;
  final String smsCode;
  const UpdatePhoneNumberParams({
    required this.verificationId,
    required this.smsCode,
  });

  @override
  List<Object?> get props => [verificationId, smsCode];
}

/// يحدّث رقم هاتف المستخدم الحالي بعد التحقّق من OTP الجديد.
class UpdatePhoneNumber implements UseCase<void, UpdatePhoneNumberParams> {
  final AuthRepository repository;
  UpdatePhoneNumber(this.repository);

  @override
  Future<Either<Failure, void>> call(UpdatePhoneNumberParams params) =>
      repository.updatePhoneNumber(
        verificationId: params.verificationId,
        smsCode: params.smsCode,
      );
}
