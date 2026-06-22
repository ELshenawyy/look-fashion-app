import 'package:my_fashion_app/models/cartt.dart';

/// السلة محلياً (in-memory). في المستقبل يمكن إضافة persistence.
abstract class CartRepository {
  Stream<List<CartItem>> watchCart();
  List<CartItem> get items;

  Future<void> loadForUser(String uid);
  void addItem(CartItem item);
  void removeAt(int index);
  void incrementQuantity(int index);
  void decrementQuantity(int index);
  void clear();

  /// يمسح حالة السلة من الذاكرة عند تسجيل الخروج دون حذف البيانات المحفوظة.
  void unloadForLogout();
}
