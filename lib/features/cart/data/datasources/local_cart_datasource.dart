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
  // v2: key خاص بكل مستخدم — يمنع تسرّب سلة حساب لحساب آخر
  static String _keyFor(String uid) => 'tala_cart_v2_$uid';

  final List<CartItem> _items = [];
  final StreamController<List<CartItem>> _controller =
      StreamController<List<CartItem>>.broadcast();

  String? _currentUid;
  bool _loaded = false;

  Stream<List<CartItem>> get stream => _controller.stream;
  List<CartItem> get items => List.unmodifiable(_items);

  /// يُستدعى عند بدء التطبيق (قبل معرفة المستخدم) — يبدأ بسلة فارغة.
  Future<void> init() async {
    // لا نحمّل أي بيانات هنا — ننتظر loadForUser لمعرفة الـ UID
    _loaded = false;
    _items.clear();
    _emit();
  }

  /// يُستدعى عند تسجيل دخول مستخدم (أو تبديل حساب).
  /// يحمّل سلة هذا المستخدم تحديداً من SharedPreferences.
  Future<void> loadForUser(String uid) async {
    if (_currentUid == uid && _loaded) return; // نفس المستخدم، مُحمَّل مسبقاً
    _currentUid = uid;
    _loaded = false;
    _items.clear();
    _emit(); // فارغة مؤقتاً أثناء التحميل
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_keyFor(uid));
      if (raw == null || raw.isEmpty) {
        _loaded = true;
        _emit();
        return;
      }
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        _loaded = true;
        _emit();
        return;
      }
      for (final entry in decoded) {
        if (entry is Map<String, dynamic>) {
          try {
            _items.add(CartItem.fromJson(entry));
          } catch (e) {
            debugPrint('cart item parse failed: $e');
          }
        }
      }
      _loaded = true;
      _emit();
    } catch (e) {
      debugPrint('cart load failed: $e');
      _items.clear();
      _loaded = true;
      _emit();
    }
  }

  void _emit() => _controller.add(items);

  /// يحفظ السلة الحالية في SharedPreferences. fire-and-forget.
  Future<void> _persist() async {
    final uid = _currentUid;
    if (uid == null) return; // لا يوجد مستخدم — لا نحفظ
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = jsonEncode(_items.map((i) => i.toJson()).toList());
      await prefs.setString(_keyFor(uid), raw);
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

  /// يُستدعى عند تسجيل الخروج فقط.
  /// يمسح السلة من الذاكرة (حتى لا يراها المستخدم التالي) لكنه **لا** يحذف
  /// السلة المحفوظة في SharedPreferences — تبقى محفوظة وتعود عند تسجيل
  /// الدخول مرة أخرى بنفس الحساب.
  void unloadForLogout() {
    _items.clear();
    _currentUid = null;
    _loaded = false;
    _emit();
  }

  void dispose() => _controller.close();
}
