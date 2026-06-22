import 'package:my_fashion_app/features/cart/data/datasources/local_cart_datasource.dart';
import 'package:my_fashion_app/features/cart/domain/repositories/cart_repository.dart';
import 'package:my_fashion_app/models/cartt.dart';

class CartRepositoryImpl implements CartRepository {
  final LocalCartDataSource local;
  CartRepositoryImpl(this.local);

  @override
  Stream<List<CartItem>> watchCart() => local.stream;

  @override
  List<CartItem> get items => local.items;

  @override
  Future<void> loadForUser(String uid) => local.loadForUser(uid);

  @override
  void addItem(CartItem item) => local.addItem(item);

  @override
  void removeAt(int index) => local.removeAt(index);

  @override
  void incrementQuantity(int index) => local.incrementQuantity(index);

  @override
  void decrementQuantity(int index) => local.decrementQuantity(index);

  @override
  void clear() => local.clear();

  @override
  void unloadForLogout() => local.unloadForLogout();
}
