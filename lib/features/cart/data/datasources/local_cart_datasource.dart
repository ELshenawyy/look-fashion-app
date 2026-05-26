import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:my_fashion_app/models/cartt.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// مصدر بيانات السلة — Single Source of Truth.
///
/// **Persistence:** يحفظ تلقائياً في SharedPreferences بعد كل تعديل،
/// ويعيد التحميل عند `init()`. النتيجة: السلة تبقى محفوظة عند إغلاق
/// التطبيق ولا تختفي حتى يقوم المستخدم بالشراء أو الحذف بنفسه.
class LocalCartDataSource {
  static const _kStorageKey = 'tala_cart_items_v1';

  final List<CartItem> _items = [];
  final StreamController<List<CartItem>> _controller =
      StreamController<List<CartItem>>.broadcast();

  bool _loaded = false;

  Stream<List<CartItem>> get stream => _controller.stream;
  List<CartItem> get items => List.unmodifiable(_items);

  /// يحمّل السلة من SharedPreferences (يُستدعى مرة واحدة عند بدء التطبيق).
  /// آمن للاستدعاء المتكرر — يتجاهل أي استدعاء بعد التحميل الأول.
  Future<void> init() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kStorageKey);
      if (raw == null || raw.isEmpty) {
        _emit();
        return;
      }
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        _emit();
        return;
      }
      _items.clear();
      for (final entry in decoded) {
        if (entry is Map<String, dynamic>) {
          try {
            _items.add(CartItem.fromJson(entry));
          } catch (e) {
            // ignore item فاسد، نحمّل الباقي
            debugPrint('cart item parse failed: $e');
          }
        }
      }
      _emit();
    } catch (e) {
      // corrupt data → نتجاهل ونبدأ بسلة فاضية
      debugPrint('cart load failed: $e');
      _items.clear();
      _emit();
    }
  }

  void _emit() => _controller.add(items);

  /// يحفظ السلة الحالية في SharedPreferences. fire-and-forget.
  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = jsonEncode(_items.map((i) => i.toJson()).toList());
      await prefs.setString(_kStorageKey, raw);
    } catch (e) {
      debugPrint('cart persist failed: $e');
    }
  }

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
    _persist();
    return true;
  }

  void removeAt(int index) {
    if (index < 0 || index >= _items.length) return;
    _items.removeAt(index);
    _emit();
    _persist();
  }

  bool incrementQuantity(int index) {
    if (index < 0 || index >= _items.length) return false;
    final item = _items[index];
    if (item.stockQuantity > 0 && item.quantity >= item.stockQuantity) {
      return false;
    }
    item.quantity++;
    _emit();
    _persist();
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
    _persist();
  }

  void clear() {
    _items.clear();
    _emit();
    _persist();
  }

  void dispose() => _controller.close();
}
