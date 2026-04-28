class Product {
  final int id;
  final double price;
  final String title;
  final String imageUrl;
  final String description;
  final String gender;
  final List<String> sizes;
  final List<String> colors;
  final int stockQuantity;
  final String category;
  final String? docId; // Firestore document ID
  final String state; // Sudanese state where product is located

  Product({
    required this.id,
    required this.price,
    required this.title,
    required this.imageUrl,
    required this.description,
    required this.gender,
    this.sizes = const [],
    this.colors = const [],
    this.stockQuantity = 0,
    this.category = '',
    this.docId,
    this.state = '',
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

    List<String> parsedSizes = [];
    if (json['sizes'] is List) {
      parsedSizes = List<String>.from(json['sizes'].map((e) => e.toString()));
    }

    List<String> parsedColors = [];
    if (json['colors'] is List) {
      parsedColors = List<String>.from(json['colors'].map((e) => e.toString()));
    }

    int parsedStock = 0;
    final rawStock = json['stockQuantity'];
    if (rawStock is int) {
      parsedStock = rawStock;
    } else if (rawStock is String) {
      parsedStock = int.tryParse(rawStock) ?? 0;
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
      sizes: parsedSizes,
      colors: parsedColors,
      stockQuantity: parsedStock,
      category: json['category'] ?? '',
      docId: json['docId'] ?? (json.containsKey('_id') ? json['_id'] : null),
      state: json['state'] as String? ?? '',
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
      'sizes': sizes,
      'colors': colors,
      'stockQuantity': stockQuantity,
      'category': category,
      'state': state,
    };
  }
}
