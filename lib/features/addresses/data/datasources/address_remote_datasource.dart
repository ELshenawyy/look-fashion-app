import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_fashion_app/core/error/exceptions.dart';
import 'package:my_fashion_app/features/addresses/data/models/address_model.dart';

abstract class AddressRemoteDataSource {
  Stream<List<AddressModel>> watchAddresses(String userId);

  Future<void> addAddress({
    required String userId,
    required String label,
    required String region,
    required String street,
    required String building,
  });

  Future<void> deleteAddress({
    required String userId,
    required String addressId,
  });
}

class AddressRemoteDataSourceImpl implements AddressRemoteDataSource {
  final FirebaseFirestore _db;
  AddressRemoteDataSourceImpl(this._db);

  CollectionReference<Map<String, dynamic>> _col(String userId) =>
      _db.collection('users').doc(userId).collection('addresses');

  @override
  Stream<List<AddressModel>> watchAddresses(String userId) {
    return _col(userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => AddressModel.fromFirestore(d)).toList());
  }

  @override
  Future<void> addAddress({
    required String userId,
    required String label,
    required String region,
    required String street,
    required String building,
  }) async {
    try {
      await _col(userId).add(AddressModel.newDoc(
        label: label,
        region: region,
        street: street,
        building: building,
      ));
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? e.code);
    }
  }

  @override
  Future<void> deleteAddress({
    required String userId,
    required String addressId,
  }) async {
    try {
      await _col(userId).doc(addressId).delete();
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? e.code);
    }
  }
}
