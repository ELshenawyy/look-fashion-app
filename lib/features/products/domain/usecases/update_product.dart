import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:my_fashion_app/core/error/failures.dart';
import 'package:my_fashion_app/core/usecase/usecase.dart';
import 'package:my_fashion_app/features/products/domain/repositories/product_repository.dart';

class UpdateProductParams extends Equatable {
  final String docId;
  final ProductInput input;
  const UpdateProductParams({required this.docId, required this.input});

  @override
  List<Object?> get props => [docId];
}

class UpdateProduct implements UseCase<void, UpdateProductParams> {
  final ProductRepository repository;
  UpdateProduct(this.repository);

  @override
  Future<Either<Failure, void>> call(UpdateProductParams params) =>
      repository.updateProduct(docId: params.docId, input: params.input);
}
