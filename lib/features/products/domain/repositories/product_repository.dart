import 'dart:io';

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

/// بيانات منتج للـ Admin (إنشاء أو تعديل).
class ProductInput {
  final String title;
  final double price;
  final String description;
  final String category;
  final int stockQuantity;
  final List<String> sizes;
  final List<String> colors;
  final String gender;
  final String state;
  final List<String> existingImageUrls; // صور محفوظة سابقاً واحتُفظ بها
  final List<File> newImages; // صور جديدة تُرفع وتُضاف بعد الصور الموجودة

  const ProductInput({
    required this.title,
    required this.price,
    required this.description,
    required this.category,
    required this.stockQuantity,
    required this.sizes,
    required this.colors,
    required this.gender,
    required this.state,
    this.existingImageUrls = const [],
    this.newImages = const [],
  });
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

  /// يجلب منتج واحد بـ docId. يرجع Right(null) إذا غير موجود.
  Future<Either<Failure, Product?>> getProductById(String docId);

  /// Stream للمنتجات المُضافة بعد `since` (real-time hook للمنتجات الجديدة).
  Stream<List<Product>> watchNewProductsSince(
    DateTime since, {
    String? category,
  });

  /// إنشاء منتج جديد. ترفع الصورة إن وُجدت، ثم تحفظ المنتج.
  Future<Either<Failure, String>> addProduct(ProductInput input);

  /// تحديث منتج موجود. ترفع صورة جديدة إن وُجدت.
  Future<Either<Failure, void>> updateProduct({
    required String docId,
    required ProductInput input,
  });
}
