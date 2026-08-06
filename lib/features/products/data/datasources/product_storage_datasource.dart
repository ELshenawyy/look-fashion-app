import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:my_fashion_app/core/error/exceptions.dart';

/// مسؤول عن رفع صور المنتجات إلى Firebase Storage.
abstract class ProductStorageDataSource {
  /// يرجع URL الصورة بعد الرفع.
  Future<String> uploadProductImage(File imageFile);

  /// يرفع مجموعة صور بالتوازي ويرجع روابطها بنفس ترتيب الإدخال.
  Future<List<String>> uploadProductImages(List<File> imageFiles);
}

class ProductStorageDataSourceImpl implements ProductStorageDataSource {
  final FirebaseStorage _storage;
  ProductStorageDataSourceImpl(this._storage);

  @override
  Future<String> uploadProductImage(File imageFile) => _upload(imageFile, 0);

  @override
  Future<List<String>> uploadProductImages(List<File> imageFiles) {
    return Future.wait([
      for (var i = 0; i < imageFiles.length; i++) _upload(imageFiles[i], i),
    ]);
  }

  /// يرفع ملفاً واحداً باسم فريد (timestamp بالميكروثانية + index) لتفادي
  /// تعارض الأسماء عند رفع عدة صور في نفس اللحظة عبر Future.wait.
  Future<String> _upload(File imageFile, int index) async {
    try {
      final timestamp = DateTime.now().microsecondsSinceEpoch.toString();
      final ref = _storage.ref('products/prod_${timestamp}_$index.jpg');
      await ref.putFile(imageFile);
      return ref.getDownloadURL();
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? e.code);
    }
  }
}
