import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dartz/dartz.dart';
import 'package:my_fashion_app/core/error/exceptions.dart';
import 'package:my_fashion_app/core/error/failures.dart';
import 'package:my_fashion_app/core/network/network_info.dart';
import 'package:my_fashion_app/features/products/data/datasources/product_remote_datasource.dart';
import 'package:my_fashion_app/features/products/domain/repositories/product_repository.dart';
import 'package:my_fashion_app/models/product.dart';

class ProductRepositoryImpl implements ProductRepository {
  final ProductRemoteDataSource remote;
  final NetworkInfo network;

  ProductRepositoryImpl({required this.remote, required this.network});

  @override
  Future<Either<Failure, ProductPage>> fetchProducts({
    String? category,
    String sortField = 'createdAt',
    bool descending = true,
    DocumentSnapshot? startAfter,
  }) async {
    if (!await network.isConnected) return const Left(NetworkFailure());
    try {
      final page = await remote.fetchProducts(
        category: category,
        sortField: sortField,
        descending: descending,
        startAfter: startAfter,
      );
      return Right(page);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Stream<Map<String, int>> watchCategoryCounts() => remote.watchCategoryCounts();

  @override
  Stream<List<Product>> watchProducts({String? category}) =>
      remote.watchProducts(category: category);
}
