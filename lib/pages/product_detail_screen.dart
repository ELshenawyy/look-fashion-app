import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:my_fashion_app/models/product.dart';
import 'package:my_fashion_app/models/cartt.dart';
import 'package:my_fashion_app/services/cart_provider.dart';

class ProductDetailScreen extends StatefulWidget {
  final Product product;

  const ProductDetailScreen({Key? key, required this.product}) : super(key: key);

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  static const Color _gold = Color(0xFFD4AF37);
  static const Color _maroon = Color(0xFF5A1010);
  static const Color _panel = Color(0xFF180808);

  late final Product product;
  String? _selectedSize;
  String? _selectedColor;

  @override
  void initState() {
    super.initState();
    product = widget.product;
    _selectedSize = product.sizes.isNotEmpty ? product.sizes.first : null;
    _selectedColor = product.colors.isNotEmpty ? product.colors.first : null;
  }

  Color _resolveColor(String colorName) {
    switch (colorName.toLowerCase()) {
      case 'black':
        return Colors.black;
      case 'white':
        return Colors.white;
      case 'red':
        return const Color(0xFFC62828);
      case 'blue':
        return const Color(0xFF0D47A1);
      case 'maroon':
        return _maroon;
      case 'gold':
        return _gold;
      case 'grey':
      case 'gray':
        return const Color(0xFF8E8E8E);
      default:
        return const Color(0xFF616161);
    }
  }

  void _handleAddToCart() {
    if (product.sizes.isNotEmpty && _selectedSize == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى اختيار المقاس أولًا.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (product.colors.isNotEmpty && _selectedColor == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى اختيار اللون أولًا.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final chosenColor = _selectedColor ?? 'افتراضي';
    final chosenSize = _selectedSize ?? 'افتراضي';

    final cartItem = CartItem(
      productId: product.docId ?? product.id.toString(),
      name: product.title,
      price: product.price,
      image: product.imageUrl,
      size: chosenSize,
      color: chosenColor,
    );

    Provider.of<Cart>(context, listen: false).addItem(cartItem);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'تمت إضافة ${product.title} إلى السلة.',
        ),
        backgroundColor: const Color(0xFF2E7D32),
        action: SnackBarAction(
          label: 'عرض السلة',
          textColor: Colors.white,
          onPressed: () => Navigator.pop(context),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: _gold,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _buildSizeOption(String size) {
    final isSelected = _selectedSize == size;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedSize = size;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.black : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? _gold : Colors.white24,
            width: isSelected ? 2.2 : 1.1,
          ),
        ),
        child: Text(
          size,
          style: TextStyle(
            color: isSelected ? _gold : Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildColorOption(String colorName) {
    final colorValue = _resolveColor(colorName);
    final isSelected = _selectedColor == colorName;
    final isLightColor =
        ThemeData.estimateBrightnessForColor(colorValue) == Brightness.light;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedColor = colorName;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? _gold : Colors.white24,
            width: isSelected ? 2.2 : 1.1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: colorValue,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? _gold
                      : (colorName.toLowerCase() == 'white'
                          ? Colors.white60
                          : Colors.white24),
                  width: isSelected ? 2.6 : 1.1,
                ),
              ),
              child: isSelected
                  ? Icon(
                      Icons.check_rounded,
                      color: isLightColor ? Colors.black : Colors.white,
                    )
                  : null,
            ),
            const SizedBox(height: 8),
            Text(
              colorName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          product.title,
          style: const TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: _gold,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            AspectRatio(
              aspectRatio: 1.05,
              child: Image.network(
                product.imageUrl,
                width: double.infinity,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    color: Colors.grey[300],
                    alignment: Alignment.center,
                    child: CircularProgressIndicator(
                      color: _gold,
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null,
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey[300],
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.image_not_supported,
                      color: Colors.grey[600],
                      size: 50,
                    ),
                  );
                },
              ),
            ),
            Transform.translate(
              offset: const Offset(0, -26),
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: _panel,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                ),
                padding: const EdgeInsets.fromLTRB(24, 26, 24, 34),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Text(
                        product.title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: _gold,
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${product.price.toStringAsFixed(2)} ج.م',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: Text(
                            'المخزون: ${product.stockQuantity}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    if (product.colors.isNotEmpty) ...[
                      _buildSectionTitle('اللون'),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: product.colors.map(_buildColorOption).toList(),
                      ),
                      const SizedBox(height: 24),
                    ],
                    if (product.sizes.isNotEmpty) ...[
                      _buildSectionTitle('المقاس'),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: product.sizes.map(_buildSizeOption).toList(),
                      ),
                      const SizedBox(height: 24),
                    ],
                    _buildSectionTitle('الوصف'),
                    const SizedBox(height: 10),
                    Text(
                      product.description,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 15,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _handleAddToCart,
                        icon: const Icon(Icons.shopping_cart_checkout_rounded),
                        label: const Text('إضافة إلى السلة'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _gold,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
