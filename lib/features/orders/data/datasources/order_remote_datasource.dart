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
    String? customerId,
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
          // Coupon fields (null/0 لو لا كوبون)
          if (input.couponCode != null) 'couponCode': input.couponCode,
          if (input.couponId != null) 'couponId': input.couponId,
          if (input.discountAmount > 0)
            'discountAmount': input.discountAmount,
        });

        // 4) إنقاص المخزون
        for (int i = 0; i < input.items.length; i++) {
          tx.update(productRefs[i], {
            'stockQuantity': FieldValue.increment(-input.items[i].quantity),
          });
        }
      });

      // ── Welcome bot message ──────────────────────────────────────
      // نضيف رسالة ترحيب تلقائية فور إنشاء الطلب — تظهر للعميل عند فتح
      // الشات + يستقبلها الأدمن مع الإشعار. غير قاتلة إذا فشلت.
      await _addWelcomeBotMessage(
        orderId: orderRef.id,
        userName: input.userName,
      );

      return orderRef.id;
    } on StockException {
      rethrow;
    } on NotFoundException {
      rethrow;
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? e.code);
    }
  }

  /// رسالة ترحيب من البوت تُضاف للشات فور إنشاء الطلب.
  /// `senderId: 'system'` يميّزها عن رسائل المستخدم/الأدمن.
  /// `isWelcome: true` يمنع الـ auto-reply القديم من التداخل معها.
  Future<void> _addWelcomeBotMessage({
    required String orderId,
    required String userName,
  }) async {
    try {
      final shortId =
          orderId.length >= 6 ? orderId.substring(0, 6) : orderId;
      final name = userName.trim().isEmpty ? 'عميلنا الكريم' : userName.trim();
      final text = 'أهلاً $name 👋\n'
          'طلبك رقم #$shortId تم استلامه بنجاح.\n'
          'فريقنا سيتواصل معك قريباً لتأكيد التفاصيل والشحن.\n'
          'يمكنك إرسال أي استفسار هنا في أي وقت.';
      await _db
          .collection('orders')
          .doc(orderId)
          .collection('messages')
          .add({
        'senderId': 'system',
        'senderName': 'إدارة تطبيق طلّة',
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
        'isAutoReply': true,
        'isWelcome': true,
      });
    } catch (_) {
      // غير قاتل — الطلب نفسه تم بنجاح
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
    String? customerId,
  }) async {
    try {
      if (status == OrderStatus.cancelled) {
        // Fetch the order to restore stock and extract customerId if needed.
        final orderDoc =
            await _db.collection('orders').doc(orderId).get();
        if (orderDoc.exists) {
          final data = orderDoc.data()!;
          final currentStatus =
              OrderStatus.fromString(data['status'] as String?);

          final batch = _db.batch();
          batch.update(_db.collection('orders').doc(orderId), {
            'status': OrderStatus.cancelled.toFirestoreValue(),
            'updatedAt': FieldValue.serverTimestamp(),
          });

          // Restore stock only once — guard against double-cancellation.
          if (currentStatus != OrderStatus.cancelled) {
            for (final item
                in (data['items'] as List<dynamic>? ?? [])) {
              final productId = item['productId'] as String?;
              final qty = (item['quantity'] as num?)?.toInt() ?? 0;
              if (productId != null && productId.isNotEmpty && qty > 0) {
                batch.update(
                  _db.collection('products').doc(productId),
                  {'stockQuantity': FieldValue.increment(qty)},
                );
              }
            }
          }

          // Reuse the already-fetched userId so _notifyCustomer avoids
          // a second read.
          customerId ??= data['userId'] as String?;
          await batch.commit();
        }
      } else {
        await _db.collection('orders').doc(orderId).update({
          'status': status.toFirestoreValue(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // Notify the customer — non-critical, never fails the status update
      await _notifyCustomerOfStatusChange(
        orderId: orderId,
        status: status,
        customerId: customerId,
      );
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? e.code);
    }
  }

  static String _statusBody(OrderStatus status) {
    switch (status.toFirestoreValue()) {
      case 'pending':
        return 'تم استلام طلبك ⏳';
      case 'preparing':
        return 'جاري تجهيز طلبك 📦';
      case 'shipped':
        return 'تم شحن طلبك 🚚';
      case 'delivered':
        return 'تم تسليم طلبك بنجاح 🎉';
      case 'cancelled':
        return 'تم إلغاء طلبك ❌';
      default:
        return 'تم تحديث حالة طلبك';
    }
  }

  Future<void> _notifyCustomerOfStatusChange({
    required String orderId,
    required OrderStatus status,
    String? customerId,
  }) async {
    try {
      // Use the customerId passed from the caller to avoid an extra Firestore
      // read. Fall back to fetching the document only if it wasn't provided.
      String? userId = customerId;
      if (userId == null || userId.isEmpty) {
        final orderDoc = await _db.collection('orders').doc(orderId).get();
        if (!orderDoc.exists) return;
        userId = orderDoc.data()?['userId'] as String?;
      }
      if (userId == null || userId.isEmpty) return;

      await _db.collection('notifications').add({
        'type': 'order_status_update',
        'title': 'تحديث طلبك',
        'body': _statusBody(status),
        'orderId': orderId,
        'forUserId': userId,
        'forRole': null,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Push notification is sent by the Cloud Function (functions/index.js)
      // which triggers on the notifications document created above.
    } catch (_) {
      // non-critical — ignore failures
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

      // Push notification is sent by the Cloud Function (functions/index.js)
      // which triggers on the notifications document created above.
    } on FirebaseException {
      // non-critical — ignore failures
    }
  }
}
