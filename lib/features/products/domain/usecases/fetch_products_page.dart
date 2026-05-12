import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:my_fashion_app/core/error/failures.dart';
import 'package:my_fashion_app/core/usecase/usecase.dart';
import 'package:my_fashion_app/features/products/domain/repositories/product_repository.dart';

class FetchProductsPageParams extends Equatable {
  final String? category;
  final String sortField;
  final bool descending;
  final DocumentSnapshot? startAfter;

  const FetchProductsPageParams({
    this.category,
    this.sortField = 'createdAt',
    this.descending = true,
    this.startAfter,
  });

  @override
  List<Object?> get props => [category, sortField, descending, startAfter];
}

class FetchProductsPage
    implements UseCase<ProductPage, FetchProductsPageParams> {
  final ProductRepository repository;
  FetchProductsPage(this.repository);

  @override
  Future<Either<Failure, ProductPage>> call(FetchProductsPageParams params) =>
      repository.fetchProducts(
        category: params.category,
        sortField: params.sortField,
        descending: params.descending,
        startAfter: params.startAfter,
      );
}
