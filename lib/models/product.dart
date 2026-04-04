class Product {
  final int id;
  final double price;
  final String title;
  final String imageUrl;
  final String description;
  final String gender;

  Product({
    required this.id,
    required this.price,
    required this.title,
    required this.imageUrl,
    required this.description,
    required this.gender,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    final rawPrice = json['price'];
    double parsedPrice;
    if (rawPrice is int) {
      parsedPrice = rawPrice.toDouble();
    } else if (rawPrice is double) {
      parsedPrice = rawPrice;
    } else if (rawPrice is String) {
      parsedPrice = double.tryParse(rawPrice) ?? 0.0;
    } else {
      parsedPrice = 0.0;
    }

    return Product(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id']?.toString() ?? '') ?? 0,
      price: parsedPrice,
      title: json['title'] ?? '',
      imageUrl: json['imageUrl'] ?? '',
      description: json['description'] ?? '',
      gender: json['gender'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'price': price,
      'title': title,
      'imageUrl': imageUrl,
      'description': description,
      'gender': gender,
    };
  }
}
