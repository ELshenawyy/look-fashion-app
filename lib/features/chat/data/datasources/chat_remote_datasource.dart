import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
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
    debugPrint('[chat.watch] subscribing to orderId=$orderId');
    return _messagesRef(orderId)
        .orderBy('createdAt')
        .snapshots()
        .map((snap) {
      debugPrint(
          '[chat.watch] orderId=$orderId snapshot docs=${snap.docs.length}');
      return snap.docs.map((d) => ChatMessageModel.fromFirestore(d)).toList();
    }).handleError((Object e, StackTrace st) {
      debugPrint('[chat.watch] ❌ orderId=$orderId stream error: $e');
      // rethrow حتى يصل الـ error للـ provider ويُظهر رسالة للمستخدم
      // بدلاً من أن يظل الـ stream صامتاً ومكسوراً
      Error.throwWithStackTrace(e, st);
    });
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
    debugPrint(
        '[chat.send] orderId=$orderId sender=$senderId isAdmin=$isAdminSender text="${text.substring(0, text.length.clamp(0, 30))}"');
    try {
      // 1) إضافة الرسالة
      final docRef = await _messagesRef(orderId).add({
        'text': text,
        'senderId': senderId,
        'senderEmail': senderEmail,
        'senderName': senderName,
        'createdAt': FieldValue.serverTimestamp(),
      });
      debugPrint('[chat.send] ✓ written docId=${docRef.id}');

      // 1.b) ── رد تلقائي من فريق الدعم ───────────────────────────────────
      // يظهر مرة واحدة فقط بعد أول رسالة من المستخدم: إذا لم يردّ الإدمن
      // بعد + لم يُنشَر رد تلقائي (غير welcome) سابقاً → نضيف رد تلقائي.
      //
      // ⚠ welcome bot من order placement له `isWelcome: true` — لا نعتبره
      // auto-reply. هكذا المستخدم يرى:
      //   1) ترحيب فور الطلب
      //   2) "تم استلام رسالتك" بعد أول رسالة منه
      //   3) رد الأدمن لاحقاً
      if (!isAdminSender) {
        try {
          final orderDoc = await _db.collection('orders').doc(orderId).get();
          final orderUserId =
              (orderDoc.data()?['userId'] as String?) ?? '';

          final allMessages = await _messagesRef(orderId).get();
          bool hasAdminReply = false;
          bool hasNonWelcomeAutoReply = false;
          for (final m in allMessages.docs) {
            final data = m.data();
            final sid = (data['senderId'] as String?) ?? '';
            final isWelcome = (data['isWelcome'] as bool?) ?? false;
            if (sid == 'system' && !isWelcome) {
              hasNonWelcomeAutoReply = true;
            } else if (sid.isNotEmpty &&
                sid != orderUserId &&
                sid != 'system') {
              hasAdminReply = true;
            }
          }

          if (!hasAdminReply && !hasNonWelcomeAutoReply) {
            await _messagesRef(orderId).add({
              'text':
                  'تم استلام رسالتك ✓\nفريق إدارة طلّة سيرد عليك في أقرب وقت 🙏',
              'senderId': 'system',
              'senderName': 'إدارة تطبيق طلّة',
              'isAutoReply': true,
              'createdAt': FieldValue.serverTimestamp(),
            });
          }
        } catch (_) {
          // الرد التلقائي غير حرج — تجاهل الفشل
        }
      }

      // 2) إنشاء/تحديث إشعار للطرف الآخر — non-fatal
      // ⚠️ تجميع: إذا كان هناك إشعار chat_message غير مقروء سابق
      // لنفس الطلب والمستلم → نحدّثه (نزيد العداد + نحدّث body) بدلاً
      // من إنشاء إشعار جديد لكل رسالة. النتيجة: "لديك 3 رسائل من X"
      // بدل 3 إشعارات منفصلة.
      try {
        final orderDoc =
            await _db.collection('orders').doc(orderId).get();
        final orderData = orderDoc.data();
        if (orderData != null) {
          final orderUserId = orderData['userId'] as String? ?? '';
          final customerName =
              orderData['userName'] as String? ?? 'العميل';

          final notifsCol = _db.collection('notifications');
          Query<Map<String, dynamic>> query = notifsCol
              .where('type', isEqualTo: 'chat_message')
              .where('orderId', isEqualTo: orderId)
              .where('read', isEqualTo: false);
          if (isAdminSender) {
            query = query.where('forUserId', isEqualTo: orderUserId);
          } else {
            query = query.where('forRole', isEqualTo: 'admin');
          }

          final existing = await query.limit(1).get();

          final shortBody =
              text.length > 50 ? '${text.substring(0, 50)}...' : text;

          if (existing.docs.isNotEmpty) {
            // ── تحديث الإشعار الموجود ──
            final docRef = existing.docs.first.reference;
            final currentCount =
                (existing.docs.first.data()['count'] as num?)?.toInt() ?? 1;
            final newCount = currentCount + 1;
            await docRef.update({
              'title': isAdminSender
                  ? 'لديك $newCount رسائل من الإدارة'
                  : 'لديك $newCount رسائل من $customerName',
              'body': shortBody,
              'count': newCount,
              'senderName': senderName,
              'senderId': senderId,
              'updatedAt': FieldValue.serverTimestamp(),
            });
          } else {
            // ── إنشاء إشعار جديد ──
            await notifsCol.add({
              'type': 'chat_message',
              'title': isAdminSender
                  ? 'رسالة من الإدارة'
                  : 'رسالة من $customerName',
              'body': shortBody,
              'count': 1,
              'orderId': orderId,
              'forRole': isAdminSender ? null : 'admin',
              'forUserId': isAdminSender ? orderUserId : null,
              'read': false,
              'senderName': senderName,
              'senderId': senderId,
              'createdAt': FieldValue.serverTimestamp(),
            });
          }
        }
      } catch (_) {
        // الإشعار غير حرج — تجاهل الفشل
      }
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? e.code);
    }
  }
}
