import 'package:dartz/dartz.dart';
import 'package:my_fashion_app/core/error/failures.dart';
import 'package:my_fashion_app/core/usecase/usecase.dart';
import 'package:my_fashion_app/features/orders/domain/repositories/order_repository.dart';

class PlaceOrder implements UseCase<String, PlaceOrderInput> {
  final OrderRepository repository;
  PlaceOrder(this.repository);

  @override
  Future<Either<Failure, String>> call(PlaceOrderInput params) =>
      repository.placeOrder(params);
}
