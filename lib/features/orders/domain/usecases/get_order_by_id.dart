import 'package:dartz/dartz.dart';
import 'package:my_fashion_app/core/error/failures.dart';
import 'package:my_fashion_app/core/usecase/usecase.dart';
import 'package:my_fashion_app/features/orders/domain/entities/order_entity.dart';
import 'package:my_fashion_app/features/orders/domain/repositories/order_repository.dart';

class GetOrderById implements UseCase<OrderEntity, String> {
  final OrderRepository repository;
  GetOrderById(this.repository);

  @override
  Future<Either<Failure, OrderEntity>> call(String orderId) =>
      repository.getOrderById(orderId);
}
