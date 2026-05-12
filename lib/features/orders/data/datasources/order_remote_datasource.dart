import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_fashion_app/core/error/exceptions.dart';
import 'package:my_fashion_app/features/orders/data/models/order_model.dart';
import 'package:my_fashion_app/features/orders/domain/entities/order_entity.dart';
import 'package:my_fashion_app/features/orders/domain/repositories/order_repository.dart';

abstract class OrderRemoteDataSource {
  /// المعاملة الذرية: تحقق من المخزون → إنشاء الطلب → إنقاص المخزون.
  /// يطلق StockException عند نقص المخزون.
  /// يرجع orderId.
  Future<String> placeOrderTransaction(PlaceOrderInput input);

  Stream<List<OrderModel>> watchUserOrders(String userId);
  Stream<List<OrderModel>> watchAllOrders();
  Future<OrderModel> getOrderById(String orderId);
  Future<void> updateOrderStatus({
    required String orderId,
    required OrderStatus status,
  });

  /// إشعار الإدمن — خارج المعاملة، non-critical.
  Future<void> notifyAdminsOfNewOrder({
    required String orderId,
    required String userName,
    required String phone,
    required String? userId,
    required List<String> itemNames,
  });
}

class OrderRemoteDataSourceImpl implements OrderRemoteDataSource {
  final FirebaseFirestore _db;
  OrderRemoteDataSourceImpl(this._db);

  @override
  Future<String> placeOrderTransaction(PlaceOrderInput input) async {
    final orderRef = _db.collection('orders').doc();
    final productRefs = input.items
        .map((item) => _db.collection('products').doc(item.productId))
        .toList();

    final orderItems = input.items
        .map((item) => {
              'productId': item.productId,
              'name': item.name,
              'price': item.price,
              'quantity': item.quantity,
              'size': item.size,
              'color': item.color,
              'image': item.image,
            })
        .toList();

    try {
      await _db.runTransaction((tx) async {
        // 1) قراءة كل المخزون أولاً (reads قبل writes)
        final snaps =
            await Future.wait(productRefs.map((ref) => tx.get(ref)));

        // 2) تحقق من المخزون
        for (int i = 0; i < input.items.length; i++) {
          final item = input.items[i];
          final snap = snaps[i];

          if (!snap.exists) {
            throw NotFoundException('المنتج "${item.name}" لم يعد متاحاً.');
          }

          final currentStock =
              (snap.data()?['stockQuantity'] as num?)?.toInt() ?? 0;

          if (currentStock < item.quantity) {
            if (currentStock == 0) {
              throw StockException(
                'المنتج "${item.name}" نفد من المخزون.',
                productId: item.productId,
                available: 0,
              );
            }
            throw StockException(
              'المنتج "${item.name}" متاح فقط $currentStock قطعة، لكن طلبت ${item.quantity}.',
              productId: item.productId,
              available: currentStock,
            );
          }
        }

        // 3) إنشاء مستند الطلب
        tx.set(orderRef, {
          'userId': input.userId,
          'userEmail': input.userEmail,
          'userName': input.userName,
          'items': orderItems,
          'subtotal': input.subtotal,
          'deliveryCost': input.deliveryCost,
          'total': input.total,
          'address': input.address,
          'state': input.state,
          'phone': input.phone,
          'status': 'pending',
          'productStates': input.productStates,
          'deliveryDays': input.deliveryDays,
          'createdAt': FieldValue.serverTimestamp(),
        });

        // 4) إنقاص المخزون
        for (int i = 0; i < input.items.length; i++) {
          tx.update(productRefs[i], {
            'stockQuantity': FieldValue.increment(-input.items[i].quantity),
          });
        }
      });

      return orderRef.id;
    } on StockException {
      rethrow;
    } on NotFoundException {
      rethrow;
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? e.code);
    }
  }

  @override
  Stream<List<OrderModel>> watchUserOrders(String userId) {
    return _db
        .collection('orders')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snap) {
      final orders =
          snap.docs.map((d) => OrderModel.fromFirestore(d)).toList();
      orders.sort((a, b) {
        final at = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bt = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bt.compareTo(at);
      });
      return orders;
    });
  }

  @override
  Stream<List<OrderModel>> watchAllOrders() {
    return _db
        .collection('orders')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => OrderModel.fromFirestore(d)).toList());
  }

  @override
  Future<OrderModel> getOrderById(String orderId) async {
    try {
      final doc = await _db.collection('orders').doc(orderId).get();
      if (!doc.exists) {
        throw const NotFoundException('الطلب غير موجود');
      }
      return OrderModel.fromFirestore(doc);
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? e.code);
    }
  }

  @override
  Future<void> updateOrderStatus({
    required String orderId,
    required OrderStatus status,
  }) async {
    try {
      await _db.collection('orders').doc(orderId).update({
        'status': status.toFirestoreValue(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? e.code);
    }
  }

  @override
  Future<void> notifyAdminsOfNewOrder({
    required String orderId,
    required String userName,
    required String phone,
    required String? userId,
    required List<String> itemNames,
  }) async {
    try {
      await _db.collection('notifications').add({
        'type': 'new_order',
        'title': 'طلب جديد من $userName',
        'body': itemNames.join('، '),
        'orderId': orderId,
        'forRole': 'admin',
        'forUserId': null,
        'read': false,
        'senderName': userName,
        'senderPhone': phone,
        'senderId': userId ?? '',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException {
      // إشعار غير حرج — تجاهل الفشل
    }
  }
}
