import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:my_fashion_app/core/error/exceptions.dart';
import 'package:my_fashion_app/core/error/failures.dart';
import 'package:my_fashion_app/core/network/network_info.dart';
import 'package:my_fashion_app/features/profile/data/datasources/profile_remote_datasource.dart';
import 'package:my_fashion_app/features/profile/domain/repositories/profile_repository.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  final ProfileRemoteDataSource remote;
  final NetworkInfo network;

  ProfileRepositoryImpl({required this.remote, required this.network});

  @override
  Future<Either<Failure, String>> uploadProfileImage({
    required String userId,
    required File imageFile,
  }) async {
    if (!await network.isConnected) return const Left(NetworkFailure());
    try {
      final url = await remote.uploadProfileImage(
        userId: userId,
        imageFile: imageFile,
      );
      return Right(url);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> updateDisplayName({
    required String userId,
    required String newName,
  }) async {
    if (!await network.isConnected) return const Left(NetworkFailure());
    try {
      await remote.updateDisplayName(userId: userId, newName: newName);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (!await network.isConnected) return const Left(NetworkFailure());
    try {
      await remote.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      return const Right(null);
    } on FirebaseAuthException catch (e) {
      return Left(AuthFailure(_mapAuthError(e.code)));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  String _mapAuthError(String code) {
    switch (code) {
      case 'wrong-password':
        return 'كلمة المرور الحالية غير صحيحة.';
      case 'weak-password':
        return 'كلمة المرور الجديدة ضعيفة جداً.';
      case 'requires-recent-login':
        return 'يرجى تسجيل الخروج ثم الدخول مجدداً قبل تغيير كلمة المرور.';
      case 'invalid-credential':
        return 'كلمة المرور الحالية غير صحيحة.';
      default:
        return 'فشل تغيير كلمة المرور ($code)';
    }
  }
}
