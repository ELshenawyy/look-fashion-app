import 'package:dartz/dartz.dart';
import 'package:my_fashion_app/core/error/failures.dart';
import 'package:my_fashion_app/features/chat/domain/entities/chat_message_entity.dart';

abstract class ChatRepository {
  /// Stream لرسائل طلب معيّن مرتّبة بالأقدم أولاً (لعرضها في chat list).
  Stream<List<ChatMessageEntity>> watchMessages(String orderId);

  /// إرسال رسالة جديدة + إشعار الطرف الآخر.
  Future<Either<Failure, void>> sendMessage({
    required String orderId,
    required String text,
    required String senderId,
    required String senderName,
    String? senderEmail,
    required bool isAdminSender,
  });
}
