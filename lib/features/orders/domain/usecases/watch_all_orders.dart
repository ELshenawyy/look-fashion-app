import 'package:my_fashion_app/features/orders/domain/entities/order_entity.dart';
import 'package:my_fashion_app/features/orders/domain/repositories/order_repository.dart';

class WatchAllOrders {
  final OrderRepository repository;
  WatchAllOrders(this.repository);

  Stream<List<OrderEntity>> call() => repository.watchAllOrders();
}
