import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:my_fashion_app/core/error/failures.dart';
import 'package:my_fashion_app/features/favorites/domain/entities/favorite_entity.dart';
import 'package:my_fashion_app/features/favorites/domain/usecases/toggle_favorite.dart';
import 'package:my_fashion_app/features/favorites/domain/usecases/watch_favorite_ids.dart';
import 'package:my_fashion_app/features/favorites/domain/usecases/watch_favorites.dart';

/// Provider يدير state للـ Favorites — يستدعي use cases فقط، لا Firebase.
class FavoritesProvider extends ChangeNotifier {
  final ToggleFavorite _toggleFavorite;
  final WatchFavoriteIds _watchFavoriteIds;
  final WatchFavorites? _watchFavorites; // اختياري لشاشة favorites_screen

  FavoritesProvider({
    required ToggleFavorite toggleFavorite,
    required WatchFavoriteIds watchFavoriteIds,
    WatchFavorites? watchFavorites,
  })  : _toggleFavorite = toggleFavorite,
        _watchFavoriteIds = watchFavoriteIds,
        _watchFavorites = watchFavorites;

  StreamSubscription<List<String>>? _idsSub;
  StreamSubscription<List<FavoriteEntity>>? _detailsSub;

  Set<String> _favoriteIds = {};
  List<FavoriteEntity> _favorites = [];
  Failure? _failure;
  String? _activeUserId;
  bool _loadingDetails = false; // قائمة كاملة لشاشة المفضلة

  Set<String> get favoriteIds => _favoriteIds;
  List<FavoriteEntity> get favorites => _favorites;
  Failure? get failure => _failure;

  /// `true` قبل وصول أول snapshot — يُستخدمه favorites_screen لإظهار
  /// shimmer/loader بدل state فارغة وامضة.
  bool get isLoading => _loadingDetails;

  bool isFavorite(String productId) => _favoriteIds.contains(productId);

  /// يبدأ مراقبة المفضلات للمستخدم الحالي (يُستدعى من الشاشة عند initState).
  void startWatching(String userId) {
    if (_activeUserId == userId && _idsSub != null) return;
    _activeUserId = userId;

    _idsSub?.cancel();
    _idsSub = _watchFavoriteIds(userId).listen(
      (ids) {
        _favoriteIds = ids.toSet();
        _failure = null;
        notifyListeners();
      },
      onError: (e) {
        _failure = UnknownFailure(e.toString());
        notifyListeners();
      },
    );

    if (_watchFavorites != null) {
      _detailsSub?.cancel();
      _loadingDetails = true;
      notifyListeners();
      _detailsSub = _watchFavorites(userId).listen(
        (list) {
          _favorites = list;
          _loadingDetails = false;
          notifyListeners();
        },
        onError: (e) {
          _failure = UnknownFailure(e.toString());
          _loadingDetails = false;
          notifyListeners();
        },
      );
    }
  }

  Future<void> toggle({
    required String userId,
    required String productId,
    required String title,
    required String imageUrl,
    required double price,
  }) async {
    // optimistic update
    final wasFavorite = _favoriteIds.contains(productId);
    if (wasFavorite) {
      _favoriteIds.remove(productId);
    } else {
      _favoriteIds.add(productId);
    }
    notifyListeners();

    final result = await _toggleFavorite(ToggleFavoriteParams(
      userId: userId,
      productId: productId,
      title: title,
      imageUrl: imageUrl,
      price: price,
    ));

    result.fold((f) {
      // rollback عند الفشل
      if (wasFavorite) {
        _favoriteIds.add(productId);
      } else {
        _favoriteIds.remove(productId);
      }
      _failure = f;
      notifyListeners();
    }, (_) => null);
  }

  void clearFailure() {
    _failure = null;
    notifyListeners();
  }

  /// يُستدعى عند signOut — مسح كل بيانات المفضلة لمنع تسرّبها للحساب التالي.
  void reset() {
    _idsSub?.cancel();
    _detailsSub?.cancel();
    _idsSub = null;
    _detailsSub = null;
    _favoriteIds = {};
    _favorites = [];
    _failure = null;
    _activeUserId = null;
    _loadingDetails = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _idsSub?.cancel();
    _detailsSub?.cancel();
    super.dispose();
  }
}
