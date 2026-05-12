import 'package:dartz/dartz.dart';
import 'package:my_fashion_app/core/error/failures.dart';
import 'package:my_fashion_app/features/favorites/domain/entities/favorite_entity.dart';

abstract class FavoritesRepository {
  /// Stream لـ IDs المنتجات المفضّلة (للتحقق السريع: هل المنتج مفضّل؟)
  Stream<List<String>> watchFavoriteIds(String userId);

  /// Stream لتفاصيل المفضّلات (للعرض في favorites_screen)
  Stream<List<FavoriteEntity>> watchFavorites(String userId);

  /// إضافة/إزالة المنتج من المفضلة (toggle)
  Future<Either<Failure, void>> toggle({
    required String userId,
    required String productId,
    required String title,
    required String imageUrl,
    required double price,
  });
}
