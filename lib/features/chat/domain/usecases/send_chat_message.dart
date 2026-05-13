import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:my_fashion_app/core/error/failures.dart';
import 'package:my_fashion_app/core/usecase/usecase.dart';
import 'package:my_fashion_app/features/chat/domain/repositories/chat_repository.dart';

class SendChatMessageParams extends Equatable {
  final String orderId;
  final String text;
  final String senderId;
  final String senderName;
  final String? senderEmail;
  final bool isAdminSender;

  const SendChatMessageParams({
    required this.orderId,
    required this.text,
    required this.senderId,
    required this.senderName,
    required this.isAdminSender,
    this.senderEmail,
  });

  @override
  List<Object?> get props =>
      [orderId, text, senderId, senderName, senderEmail, isAdminSender];
}

class SendChatMessage implements UseCase<void, SendChatMessageParams> {
  final ChatRepository repository;
  SendChatMessage(this.repository);

  @override
  Future<Either<Failure, void>> call(SendChatMessageParams params) =>
      repository.sendMessage(
        orderId: params.orderId,
        text: params.text,
        senderId: params.senderId,
        senderName: params.senderName,
        senderEmail: params.senderEmail,
        isAdminSender: params.isAdminSender,
      );
}
