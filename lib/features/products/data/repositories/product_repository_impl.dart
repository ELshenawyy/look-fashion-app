import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dartz/dartz.dart';
import 'package:my_fashion_app/core/error/exceptions.dart';
import 'package:my_fashion_app/core/error/failures.dart';
import 'package:my_fashion_app/core/network/network_info.dart';
import 'package:my_fashion_app/features/products/data/datasources/product_remote_datasource.dart';
import 'package:my_fashion_app/features/products/data/datasources/product_storage_datasource.dart';
import 'package:my_fashion_app/features/products/domain/repositories/product_repository.dart';
import 'package:my_fashion_app/models/product.dart';

class ProductRepositoryImpl implements ProductRepository {
  final ProductRemoteDataSource remote;
  final ProductStorageDataSource storage;
  final NetworkInfo network;

  ProductRepositoryImpl({
    required this.remote,
    required this.storage,
    required this.network,
  });

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

  @override
  Stream<List<Product>> watchNewProductsSince(
    DateTime since, {
    String? category,
  }) =>
      remote.watchNewProductsSince(since, category: category);

  @override
  Future<Either<Failure, Product?>> getProductById(String docId) async {
    if (!await network.isConnected) return const Left(NetworkFailure());
    try {
      final product = await remote.getProductById(docId);
      return Right(product);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, String>> addProduct(ProductInput input) async {
    if (!await network.isConnected) return const Left(NetworkFailure());
    try {
      String url = input.imageUrl;
      if (input.newImage != null) {
        url = await storage.uploadProductImage(input.newImage!);
      }
      final id = await remote.addProduct(_buildMap(input, url));
      return Right(id);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> updateProduct({
    required String docId,
    required ProductInput input,
  }) async {
    if (!await network.isConnected) return const Left(NetworkFailure());
    try {
      String url = input.imageUrl;
      if (input.newImage != null) {
        url = await storage.uploadProductImage(input.newImage!);
      }
      await remote.updateProduct(docId, _buildMap(input, url));
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  Map<String, dynamic> _buildMap(ProductInput input, String imageUrl) {
    return {
      'title': input.title,
      'price': input.price,
      'description': input.description,
      'imageUrl': imageUrl,
      'category': input.category,
      'stockQuantity': input.stockQuantity,
      'sizes': input.sizes,
      'colors': input.colors,
      'gender': input.gender,
      'state': input.state,
    };
  }
}
