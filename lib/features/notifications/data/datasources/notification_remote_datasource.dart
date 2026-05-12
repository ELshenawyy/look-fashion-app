import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_fashion_app/core/error/exceptions.dart';
import 'package:my_fashion_app/features/notifications/data/models/notification_model.dart';

abstract class NotificationRemoteDataSource {
  Stream<List<NotificationModel>> watchNotifications({
    required String userId,
    required bool isAdmin,
  });

  Stream<int> watchUnreadCount({
    required String userId,
    required bool isAdmin,
  });

  Future<void> markAsRead(String notificationId);

  Future<void> markAllAsRead({
    required String userId,
    required bool isAdmin,
  });

  Future<void> delete(String notificationId);
}

class NotificationRemoteDataSourceImpl implements NotificationRemoteDataSource {
  final FirebaseFirestore _db;
  NotificationRemoteDataSourceImpl(this._db);

  Query<Map<String, dynamic>> _baseQuery({
    required String userId,
    required bool isAdmin,
  }) {
    final col = _db.collection('notifications');
    if (isAdmin) {
      return col.where('forRole', isEqualTo: 'admin');
    }
    return col.where('forUserId', isEqualTo: userId);
  }

  @override
  Stream<List<NotificationModel>> watchNotifications({
    required String userId,
    required bool isAdmin,
  }) {
    return _baseQuery(userId: userId, isAdmin: isAdmin).snapshots().map((snap) {
      final list =
          snap.docs.map((d) => NotificationModel.fromFirestore(d)).toList();
      list.sort((a, b) {
        final at = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bt = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bt.compareTo(at);
      });
      return list;
    });
  }

  @override
  Stream<int> watchUnreadCount({
    required String userId,
    required bool isAdmin,
  }) {
    return _baseQuery(userId: userId, isAdmin: isAdmin).snapshots().map(
          (snap) => snap.docs.where((d) => d.data()['read'] != true).length,
        );
  }

  @override
  Future<void> markAsRead(String notificationId) async {
    try {
      await _db
          .collection('notifications')
          .doc(notificationId)
          .update({'read': true});
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? e.code);
    }
  }

  @override
  Future<void> markAllAsRead({
    required String userId,
    required bool isAdmin,
  }) async {
    try {
      final unread = await _baseQuery(userId: userId, isAdmin: isAdmin)
          .where('read', isEqualTo: false)
          .get();
      final batch = _db.batch();
      for (final doc in unread.docs) {
        batch.update(doc.reference, {'read': true});
      }
      await batch.commit();
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? e.code);
    }
  }

  @override
  Future<void> delete(String notificationId) async {
    try {
      await _db.collection('notifications').doc(notificationId).delete();
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? e.code);
    }
  }
}
