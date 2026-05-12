import 'dart:async';

import 'package:my_fashion_app/models/cartt.dart';

/// مصدر بيانات السلة في الذاكرة — Single Source of Truth.
class LocalCartDataSource {
  final List<CartItem> _items = [];
  final StreamController<List<CartItem>> _controller =
      StreamController<List<CartItem>>.broadcast();

  Stream<List<CartItem>> get stream => _controller.stream;
  List<CartItem> get items => List.unmodifiable(_items);

  void _emit() => _controller.add(items);

  /// يضيف منتج للسلة. إذا موجود بنفس المقاس واللون → يزيد الكمية مع احترام المخزون.
  /// يُرجع true إذا تمت الإضافة، false إذا وصل للحد الأقصى.
  bool addItem(CartItem item) {
    final existingIndex = _items.indexWhere(
      (i) =>
          i.productId == item.productId &&
          i.size == item.size &&
          i.color == item.color,
    );
    if (existingIndex >= 0) {
      final existing = _items[existingIndex];
      if (existing.stockQuantity > 0 &&
          existing.quantity >= existing.stockQuantity) {
        return false;
      }
      existing.quantity++;
    } else {
      _items.add(item);
    }
    _emit();
    return true;
  }

  void removeAt(int index) {
    if (index < 0 || index >= _items.length) return;
    _items.removeAt(index);
    _emit();
  }

  bool incrementQuantity(int index) {
    if (index < 0 || index >= _items.length) return false;
    final item = _items[index];
    if (item.stockQuantity > 0 && item.quantity >= item.stockQuantity) {
      return false;
    }
    item.quantity++;
    _emit();
    return true;
  }

  void decrementQuantity(int index) {
    if (index < 0 || index >= _items.length) return;
    if (_items[index].quantity > 1) {
      _items[index].quantity--;
    } else {
      _items.removeAt(index);
    }
    _emit();
  }

  void clear() {
    _items.clear();
    _emit();
  }

  void dispose() => _controller.close();
}
