import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:my_fashion_app/core/error/failures.dart';
import 'package:my_fashion_app/core/usecase/usecase.dart';
import 'package:my_fashion_app/features/profile/domain/repositories/profile_repository.dart';

class ChangePasswordParams extends Equatable {
  final String currentPassword;
  final String newPassword;
  const ChangePasswordParams(
      {required this.currentPassword, required this.newPassword});

  @override
  List<Object?> get props => [currentPassword, newPassword];
}

class ChangePassword implements UseCase<void, ChangePasswordParams> {
  final ProfileRepository repository;
  ChangePassword(this.repository);

  @override
  Future<Either<Failure, void>> call(ChangePasswordParams params) =>
      repository.changePassword(
        currentPassword: params.currentPassword,
        newPassword: params.newPassword,
      );
}
