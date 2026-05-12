import 'package:my_fashion_app/features/favorites/domain/entities/favorite_entity.dart';
import 'package:my_fashion_app/features/favorites/domain/repositories/favorites_repository.dart';

class WatchFavorites {
  final FavoritesRepository repository;
  WatchFavorites(this.repository);

  Stream<List<FavoriteEntity>> call(String userId) =>
      repository.watchFavorites(userId);
}
