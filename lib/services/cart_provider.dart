import 'package:flutter/foundation.dart';
import 'package:my_fashion_app/models/cartt.dart';

class Cart with ChangeNotifier {
  final List<CartItem> _items = [];

  List<CartItem> get items => List.unmodifiable(_items);

  int get itemCount => _items.fold(0, (sum, item) => sum + item.quantity);

  double get totalPrice =>
      _items.fold(0.0, (sum, item) => sum + item.price * item.quantity);

  void addItem(CartItem item) {
    final existingIndex = _items.indexWhere(
      (i) =>
          i.productId == item.productId &&
          i.size == item.size &&
          i.color == item.color,
    );
    if (existingIndex >= 0) {
      final existing = _items[existingIndex];
      // احترام حد المخزون: إذا stockQuantity > 0 لا نتجاوزه
      if (existing.stockQuantity > 0 &&
          existing.quantity >= existing.stockQuantity) {
        return; // الكمية وصلت للحد الأقصى — تجاهل الطلب
      }
      existing.quantity++;
    } else {
      _items.add(item);
    }
    notifyListeners();
  }

  void removeItem(int index) {
    _items.removeAt(index);
    notifyListeners();
  }

  void incrementQuantity(int index) {
    final item = _items[index];
    // احترام حد المخزون
    if (item.stockQuantity > 0 && item.quantity >= item.stockQuantity) {
      return; // وصلنا للحد الأقصى
    }
    item.quantity++;
    notifyListeners();
  }

  void decrementQuantity(int index) {
    if (_items[index].quantity > 1) {
      _items[index].quantity--;
    } else {
      _items.removeAt(index);
    }
    notifyListeners();
  }

  void clear() {
    _items.clear();
    notifyListeners();
  }
}
