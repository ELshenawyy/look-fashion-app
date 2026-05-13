import 'package:equatable/equatable.dart';

class ChatMessageEntity extends Equatable {
  final String id;
  final String text;
  final String senderId;
  final String senderName;
  final String? senderEmail;
  final DateTime? createdAt;

  const ChatMessageEntity({
    required this.id,
    required this.text,
    required this.senderId,
    required this.senderName,
    this.senderEmail,
    this.createdAt,
  });

  @override
  List<Object?> get props =>
      [id, text, senderId, senderName, senderEmail, createdAt];
}
