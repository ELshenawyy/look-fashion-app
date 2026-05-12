import 'package:dartz/dartz.dart';
import 'package:my_fashion_app/core/error/failures.dart';
import 'package:my_fashion_app/features/orders/domain/entities/order_entity.dart';
import 'package:my_fashion_app/models/cartt.dart';

/// Payload لإنشاء الطلب — البيانات المدخلة من الـ checkout.
class PlaceOrderInput {
  final String? userId;
  final String? userEmail;
  final String userName;
  final String phone;
  final String address;
  final String? state;
  final List<CartItem> items;
  final double subtotal;
  final double deliveryCost;
  final double total;
  final List<String> productStates;
  final String deliveryDays;

  const PlaceOrderInput({
    required this.userId,
    required this.userEmail,
    required this.userName,
    required this.phone,
    required this.address,
    required this.state,
    required this.items,
    required this.subtotal,
    required this.deliveryCost,
    required this.total,
    required this.productStates,
    this.deliveryDays = '1-15',
  });
}

abstract class OrderRepository {
  /// تنفيذ معاملة Firestore: تحقق من المخزون → إنشاء الطلب → إنقاص المخزون → إشعار الإدمن.
  /// الجزء الذري هو (تحقق + إنشاء + إنقاص). إشعار الإدمن خارج المعاملة (غير حرج).
  Future<Either<Failure, String>> placeOrder(PlaceOrderInput input);

  Stream<List<OrderEntity>> watchUserOrders(String userId);
  Stream<List<OrderEntity>> watchAllOrders();

  Future<Either<Failure, OrderEntity>> getOrderById(String orderId);

  Future<Either<Failure, void>> updateOrderStatus({
    required String orderId,
    required OrderStatus status,
  });
}
