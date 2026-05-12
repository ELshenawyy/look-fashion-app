import 'package:my_fashion_app/features/orders/domain/entities/order_entity.dart';
import 'package:my_fashion_app/features/orders/domain/repositories/order_repository.dart';

class WatchUserOrders {
  final OrderRepository repository;
  WatchUserOrders(this.repository);

  Stream<List<OrderEntity>> call(String userId) =>
      repository.watchUserOrders(userId);
}
