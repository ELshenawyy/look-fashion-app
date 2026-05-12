import 'package:equatable/equatable.dart';

class AddressEntity extends Equatable {
  final String id;
  final String label;
  final String region;
  final String street;
  final String building;
  final DateTime? createdAt;

  const AddressEntity({
    required this.id,
    required this.label,
    required this.region,
    required this.street,
    this.building = '',
    this.createdAt,
  });

  @override
  List<Object?> get props => [id, label, region, street, building, createdAt];
}
