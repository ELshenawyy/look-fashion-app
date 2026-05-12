import 'package:my_fashion_app/features/favorites/domain/repositories/favorites_repository.dart';

/// use case "stream-based" — يرجع Stream مباشرة (ليس Either).
/// التعامل مع الأخطاء يتم في Provider عبر onError.
class WatchFavoriteIds {
  final FavoritesRepository repository;
  WatchFavoriteIds(this.repository);

  Stream<List<String>> call(String userId) =>
      repository.watchFavoriteIds(userId);
}
