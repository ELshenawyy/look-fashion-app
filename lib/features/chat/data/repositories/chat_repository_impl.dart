import 'package:dartz/dartz.dart';
import 'package:my_fashion_app/core/error/exceptions.dart';
import 'package:my_fashion_app/core/error/failures.dart';
import 'package:my_fashion_app/core/network/network_info.dart';
import 'package:my_fashion_app/features/chat/data/datasources/chat_remote_datasource.dart';
import 'package:my_fashion_app/features/chat/domain/entities/chat_message_entity.dart';
import 'package:my_fashion_app/features/chat/domain/repositories/chat_repository.dart';

class ChatRepositoryImpl implements ChatRepository {
  final ChatRemoteDataSource remote;
  final NetworkInfo network;
  ChatRepositoryImpl({required this.remote, required this.network});

  @override
  Stream<List<ChatMessageEntity>> watchMessages(String orderId) =>
      remote.watchMessages(orderId);

  @override
  Future<Either<Failure, void>> sendMessage({
    required String orderId,
    required String text,
    required String senderId,
    required String senderName,
    String? senderEmail,
    required bool isAdminSender,
  }) async {
    if (!await network.isConnected) return const Left(NetworkFailure());
    try {
      await remote.sendMessage(
        orderId: orderId,
        text: text,
        senderId: senderId,
        senderName: senderName,
        senderEmail: senderEmail,
        isAdminSender: isAdminSender,
      );
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }
}
