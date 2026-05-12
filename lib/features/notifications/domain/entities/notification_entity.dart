import 'package:equatable/equatable.dart';

class NotificationEntity extends Equatable {
  final String id;
  final String type;
  final String title;
  final String body;
  final String? orderId;
  final String? forRole;
  final String? forUserId;
  final bool read;
  final String senderName;
  final String? senderPhone;
  final String senderId;
  final DateTime? createdAt;

  const NotificationEntity({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.read,
    required this.senderName,
    required this.senderId,
    this.orderId,
    this.forRole,
    this.forUserId,
    this.senderPhone,
    this.createdAt,
  });

  @override
  List<Object?> get props => [
        id,
        type,
        title,
        body,
        orderId,
        forRole,
        forUserId,
        read,
        senderName,
        senderPhone,
        senderId,
        createdAt,
      ];
}
