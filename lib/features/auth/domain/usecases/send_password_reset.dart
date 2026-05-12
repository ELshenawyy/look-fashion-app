import 'package:dartz/dartz.dart';
import 'package:my_fashion_app/core/error/failures.dart';
import 'package:my_fashion_app/core/usecase/usecase.dart';
import 'package:my_fashion_app/features/auth/domain/repositories/auth_repository.dart';

class SendPasswordReset implements UseCase<void, String> {
  final AuthRepository repository;
  SendPasswordReset(this.repository);

  @override
  Future<Either<Failure, void>> call(String email) =>
      repository.sendPasswordReset(email);
}
