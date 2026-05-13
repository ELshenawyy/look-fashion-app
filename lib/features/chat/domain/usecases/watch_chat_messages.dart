import 'package:my_fashion_app/features/chat/domain/entities/chat_message_entity.dart';
import 'package:my_fashion_app/features/chat/domain/repositories/chat_repository.dart';

class WatchChatMessages {
  final ChatRepository repository;
  WatchChatMessages(this.repository);

  Stream<List<ChatMessageEntity>> call(String orderId) =>
      repository.watchMessages(orderId);
}
