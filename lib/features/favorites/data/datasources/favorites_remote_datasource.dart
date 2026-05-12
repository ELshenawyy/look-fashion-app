import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_fashion_app/core/error/exceptions.dart';
import 'package:my_fashion_app/features/favorites/data/models/favorite_model.dart';

abstract class FavoritesRemoteDataSource {
  Stream<List<String>> watchFavoriteIds(String userId);
  Stream<List<FavoriteModel>> watchFavorites(String userId);

  /// يطلق `ServerException` عند الفشل
  Future<void> toggle({
    required String userId,
    required String productId,
    required FavoriteModel model,
  });
}

class FavoritesRemoteDataSourceImpl implements FavoritesRemoteDataSource {
  final FirebaseFirestore _db;
  FavoritesRemoteDataSourceImpl(this._db);

  CollectionReference<Map<String, dynamic>> _favCol(String userId) =>
      _db.collection('users').doc(userId).collection('favorites');

  @override
  Stream<List<String>> watchFavoriteIds(String userId) {
    return _favCol(userId).snapshots().map(
          (snap) => snap.docs.map((d) => d.id).toList(),
        );
  }

  @override
  Stream<List<FavoriteModel>> watchFavorites(String userId) {
    return _favCol(userId)
        .orderBy('savedAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => FavoriteModel.fromFirestore(d)).toList());
  }

  @override
  Future<void> toggle({
    required String userId,
    required String productId,
    required FavoriteModel model,
  }) async {
    try {
      final docRef = _favCol(userId).doc(productId);
      final exists = (await docRef.get()).exists;
      if (exists) {
        await docRef.delete();
      } else {
        await docRef.set(model.toFirestore());
      }
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? e.code);
    }
  }
}
