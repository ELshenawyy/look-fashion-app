import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:my_fashion_app/core/error/failures.dart';
import 'package:my_fashion_app/core/usecase/usecase.dart';
import 'package:my_fashion_app/features/profile/domain/repositories/profile_repository.dart';

class UpdateDisplayNameParams extends Equatable {
  final String userId;
  final String newName;
  const UpdateDisplayNameParams({required this.userId, required this.newName});

  @override
  List<Object?> get props => [userId, newName];
}

class UpdateDisplayName implements UseCase<void, UpdateDisplayNameParams> {
  final ProfileRepository repository;
  UpdateDisplayName(this.repository);

  @override
  Future<Either<Failure, void>> call(UpdateDisplayNameParams params) =>
      repository.updateDisplayName(
        userId: params.userId,
        newName: params.newName,
      );
}
