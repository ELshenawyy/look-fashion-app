import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dartz/dartz.dart';
import 'package:my_fashion_app/core/error/failures.dart';
import 'package:my_fashion_app/models/product.dart';

/// نتيجة صفحة من المنتجات مع cursor للـ pagination.
class ProductPage {
  final List<Product> products;
  final DocumentSnapshot? lastDoc;

  const ProductPage({required this.products, this.lastDoc});
}

abstract class ProductRepository {
  /// جلب صفحة من المنتجات مع pagination.
  Future<Either<Failure, ProductPage>> fetchProducts({
    String? category,
    String sortField,
    bool descending,
    DocumentSnapshot? startAfter,
  });

  /// Stream لعدد المنتجات في كل فئة.
  Stream<Map<String, int>> watchCategoryCounts();

  /// Stream لكل المنتجات (مع فلتر فئة اختياري) — للاستخدام في شاشات الفئات.
  Stream<List<Product>> watchProducts({String? category});
}
