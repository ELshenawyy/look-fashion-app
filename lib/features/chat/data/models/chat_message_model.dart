import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_fashion_app/features/chat/domain/entities/chat_message_entity.dart';

class ChatMessageModel extends ChatMessageEntity {
  const ChatMessageModel({
    required super.id,
    required super.text,
    required super.senderId,
    required super.senderName,
    super.senderEmail,
    super.createdAt,
  });

  factory ChatMessageModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const <String, dynamic>{};
    return ChatMessageModel(
      id: doc.id,
      text: (d['text'] as String?) ?? '',
      senderId: (d['senderId'] as String?) ?? '',
      senderName: (d['senderName'] as String?) ?? 'مستخدم',
      senderEmail: d['senderEmail'] as String?,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
