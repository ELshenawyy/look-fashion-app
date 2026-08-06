class Product {
  final int id;
  final double price;
  final String title;
  final List<String> imageUrls;
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
    this.imageUrls = const [],
    required this.description,
    required this.gender,
    this.sizes = const [],
    this.colors = const [],
    this.stockQuantity = -1,
    this.category = '',
    this.docId,
    this.state = '',
  });

  /// صورة الغلاف (الأولى في القائمة) — للاستخدام في الأماكن التي تعرض
  /// صورة واحدة فقط (بطاقات المنتج، السلة، المفضلة...). فارغة إن لم توجد صور.
  String get imageUrl => imageUrls.isNotEmpty ? imageUrls.first : '';

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

    // يدعم كلا الشكلين: `imageUrls` (قائمة، الشكل الجديد) و
    // `imageUrl` (نص مفرد، الشكل القديم لمستندات Firestore السابقة).
    // لا نستخدم else-if لأن المنادي قد يمرر كلا الحقلين معاً (أحدهما فارغ).
    List<String> parsedImageUrls = [];
    if (json['imageUrls'] is List) {
      parsedImageUrls = List<String>.from(
        (json['imageUrls'] as List)
            .map((e) => e.toString())
            .where((e) => e.isNotEmpty),
      );
    }
    if (parsedImageUrls.isEmpty &&
        json['imageUrl'] is String &&
        (json['imageUrl'] as String).isNotEmpty) {
      parsedImageUrls = [json['imageUrl'] as String];
    }

    int parsedStock = -1;
    final rawStock = json['stockQuantity'];
    if (rawStock is int) {
      parsedStock = rawStock;
    } else if (rawStock is String) {
      parsedStock = int.tryParse(rawStock) ?? -1;
    }

    return Product(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id']?.toString() ?? '') ?? 0,
      price: parsedPrice,
      title: json['title'] ?? '',
      imageUrls: parsedImageUrls,
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
      if (docId != null) 'docId': docId,
      'price': price,
      'title': title,
      'imageUrls': imageUrls,
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
