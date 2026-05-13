import 'package:dartz/dartz.dart';
import 'package:my_fashion_app/core/error/failures.dart';
import 'package:my_fashion_app/core/usecase/usecase.dart';
import 'package:my_fashion_app/features/products/domain/repositories/product_repository.dart';

class AddProduct implements UseCase<String, ProductInput> {
  final ProductRepository repository;
  AddProduct(this.repository);

  @override
  Future<Either<Failure, String>> call(ProductInput input) =>
      repository.addProduct(input);
}
