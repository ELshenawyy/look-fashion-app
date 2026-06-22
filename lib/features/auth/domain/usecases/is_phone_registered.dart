import 'package:dartz/dartz.dart';
import 'package:my_fashion_app/core/error/failures.dart';
import 'package:my_fashion_app/core/usecase/usecase.dart';
import 'package:my_fashion_app/features/auth/domain/repositories/auth_repository.dart';

/// يتحقق هل رقم الهاتف (E.164) مسجَّل في التطبيق قبل إرسال OTP.
class IsPhoneRegistered implements UseCase<bool, String> {
  final AuthRepository repository;
  IsPhoneRegistered(this.repository);

  @override
  Future<Either<Failure, bool>> call(String phoneNumber) =>
      repository.isPhoneRegistered(phoneNumber);
}
