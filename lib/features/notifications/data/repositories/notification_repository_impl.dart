import 'package:dartz/dartz.dart';
import 'package:my_fashion_app/core/error/exceptions.dart';
import 'package:my_fashion_app/core/error/failures.dart';
import 'package:my_fashion_app/core/network/network_info.dart';
import 'package:my_fashion_app/features/notifications/data/datasources/notification_remote_datasource.dart';
import 'package:my_fashion_app/features/notifications/domain/entities/notification_entity.dart';
import 'package:my_fashion_app/features/notifications/domain/repositories/notification_repository.dart';

class NotificationRepositoryImpl implements NotificationRepository {
  final NotificationRemoteDataSource remote;
  final NetworkInfo network;
  NotificationRepositoryImpl({required this.remote, required this.network});

  @override
  Stream<List<NotificationEntity>> watchNotifications({
    required String userId,
    required bool isAdmin,
  }) =>
      remote.watchNotifications(userId: userId, isAdmin: isAdmin);

  @override
  Stream<int> watchUnreadCount({
    required String userId,
    required bool isAdmin,
  }) =>
      remote.watchUnreadCount(userId: userId, isAdmin: isAdmin);

  @override
  Future<Either<Failure, void>> markAsRead(String notificationId) =>
      _wrap(() => remote.markAsRead(notificationId));

  @override
  Future<Either<Failure, void>> markAllAsRead({
    required String userId,
    required bool isAdmin,
  }) =>
      _wrap(() =>
          remote.markAllAsRead(userId: userId, isAdmin: isAdmin));

  @override
  Future<Either<Failure, void>> delete(String notificationId) =>
      _wrap(() => remote.delete(notificationId));

  Future<Either<Failure, void>> _wrap(Future<void> Function() action) async {
    if (!await network.isConnected) return const Left(NetworkFailure());
    try {
      await action();
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }
}
