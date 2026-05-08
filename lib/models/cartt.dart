class CartItem {
  final String productId;
  final String name;
  final double price;
  final String image;
  final String size;
  final String color;
  final String productState;
  final int stockQuantity; // 0 = بدون حد (عند الإضافة السريعة)
  int quantity;

  CartItem({
    required this.productId,
    required this.name,
    required this.price,
    required this.image,
    required this.size,
    required this.color,
    this.productState = '',
    this.stockQuantity = 0,
    this.quantity = 1,
  });
}
