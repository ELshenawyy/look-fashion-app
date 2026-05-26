import 'package:dartz/dartz.dart';
import 'package:my_fashion_app/core/error/failures.dart';
import 'package:my_fashion_app/core/usecase/usecase.dart';
import 'package:my_fashion_app/features/auth/domain/entities/user_entity.dart';
import 'package:my_fashion_app/features/auth/domain/repositories/auth_repository.dart';

/// يُعيد تحميل المستخدم من Firebase ويرجع نسخة محدّثة (لـ emailVerified).
class ReloadUser implements UseCase<UserEntity?, NoParams> {
  final AuthRepository repository;
  ReloadUser(this.repository);

  @override
  Future<Either<Failure, UserEntity?>> call(NoParams params) =>
      repository.reloadCurrentUser();
}
