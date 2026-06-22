import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:my_fashion_app/features/cart/domain/repositories/cart_repository.dart';
import 'package:my_fashion_app/models/cartt.dart';

/// Provider للسلة — يحافظ على نفس واجهة Cart القديمة لتقليل تأثير التغيير.
/// يستدعي CartRepository، لا يحوي منطق مباشر.
class CartProvider extends ChangeNotifier {
  final CartRepository _repo;
  StreamSubscription<List<CartItem>>? _sub;
  List<CartItem> _items = const [];

  CartProvider(this._repo) {
    _items = _repo.items;
    _sub = _repo.watchCart().listen((data) {
      _items = data;
      notifyListeners();
    });
  }

  List<CartItem> get items => List.unmodifiable(_items);

  int get itemCount => _items.fold(0, (sum, item) => sum + item.quantity);

  double get totalPrice =>
      _items.fold(0.0, (sum, item) => sum + item.price * item.quantity);

  Future<void> loadForUser(String uid) => _repo.loadForUser(uid);

  void addItem(CartItem item) => _repo.addItem(item);
  void removeItem(int index) => _repo.removeAt(index);
  void incrementQuantity(int index) => _repo.incrementQuantity(index);
  void decrementQuantity(int index) => _repo.decrementQuantity(index);
  void clear() => _repo.clear();
  void unloadForLogout() => _repo.unloadForLogout();

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
