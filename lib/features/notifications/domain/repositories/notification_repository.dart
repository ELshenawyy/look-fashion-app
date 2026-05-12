import 'package:dartz/dartz.dart';
import 'package:my_fashion_app/core/error/failures.dart';
import 'package:my_fashion_app/features/notifications/domain/entities/notification_entity.dart';

abstract class NotificationRepository {
  /// Stream للإشعارات حسب الدور: الإدمن يرى إشعارات الإدمن، المستخدم يرى إشعاراته فقط.
  Stream<List<NotificationEntity>> watchNotifications({
    required String userId,
    required bool isAdmin,
  });

  Stream<int> watchUnreadCount({
    required String userId,
    required bool isAdmin,
  });

  Future<Either<Failure, void>> markAsRead(String notificationId);

  Future<Either<Failure, void>> markAllAsRead({
    required String userId,
    required bool isAdmin,
  });

  Future<Either<Failure, void>> delete(String notificationId);
}
