import 'package:equatable/equatable.dart';

enum OrderStatus {
  pending,
  preparing,
  shipped,
  delivered,
  cancelled,
  unknown;

  static OrderStatus fromString(String? v) {
    switch (v) {
      case 'pending':
        return pending;
      case 'preparing':
        return preparing;
      case 'shipped':
        return shipped;
      case 'delivered':
        return delivered;
      case 'cancelled':
        return cancelled;
      default:
        return unknown;
    }
  }

  String toFirestoreValue() => name;
}

class OrderItemEntity extends Equatable {
  final String productId;
  final String name;
  final double price;
  final int quantity;
  final String size;
  final String color;
  final String image;

  const OrderItemEntity({
    required this.productId,
    required this.name,
    required this.price,
    required this.quantity,
    required this.size,
    required this.color,
    required this.image,
  });

  @override
  List<Object?> get props =>
      [productId, name, price, quantity, size, color, image];
}

class OrderEntity extends Equatable {
  final String id;
  final String? userId;
  final String? userEmail;
  final String userName;
  final String phone;
  final String address;
  final String? state;
  final List<OrderItemEntity> items;
  final double subtotal;
  final double deliveryCost;
  final double total;
  final OrderStatus status;
  final List<String> productStates;
  final String deliveryDays;
  final DateTime? createdAt;

  const OrderEntity({
    required this.id,
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
    required this.status,
    required this.productStates,
    required this.deliveryDays,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [
        id,
        userId,
        userEmail,
        userName,
        phone,
        address,
        state,
        items,
        subtotal,
        deliveryCost,
        total,
        status,
        productStates,
        deliveryDays,
        createdAt,
      ];
}
