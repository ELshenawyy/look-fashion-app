import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_fashion_app/models/product.dart';

class ProductService {
  Stream<List<Product>> getProductsStream() {
    return FirebaseFirestore.instance.collection('products').snapshots().map(
      (snapshot) => snapshot.docs.map((doc) {
        final data = doc.data();
        return Product.fromJson({
          'id': int.tryParse(doc.id) ?? 0,
          'price': data['price'] ?? 0.0,
          'title': data['title'] ?? '',
          'imageUrl': data['imageUrl'] ?? '',
          'description': data['description'] ?? '',
          'gender': data['gender'] ?? '',
        });
      }).toList(),
    );
  }
}
