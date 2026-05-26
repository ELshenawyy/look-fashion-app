import 'package:dartz/dartz.dart';
import 'package:my_fashion_app/core/error/failures.dart';
import 'package:my_fashion_app/core/usecase/usecase.dart';
import 'package:my_fashion_app/features/auth/domain/repositories/auth_repository.dart';

/// إعادة إرسال رابط تفعيل البريد للمستخدم الحالي.
class SendEmailVerification implements UseCase<void, NoParams> {
  final AuthRepository repository;
  SendEmailVerification(this.repository);

  @override
  Future<Either<Failure, void>> call(NoParams params) =>
      repository.sendEmailVerification();
}
