import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_fashion_app/models/product.dart';

class ProductService {
  /// يجلب stream للمنتجات مع فرز من جهة Firestore (لا فرز على العميل).
  /// عند التصفية بالفئة يحتاج Composite Index:
  ///   category ASC + createdAt DESC  (أنشئه من Firebase Console)
  Stream<List<Product>> getProductsStream({String? category}) {
    Query<Map<String, dynamic>> query;

    if (category != null && category.isNotEmpty) {
      query = FirebaseFirestore.instance
          .collection('products')
          .where('category', isEqualTo: category)
          .orderBy('createdAt', descending: true);
    } else {
      query = FirebaseFirestore.instance
          .collection('products')
          .orderBy('createdAt', descending: true);
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
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
          'state': data['state'] ?? '',
        });
      }).toList();
    });
  }
}
