class CartItem {
  final String productId;
  final String name;
  final double price;
  final String image;
  final String size;
  final String color;
  int quantity;

  CartItem({
    required this.productId,
    required this.name,
    required this.price,
    required this.image,
    required this.size,
    required this.color,
    this.quantity = 1,
  });
}
