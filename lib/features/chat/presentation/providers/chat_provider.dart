import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:my_fashion_app/core/error/failures.dart';
import 'package:my_fashion_app/features/chat/domain/entities/chat_message_entity.dart';
import 'package:my_fashion_app/features/chat/domain/usecases/send_chat_message.dart';
import 'package:my_fashion_app/features/chat/domain/usecases/watch_chat_messages.dart';

class ChatProvider extends ChangeNotifier {
  final WatchChatMessages _watchMessages;
  final SendChatMessage _sendMessage;

  ChatProvider({
    required WatchChatMessages watchMessages,
    required SendChatMessage sendMessage,
  })  : _watchMessages = watchMessages,
        _sendMessage = sendMessage;

  StreamSubscription<List<ChatMessageEntity>>? _sub;
  List<ChatMessageEntity> _messages = const [];
  Failure? _failure;
  bool _sending = false;
  String? _activeOrderId;

  List<ChatMessageEntity> get messages => _messages;
  Failure? get failure => _failure;
  bool get sending => _sending;

  void watchOrder(String orderId) {
    if (_activeOrderId == orderId && _sub != null) return;
    _activeOrderId = orderId;
    _sub?.cancel();
    _sub = _watchMessages(orderId).listen(
      (data) {
        _messages = data;
        notifyListeners();
      },
      onError: (e) {
        _failure = UnknownFailure(e.toString());
        notifyListeners();
      },
    );
  }

  Future<bool> send({
    required String orderId,
    required String text,
    required String senderId,
    required String senderName,
    String? senderEmail,
    required bool isAdminSender,
  }) async {
    _sending = true;
    notifyListeners();

    final res = await _sendMessage(SendChatMessageParams(
      orderId: orderId,
      text: text,
      senderId: senderId,
      senderName: senderName,
      senderEmail: senderEmail,
      isAdminSender: isAdminSender,
    ));

    _sending = false;
    return res.fold((f) {
      _failure = f;
      notifyListeners();
      return false;
    }, (_) {
      notifyListeners();
      return true;
    });
  }

  void clearFailure() {
    _failure = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
