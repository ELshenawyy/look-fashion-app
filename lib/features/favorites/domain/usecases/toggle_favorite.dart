import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:my_fashion_app/core/error/failures.dart';
import 'package:my_fashion_app/core/usecase/usecase.dart';
import 'package:my_fashion_app/features/favorites/domain/repositories/favorites_repository.dart';

class ToggleFavoriteParams extends Equatable {
  final String userId;
  final String productId;
  final String title;
  final String imageUrl;
  final double price;

  const ToggleFavoriteParams({
    required this.userId,
    required this.productId,
    required this.title,
    required this.imageUrl,
    required this.price,
  });

  @override
  List<Object?> get props => [userId, productId, title, imageUrl, price];
}

class ToggleFavorite implements UseCase<void, ToggleFavoriteParams> {
  final FavoritesRepository repository;
  ToggleFavorite(this.repository);

  @override
  Future<Either<Failure, void>> call(ToggleFavoriteParams params) {
    return repository.toggle(
      userId: params.userId,
      productId: params.productId,
      title: params.title,
      imageUrl: params.imageUrl,
      price: params.price,
    );
  }
}
