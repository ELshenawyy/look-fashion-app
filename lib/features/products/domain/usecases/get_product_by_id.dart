import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:my_fashion_app/core/error/failures.dart';
import 'package:my_fashion_app/core/usecase/usecase.dart';
import 'package:my_fashion_app/features/products/domain/repositories/product_repository.dart';
import 'package:my_fashion_app/models/product.dart';

class GetProductByIdParams extends Equatable {
  final String docId;
  const GetProductByIdParams(this.docId);

  @override
  List<Object?> get props => [docId];
}

/// يجلب منتج واحد بـ docId (يستخدم من المفضلة لجلب بيانات كاملة).
/// يرجع `Right(null)` لو المنتج محذوف.
class GetProductById implements UseCase<Product?, GetProductByIdParams> {
  final ProductRepository repository;
  GetProductById(this.repository);

  @override
  Future<Either<Failure, Product?>> call(GetProductByIdParams params) =>
      repository.getProductById(params.docId);
}
