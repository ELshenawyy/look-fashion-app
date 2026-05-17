import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:my_fashion_app/core/error/failures.dart';
import 'package:my_fashion_app/features/notifications/domain/entities/notification_entity.dart';
import 'package:my_fashion_app/features/notifications/domain/repositories/notification_repository.dart';

class NotificationsProvider extends ChangeNotifier {
  final NotificationRepository _repo;
  NotificationsProvider(this._repo);

  StreamSubscription<List<NotificationEntity>>? _sub;
  List<NotificationEntity> _notifications = const [];
  Failure? _failure;
  bool _loading = true;
  String? _activeUserId;
  bool _activeIsAdmin = false;

  List<NotificationEntity> get notifications => _notifications;
  Failure? get failure => _failure;
  bool get loading => _loading;

  /// Stream للعدد غير المقروء — يُستهلك مباشرة من repo (للـ NotificationBellAction).
  Stream<int> watchUnreadCount({
    required String userId,
    required bool isAdmin,
  }) =>
      _repo.watchUnreadCount(userId: userId, isAdmin: isAdmin);

  void startWatching({required String userId, required bool isAdmin}) {
    if (_activeUserId == userId &&
        _activeIsAdmin == isAdmin &&
        _sub != null) {
      return;
    }
    _activeUserId = userId;
    _activeIsAdmin = isAdmin;
    _sub?.cancel();
    _sub = _repo.watchNotifications(userId: userId, isAdmin: isAdmin).listen(
      (data) {
        _notifications = data;
        _loading = false;
        _failure = null;
        notifyListeners();
      },
      onError: (e) {
        _failure = UnknownFailure(e.toString());
        _loading = false;
        notifyListeners();
      },
    );
  }

  Future<void> markAsRead(String id) async {
    final res = await _repo.markAsRead(id);
    res.fold((f) {
      _failure = f;
      notifyListeners();
    }, (_) => null);
  }

  Future<void> markAllAsRead() async {
    final uid = _activeUserId;
    if (uid == null) return;
    final res =
        await _repo.markAllAsRead(userId: uid, isAdmin: _activeIsAdmin);
    res.fold((f) {
      _failure = f;
      notifyListeners();
    }, (_) => null);
  }

  Future<void> delete(String id) async {
    final res = await _repo.delete(id);
    res.fold((f) {
      _failure = f;
      notifyListeners();
    }, (_) => null);
  }

  void clearFailure() {
    _failure = null;
    notifyListeners();
  }

  /// يُستدعى عند signOut — مسح إشعارات المستخدم القديم من الذاكرة.
  void reset() {
    _sub?.cancel();
    _sub = null;
    _notifications = const [];
    _failure = null;
    _loading = true;
    _activeUserId = null;
    _activeIsAdmin = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
