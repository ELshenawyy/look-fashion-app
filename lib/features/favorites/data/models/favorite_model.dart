import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_fashion_app/features/favorites/domain/entities/favorite_entity.dart';

/// Data layer model — يمتد الكيان ويضيف serialization لـ Firestore.
class FavoriteModel extends FavoriteEntity {
  const FavoriteModel({
    required super.productId,
    required super.title,
    required super.imageUrl,
    required super.price,
    required super.addedAt,
  });

  factory FavoriteModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return FavoriteModel(
      productId: doc.id,
      title: (data['title'] as String?) ?? '',
      imageUrl: (data['imageUrl'] as String?) ?? '',
      price: (data['price'] as num?)?.toDouble() ?? 0.0,
      // backward compat: حقل savedAt هو الاسم القديم في Firestore
      addedAt: (data['savedAt'] as Timestamp?)?.toDate() ??
          (data['addedAt'] as Timestamp?)?.toDate() ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'title': title,
        'imageUrl': imageUrl,
        'price': price,
        'savedAt': FieldValue.serverTimestamp(),
      };
}
