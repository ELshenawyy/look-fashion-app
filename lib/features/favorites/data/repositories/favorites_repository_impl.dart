import 'package:dartz/dartz.dart';
import 'package:my_fashion_app/core/error/exceptions.dart';
import 'package:my_fashion_app/core/error/failures.dart';
import 'package:my_fashion_app/core/network/network_info.dart';
import 'package:my_fashion_app/features/favorites/data/datasources/favorites_remote_datasource.dart';
import 'package:my_fashion_app/features/favorites/data/models/favorite_model.dart';
import 'package:my_fashion_app/features/favorites/domain/entities/favorite_entity.dart';
import 'package:my_fashion_app/features/favorites/domain/repositories/favorites_repository.dart';

class FavoritesRepositoryImpl implements FavoritesRepository {
  final FavoritesRemoteDataSource remote;
  final NetworkInfo network;

  FavoritesRepositoryImpl({required this.remote, required this.network});

  @override
  Stream<List<String>> watchFavoriteIds(String userId) =>
      remote.watchFavoriteIds(userId);

  @override
  Stream<List<FavoriteEntity>> watchFavorites(String userId) =>
      remote.watchFavorites(userId);

  @override
  Future<Either<Failure, void>> toggle({
    required String userId,
    required String productId,
    required String title,
    required String imageUrl,
    required double price,
  }) async {
    if (!await network.isConnected) {
      return const Left(NetworkFailure());
    }
    try {
      await remote.toggle(
        userId: userId,
        productId: productId,
        model: FavoriteModel(
          productId: productId,
          title: title,
          imageUrl: imageUrl,
          price: price,
          addedAt: DateTime.now(),
        ),
      );
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }
}
