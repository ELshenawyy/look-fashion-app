import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:my_fashion_app/core/error/exceptions.dart';

/// مسؤول عن رفع صور المنتجات إلى Firebase Storage.
abstract class ProductStorageDataSource {
  /// يرجع URL الصورة بعد الرفع.
  Future<String> uploadProductImage(File imageFile);
}

class ProductStorageDataSourceImpl implements ProductStorageDataSource {
  final FirebaseStorage _storage;
  ProductStorageDataSourceImpl(this._storage);

  @override
  Future<String> uploadProductImage(File imageFile) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final ref = _storage.ref('products/prod_$timestamp.jpg');
      await ref.putFile(imageFile);
      return ref.getDownloadURL();
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? e.code);
    }
  }
}
