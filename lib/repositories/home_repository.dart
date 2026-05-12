import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_fashion_app/models/product.dart';

/// نتيجة صفحة واحدة من المنتجات — Dart 2 متوافق (لا Record types)
class ProductPage {
  final List<Product> products;
  final DocumentSnapshot? lastDoc; // cursor للصفحة التالية

  const ProductPage({required this.products, this.lastDoc});
}

/// مسؤولية واحدة: جلب البيانات من Firestore — لا state، لا UI
class HomeRepository {
  static const int pageSize = 10;

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// جلب صفحة من المنتجات مع pagination حقيقي لجميع الحالات.
  ///
  /// يتطلب Composite Indexes في Firebase Console:
  ///   - category ASC + createdAt DESC
  ///   - category ASC + stockQuantity ASC
  Future<ProductPage> fetchProducts({
    String? category,
    String sortField = 'createdAt',
    bool descending = true,
    DocumentSnapshot? startAfter,
  }) async {
    Query<Map<String, dynamic>> q = _db.collection('products');

    if (category != null && category.isNotEmpty) {
      q = q.where('category', isEqualTo: category);
    }

    q = q.orderBy(sortField, descending: descending).limit(pageSize);

    if (startAfter != null) {
      q = q.startAfterDocument(startAfter);
    }

    final snap = await q.get();
    final products = snap.docs.map(_fromDoc).toList();
    final lastDoc = snap.docs.isNotEmpty ? snap.docs.last : null;

    return ProductPage(products: products, lastDoc: lastDoc);
  }

  Product _fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    return Product.fromJson({
      'id': 0,
      'docId': doc.id,
      'price': d['price'] ?? 0.0,
      'title': d['title'] ?? '',
      'imageUrl': d['imageUrl'] ?? '',
      'description': d['description'] ?? '',
      'gender': d['gender'] ?? '',
      'sizes': d['sizes'] ?? const <dynamic>[],
      'colors': d['colors'] ?? const <dynamic>[],
      'stockQuantity': d['stockQuantity'] ?? 0,
      'category': d['category'] ?? '',
      'state': d['state'] ?? '',
    });
  }
}
