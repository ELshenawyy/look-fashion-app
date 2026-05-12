import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_fashion_app/features/notifications/domain/entities/notification_entity.dart';

class NotificationModel extends NotificationEntity {
  const NotificationModel({
    required super.id,
    required super.type,
    required super.title,
    required super.body,
    required super.read,
    required super.senderName,
    required super.senderId,
    super.orderId,
    super.forRole,
    super.forUserId,
    super.senderPhone,
    super.createdAt,
  });

  factory NotificationModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const <String, dynamic>{};
    return NotificationModel(
      id: doc.id,
      type: (d['type'] as String?) ?? '',
      title: (d['title'] as String?) ?? '',
      body: (d['body'] as String?) ?? '',
      orderId: d['orderId'] as String?,
      forRole: d['forRole'] as String?,
      forUserId: d['forUserId'] as String?,
      read: (d['read'] as bool?) ?? false,
      senderName: (d['senderName'] as String?) ?? '',
      senderPhone: d['senderPhone'] as String?,
      senderId: (d['senderId'] as String?) ?? '',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
