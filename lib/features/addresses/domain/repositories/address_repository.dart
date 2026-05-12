import 'package:dartz/dartz.dart';
import 'package:my_fashion_app/core/error/failures.dart';
import 'package:my_fashion_app/features/addresses/domain/entities/address_entity.dart';

abstract class AddressRepository {
  Stream<List<AddressEntity>> watchAddresses(String userId);

  Future<Either<Failure, void>> addAddress({
    required String userId,
    required String label,
    required String region,
    required String street,
    required String building,
  });

  Future<Either<Failure, void>> deleteAddress({
    required String userId,
    required String addressId,
  });
}
