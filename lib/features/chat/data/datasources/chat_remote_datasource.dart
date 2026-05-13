import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_fashion_app/core/error/exceptions.dart';
import 'package:my_fashion_app/features/chat/data/models/chat_message_model.dart';

abstract class ChatRemoteDataSource {
  Stream<List<ChatMessageModel>> watchMessages(String orderId);

  Future<void> sendMessage({
    required String orderId,
    required String text,
    required String senderId,
    required String senderName,
    String? senderEmail,
    required bool isAdminSender,
  });
}

class ChatRemoteDataSourceImpl implements ChatRemoteDataSource {
  final FirebaseFirestore _db;
  ChatRemoteDataSourceImpl(this._db);

  CollectionReference<Map<String, dynamic>> _messagesRef(String orderId) =>
      _db.collection('orders').doc(orderId).collection('messages');

  @override
  Stream<List<ChatMessageModel>> watchMessages(String orderId) {
    return _messagesRef(orderId)
        .orderBy('createdAt')
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => ChatMessageModel.fromFirestore(d)).toList());
  }

  @override
  Future<void> sendMessage({
    required String orderId,
    required String text,
    required String senderId,
    required String senderName,
    String? senderEmail,
    required bool isAdminSender,
  }) async {
    try {
      // 1) إضافة الرسالة
      await _messagesRef(orderId).add({
        'text': text,
        'senderId': senderId,
        'senderEmail': senderEmail,
        'senderName': senderName,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 2) إنشاء إشعار للطرف الآخر — non-fatal
      try {
        final orderDoc =
            await _db.collection('orders').doc(orderId).get();
        final orderData = orderDoc.data();
        if (orderData != null) {
          final orderUserId = orderData['userId'] as String? ?? '';
          final customerName =
              orderData['userName'] as String? ?? 'العميل';

          await _db.collection('notifications').add({
            'type': 'chat_message',
            'title':
                isAdminSender ? 'رسالة من الإدارة' : 'رسالة من $customerName',
            'body': text.length > 50 ? '${text.substring(0, 50)}...' : text,
            'orderId': orderId,
            'forRole': isAdminSender ? null : 'admin',
            'forUserId': isAdminSender ? orderUserId : null,
            'read': false,
            'senderName': senderName,
            'senderId': senderId,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      } catch (_) {
        // الإشعار غير حرج — تجاهل الفشل
      }
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? e.code);
    }
  }
}
