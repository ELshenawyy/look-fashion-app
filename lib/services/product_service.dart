import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_fashion_app/models/product.dart';

class ProductService {
  Stream<List<Product>> getProductsStream({String? category}) {
    Query<Map<String, dynamic>> query =
        FirebaseFirestore.instance.collection('products');

    if (category != null && category.isNotEmpty) {
      query = query.where('category', isEqualTo: category);
    }

    return query.snapshots().map(
      (snapshot) {
        final docs = snapshot.docs.toList()
          ..sort(
            (a, b) =>
                _resolveSortDate(b.data()).compareTo(_resolveSortDate(a.data())),
          );

        return docs.map((doc) {
          final data = doc.data();
          return Product.fromJson({
            'id': int.tryParse(doc.id) ?? 0,
            'docId': doc.id,
            'price': data['price'] ?? 0.0,
            'title': data['title'] ?? '',
            'imageUrl': data['imageUrl'] ?? '',
            'description': data['description'] ?? '',
            'gender': data['gender'] ?? '',
            'sizes': data['sizes'] ?? const [],
            'colors': data['colors'] ?? const [],
            'stockQuantity': data['stockQuantity'] ?? 0,
            'category': data['category'] ?? '',
          });
        }).toList();
      },
    );
  }

  DateTime _resolveSortDate(Map<String, dynamic> data) {
    return _toDateTime(data['createdAt']) ??
        _toDateTime(data['updatedAt']) ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  DateTime? _toDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
