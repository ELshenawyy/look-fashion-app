import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:my_fashion_app/core/error/failures.dart';
import 'package:my_fashion_app/core/usecase/usecase.dart';
import 'package:my_fashion_app/features/orders/domain/entities/order_entity.dart';
import 'package:my_fashion_app/features/orders/domain/repositories/order_repository.dart';

class UpdateOrderStatusParams extends Equatable {
  final String orderId;
  final OrderStatus status;
  const UpdateOrderStatusParams({required this.orderId, required this.status});

  @override
  List<Object?> get props => [orderId, status];
}

class UpdateOrderStatus implements UseCase<void, UpdateOrderStatusParams> {
  final OrderRepository repository;
  UpdateOrderStatus(this.repository);

  @override
  Future<Either<Failure, void>> call(UpdateOrderStatusParams params) =>
      repository.updateOrderStatus(
        orderId: params.orderId,
        status: params.status,
      );
}
