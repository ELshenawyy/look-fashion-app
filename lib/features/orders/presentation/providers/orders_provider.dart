import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:my_fashion_app/core/error/failures.dart';
import 'package:my_fashion_app/features/orders/domain/entities/order_entity.dart';
import 'package:my_fashion_app/features/orders/domain/repositories/order_repository.dart';
import 'package:my_fashion_app/features/orders/domain/usecases/place_order.dart';
import 'package:my_fashion_app/features/orders/domain/usecases/update_order_status.dart';
import 'package:my_fashion_app/features/orders/domain/usecases/watch_all_orders.dart';
import 'package:my_fashion_app/features/orders/domain/usecases/watch_user_orders.dart';

class OrdersProvider extends ChangeNotifier {
  final PlaceOrder _placeOrder;
  final WatchUserOrders _watchUserOrders;
  final WatchAllOrders _watchAllOrders;
  final UpdateOrderStatus _updateOrderStatus;

  OrdersProvider({
    required PlaceOrder placeOrder,
    required WatchUserOrders watchUserOrders,
    required WatchAllOrders watchAllOrders,
    required UpdateOrderStatus updateOrderStatus,
  })  : _placeOrder = placeOrder,
        _watchUserOrders = watchUserOrders,
        _watchAllOrders = watchAllOrders,
        _updateOrderStatus = updateOrderStatus;

  StreamSubscription<List<OrderEntity>>? _userSub;
  StreamSubscription<List<OrderEntity>>? _allSub;

  List<OrderEntity> _userOrders = const [];
  List<OrderEntity> _allOrders = const [];
  Failure? _failure;
  bool _placing = false;

  List<OrderEntity> get userOrders => _userOrders;
  List<OrderEntity> get allOrders => _allOrders;
  Failure? get failure => _failure;
  bool get placing => _placing;

  void watchForUser(String userId) {
    _userSub?.cancel();
    _userSub = _watchUserOrders(userId).listen(
      (data) {
        _userOrders = data;
        notifyListeners();
      },
      onError: (e) {
        _failure = UnknownFailure(e.toString());
        notifyListeners();
      },
    );
  }

  void watchAll() {
    _allSub?.cancel();
    _allSub = _watchAllOrders().listen(
      (data) {
        _allOrders = data;
        notifyListeners();
      },
      onError: (e) {
        _failure = UnknownFailure(e.toString());
        notifyListeners();
      },
    );
  }

  /// يرجع orderId عند النجاح، null عند الفشل (failure مُعَيَّن).
  Future<String?> placeOrder(PlaceOrderInput input) async {
    _placing = true;
    _failure = null;
    notifyListeners();

    final res = await _placeOrder(input);
    _placing = false;
    return res.fold((f) {
      _failure = f;
      notifyListeners();
      return null;
    }, (id) {
      notifyListeners();
      return id;
    });
  }

  Future<bool> updateStatus({
    required String orderId,
    required OrderStatus status,
  }) async {
    final res = await _updateOrderStatus(
        UpdateOrderStatusParams(orderId: orderId, status: status));
    return res.fold((f) {
      _failure = f;
      notifyListeners();
      return false;
    }, (_) => true);
  }

  void clearFailure() {
    _failure = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _userSub?.cancel();
    _allSub?.cancel();
    super.dispose();
  }
}
