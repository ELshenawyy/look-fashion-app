import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_fashion_app/core/error/exceptions.dart';
import 'package:my_fashion_app/features/products/domain/repositories/product_repository.dart';
import 'package:my_fashion_app/models/product.dart';

abstract class ProductRemoteDataSource {
  Future<ProductPage> fetchProducts({
    String? category,
    String sortField,
    bool descending,
    DocumentSnapshot? startAfter,
  });

  Stream<Map<String, int>> watchCategoryCounts();
  Stream<List<Product>> watchProducts({String? category});

  /// يجلب منتج واحد بـ docId. يرجع null إن لم يوجد.
  Future<Product?> getProductById(String docId);

  /// Stream للمنتجات اللي تمّ إضافتها بعد timestamp مُحدَّد.
  /// مُستخدَم لاكتشاف المنتجات الجديدة real-time بدون قراءة كل الكتالوج.
  Stream<List<Product>> watchNewProductsSince(
    DateTime since, {
    String? category,
  });

  /// إنشاء منتج جديد. يرجع docId الجديد.
  Future<String> addProduct(Map<String, dynamic> productData);

  /// تحديث منتج موجود.
  Future<void> updateProduct(
      String docId, Map<String, dynamic> productData);
}

class ProductRemoteDataSourceImpl implements ProductRemoteDataSource {
  static const int pageSize = 10;

  final FirebaseFirestore _db;
  ProductRemoteDataSourceImpl(this._db);

  @override
  /// جلب صفحة من المنتجات مع pagination حقيقي لجميع الحالات.
  /// يتطلب Composite Index في Firebase Console:
  ///   category ASC + createdAt DESC
  Future<ProductPage> fetchProducts({
    String? category,
    String sortField = 'createdAt',
    bool descending = true,
    DocumentSnapshot? startAfter,
  }) async {
    try {
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
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? e.code);
    }
  }

  @override
  Stream<Map<String, int>> watchCategoryCounts() {
    return _db.collection('products').snapshots().map((snapshot) {
      final counts = <String, int>{};
      for (final doc in snapshot.docs) {
        final cat = (doc.data()['category'] as String?) ?? '';
        if (cat.isNotEmpty) counts[cat] = (counts[cat] ?? 0) + 1;
      }
      return counts;
    });
  }

  @override
  Stream<List<Product>> watchProducts({String? category}) {
    Query<Map<String, dynamic>> query;
    if (category != null && category.isNotEmpty) {
      query = _db
          .collection('products')
          .where('category', isEqualTo: category)
          .orderBy('createdAt', descending: true);
    } else {
      query = _db
          .collection('products')
          .orderBy('createdAt', descending: true);
    }
    return query.snapshots().map((snap) => snap.docs.map(_fromDoc).toList());
  }

  Product _fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
      _buildProduct(doc.id, doc.data());

  /// Builder موحَّد من map → Product. مُستخدَم من كل من `_fromDoc`
  /// (للـ pagination/streams) و `getProductById` (للـ DocumentSnapshot).
  Product _buildProduct(String docId, Map<String, dynamic> d) {
    return Product.fromJson({
      'id': 0,
      'docId': docId,
      'price': d['price'] ?? 0.0,
      'title': d['title'] ?? '',
      // يدعم مستندات قديمة محفوظة بحقل `imageUrl` مفرد + الحقل الجديد `imageUrls`.
      'imageUrls': d['imageUrls'] ?? const <String>[],
      'imageUrl': d['imageUrl'] ?? '',
      'description': d['description'] ?? '',
      'gender': d['gender'] ?? '',
      'sizes': (d['sizes'] as List?)?.cast<String>() ?? const <String>[],
      'colors': (d['colors'] as List?)?.cast<String>() ?? const <String>[],
      'stockQuantity': d['stockQuantity'] ?? 0,
      'category': d['category'] ?? '',
      'state': d['state'] ?? '',
    });
  }

  @override
  Stream<List<Product>> watchNewProductsSince(
    DateTime since, {
    String? category,
  }) {
    Query<Map<String, dynamic>> q = _db
        .collection('products')
        .where('createdAt', isGreaterThan: Timestamp.fromDate(since));
    if (category != null && category.isNotEmpty) {
      q = q.where('category', isEqualTo: category);
    }
    // ⚠ مع where('createdAt', >) لازم orderBy على نفس الحقل
    q = q.orderBy('createdAt', descending: true);
    return q.snapshots().map(
          (snap) => snap.docs.map(_fromDoc).toList(),
        );
  }

  @override
  Future<Product?> getProductById(String docId) async {
    try {
      final snap = await _db.collection('products').doc(docId).get();
      final data = snap.data();
      if (!snap.exists || data == null) return null;
      return _buildProduct(snap.id, data);
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? e.code);
    }
  }

  @override
  Future<String> addProduct(Map<String, dynamic> productData) async {
    try {
      final ref = await _db.collection('products').add({
        ...productData,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return ref.id;
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? e.code);
    }
  }

  @override
  Future<void> updateProduct(
      String docId, Map<String, dynamic> productData) async {
    try {
      await _db.collection('products').doc(docId).update({
        ...productData,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? e.code);
    }
  }
}
