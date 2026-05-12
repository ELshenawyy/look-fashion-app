import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_fashion_app/features/orders/domain/entities/order_entity.dart';

class OrderItemModel extends OrderItemEntity {
  const OrderItemModel({
    required super.productId,
    required super.name,
    required super.price,
    required super.quantity,
    required super.size,
    required super.color,
    required super.image,
  });

  factory OrderItemModel.fromMap(Map<String, dynamic> m) => OrderItemModel(
        productId: (m['productId'] as String?) ?? '',
        name: (m['name'] as String?) ?? '',
        price: (m['price'] as num?)?.toDouble() ?? 0.0,
        quantity: (m['quantity'] as num?)?.toInt() ?? 0,
        size: (m['size'] as String?) ?? '',
        color: (m['color'] as String?) ?? '',
        image: (m['image'] as String?) ?? '',
      );
}

class OrderModel extends OrderEntity {
  const OrderModel({
    required super.id,
    required super.userId,
    required super.userEmail,
    required super.userName,
    required super.phone,
    required super.address,
    required super.state,
    required super.items,
    required super.subtotal,
    required super.deliveryCost,
    required super.total,
    required super.status,
    required super.productStates,
    required super.deliveryDays,
    required super.createdAt,
  });

  factory OrderModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const <String, dynamic>{};
    final rawItems = (d['items'] as List?) ?? const [];
    final items = rawItems
        .whereType<Map<String, dynamic>>()
        .map(OrderItemModel.fromMap)
        .toList();
    return OrderModel(
      id: doc.id,
      userId: d['userId'] as String?,
      userEmail: d['userEmail'] as String?,
      userName: (d['userName'] as String?) ?? '',
      phone: (d['phone'] as String?) ?? '',
      address: (d['address'] as String?) ?? '',
      state: d['state'] as String?,
      items: items,
      subtotal: (d['subtotal'] as num?)?.toDouble() ?? 0.0,
      deliveryCost: (d['deliveryCost'] as num?)?.toDouble() ?? 0.0,
      total: (d['total'] as num?)?.toDouble() ?? 0.0,
      status: OrderStatus.fromString(d['status'] as String?),
      productStates:
          ((d['productStates'] as List?) ?? const []).cast<String>(),
      deliveryDays: (d['deliveryDays'] as String?) ?? '',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
