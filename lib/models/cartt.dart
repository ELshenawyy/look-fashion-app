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

  Map<String, dynamic> toJson() => {
        'productId': productId,
        'name': name,
        'price': price,
        'image': image,
        'size': size,
        'color': color,
        'productState': productState,
        'stockQuantity': stockQuantity,
        'quantity': quantity,
      };

  factory CartItem.fromJson(Map<String, dynamic> json) => CartItem(
        productId: json['productId'] as String,
        name: json['name'] as String,
        price: (json['price'] as num).toDouble(),
        image: json['image'] as String,
        size: json['size'] as String,
        color: json['color'] as String,
        productState: json['productState'] as String? ?? '',
        stockQuantity: json['stockQuantity'] as int? ?? 0,
        quantity: json['quantity'] as int? ?? 1,
      );
}
