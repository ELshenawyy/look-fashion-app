import 'package:equatable/equatable.dart';

/// كيان نقي يمثل مفضّلة مستخدم — لا اعتماد على Firebase.
class FavoriteEntity extends Equatable {
  final String productId;
  final String title;
  final String imageUrl;
  final double price;
  final DateTime addedAt;

  const FavoriteEntity({
    required this.productId,
    required this.title,
    required this.imageUrl,
    required this.price,
    required this.addedAt,
  });

  @override
  List<Object?> get props => [productId, title, imageUrl, price, addedAt];
}
