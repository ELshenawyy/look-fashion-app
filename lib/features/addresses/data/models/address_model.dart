import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_fashion_app/features/addresses/domain/entities/address_entity.dart';

class AddressModel extends AddressEntity {
  const AddressModel({
    required super.id,
    required super.label,
    required super.region,
    required super.street,
    super.building,
    super.createdAt,
  });

  factory AddressModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const <String, dynamic>{};
    return AddressModel(
      id: doc.id,
      label: (d['label'] as String?) ?? '',
      region: (d['region'] as String?) ?? '',
      street: (d['street'] as String?) ?? '',
      building: (d['building'] as String?) ?? '',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  static Map<String, dynamic> newDoc({
    required String label,
    required String region,
    required String street,
    required String building,
  }) =>
      {
        'label': label,
        'region': region,
        'street': street,
        'building': building,
        'createdAt': FieldValue.serverTimestamp(),
      };
}
