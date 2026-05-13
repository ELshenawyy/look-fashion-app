import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:my_fashion_app/core/error/failures.dart';
import 'package:my_fashion_app/core/usecase/usecase.dart';
import 'package:my_fashion_app/features/profile/domain/repositories/profile_repository.dart';

class UploadProfileImageParams extends Equatable {
  final String userId;
  final File imageFile;
  const UploadProfileImageParams(
      {required this.userId, required this.imageFile});

  @override
  List<Object?> get props => [userId, imageFile.path];
}

class UploadProfileImage
    implements UseCase<String, UploadProfileImageParams> {
  final ProfileRepository repository;
  UploadProfileImage(this.repository);

  @override
  Future<Either<Failure, String>> call(UploadProfileImageParams params) =>
      repository.uploadProfileImage(
        userId: params.userId,
        imageFile: params.imageFile,
      );
}
