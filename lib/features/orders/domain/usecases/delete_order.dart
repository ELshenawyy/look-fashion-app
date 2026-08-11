import 'package:dartz/dartz.dart';
import 'package:my_fashion_app/core/error/failures.dart';
import 'package:my_fashion_app/core/usecase/usecase.dart';
import 'package:my_fashion_app/features/orders/domain/repositories/order_repository.dart';

class DeleteOrder implements UseCase<void, String> {
  final OrderRepository repository;
  DeleteOrder(this.repository);

  @override
  Future<Either<Failure, void>> call(String orderId) =>
      repository.deleteOrder(orderId);
}
