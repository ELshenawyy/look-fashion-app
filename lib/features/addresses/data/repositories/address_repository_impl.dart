import 'package:dartz/dartz.dart';
import 'package:my_fashion_app/core/error/exceptions.dart';
import 'package:my_fashion_app/core/error/failures.dart';
import 'package:my_fashion_app/core/network/network_info.dart';
import 'package:my_fashion_app/features/addresses/data/datasources/address_remote_datasource.dart';
import 'package:my_fashion_app/features/addresses/domain/entities/address_entity.dart';
import 'package:my_fashion_app/features/addresses/domain/repositories/address_repository.dart';

class AddressRepositoryImpl implements AddressRepository {
  final AddressRemoteDataSource remote;
  final NetworkInfo network;
  AddressRepositoryImpl({required this.remote, required this.network});

  @override
  Stream<List<AddressEntity>> watchAddresses(String userId) =>
      remote.watchAddresses(userId);

  @override
  Future<Either<Failure, void>> addAddress({
    required String userId,
    required String label,
    required String region,
    required String street,
    required String building,
  }) async {
    if (!await network.isConnected) return const Left(NetworkFailure());
    try {
      await remote.addAddress(
        userId: userId,
        label: label,
        region: region,
        street: street,
        building: building,
      );
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> deleteAddress({
    required String userId,
    required String addressId,
  }) async {
    if (!await network.isConnected) return const Left(NetworkFailure());
    try {
      await remote.deleteAddress(userId: userId, addressId: addressId);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }
}
