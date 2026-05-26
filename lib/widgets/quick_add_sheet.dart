import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import 'package:my_fashion_app/constants/category_constants.dart';
import 'package:my_fashion_app/core/utils/color_utils.dart';
import 'package:my_fashion_app/features/cart/presentation/providers/cart_provider.dart';
import 'package:my_fashion_app/models/cartt.dart';
import 'package:my_fashion_app/models/product.dart';

/// يفتح bottom sheet للاختيار السريع (size + color + qty)
/// قبل إضافة المنتج للسلة. يُستخدم من زر "+" في بطاقة المنتج
/// عندما يكون المنتج له variants فعلية أو فئته تتطلبهم.
Future<void> showQuickAddSheet(BuildContext context, Product product) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => QuickAddSheet(product: product),
  );
}

class QuickAddSheet extends StatefulWidget {
  final Product product;
  const QuickAddSheet({super.key, required this.product});

  @override
  State<QuickAddSheet> createState() => _QuickAddSheetState();
}

class _QuickAddSheetState extends State<QuickAddSheet> {
  static const Color _gold = Color(0xFFD4AF37);
  static const Color _panel = Color(0xFF180808);
  static const Color _bg = Color(0xFF0A0A0A);

  String? _selectedSize;
  String? _selectedColor;
  int _qty = 1;

  bool get _canAdd {
    if (widget.product.sizes.isNotEmpty && _selectedSize == null) {
      return false;
    }
    if (widget.product.colors.isNotEmpty && _selectedColor == null) {
      return false;
    }
    return true;
  }

  void _add() {
    final p = widget.product;
    final cart = context.read<CartProvider>();
    cart.addItem(CartItem(
      productId: p.docId ?? '',
      name: p.title,
      price: p.price,
      image: p.imageUrl,
      size: _selectedSize ?? 'افتراضي',
      color: _selectedColor ?? 'افتراضي',
      productState: p.state,
      stockQuantity: p.stockQuantity,
      quantity: _qty,
    ));
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تمت إضافة "${p.title}" إلى السلة'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _incrementQty() {
    final maxStock = widget.product.stockQuantity;
    if (maxStock > 0 && _qty >= maxStock) return;
    setState(() => _qty++);
  }

  void _decrementQty() {
    if (_qty <= 1) return;
    setState(() => _qty--);
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: const BoxDecoration(
          color: _bg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black54,
              blurRadius: 20,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Drag handle ──
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // ── Product header (image + name + price) ──
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: 64,
                        height: 64,
                        child: p.imageUrl.isEmpty
                            ? Container(
                                color: _panel,
                                child: const Icon(Icons.image_outlined,
                                    color: Colors.white24),
                              )
                            : CachedNetworkImage(
                                imageUrl: p.imageUrl,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => Shimmer.fromColors(
                                  baseColor: const Color(0xFF1E1E1E),
                                  highlightColor: const Color(0xFF2A2A2A),
                                  child: Container(color: Colors.black),
                                ),
                                errorWidget: (_, __, ___) => Container(
                                  color: _panel,
                                  child: const Icon(
                                      Icons.broken_image_outlined,
                                      color: Colors.white24),
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${p.price.toStringAsFixed(0)} ج.س',
                            style: const TextStyle(
                              color: _gold,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                if (p.stockQuantity > 0 && p.stockQuantity <= 10) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: Colors.orange.withValues(alpha: 0.5)),
                    ),
                    child: Text(
                      'كمية محدودة — متبقي ${p.stockQuantity}',
                      style: const TextStyle(
                        color: Colors.orange,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],

                // ── Size selector ──
                if (p.sizes.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text(
                    sizeLabelForCategory(p.category),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: p.sizes.map((size) {
                      final active = size == _selectedSize;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedSize = size),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 9),
                          decoration: BoxDecoration(
                            color: active ? _gold : _panel,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: active
                                  ? _gold
                                  : Colors.white.withValues(alpha: 0.15),
                            ),
                          ),
                          child: Text(
                            size,
                            style: TextStyle(
                              color: active ? Colors.black : Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],

                // ── Color selector ──
                if (p.colors.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  const Text(
                    'اللون',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: p.colors.map((code) {
                      final color = ColorUtils.parse(code);
                      final active = code == _selectedColor;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedColor = code),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: active ? _gold : Colors.white24,
                              width: active ? 3 : 1.5,
                            ),
                            boxShadow: active
                                ? [
                                    BoxShadow(
                                      color:
                                          _gold.withValues(alpha: 0.5),
                                      blurRadius: 8,
                                    ),
                                  ]
                                : null,
                          ),
                          child: active
                              ? Icon(
                                  Icons.check,
                                  size: 18,
                                  color: color.computeLuminance() > 0.5
                                      ? Colors.black
                                      : Colors.white,
                                )
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                  if (_selectedColor != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      ColorUtils.displayLabel(_selectedColor!),
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],

                // ── Quantity selector ──
                const SizedBox(height: 20),
                Row(
                  children: [
                    const Text(
                      'الكمية',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      decoration: BoxDecoration(
                        color: _panel,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.15)),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: _qty > 1 ? _decrementQty : null,
                            icon: const Icon(Icons.remove, size: 18),
                            color: Colors.white,
                            disabledColor: Colors.white24,
                            constraints: const BoxConstraints(
                                minWidth: 36, minHeight: 36),
                            padding: EdgeInsets.zero,
                          ),
                          Container(
                            width: 36,
                            alignment: Alignment.center,
                            child: Text(
                              '$_qty',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: (p.stockQuantity == 0 ||
                                    _qty < p.stockQuantity)
                                ? _incrementQty
                                : null,
                            icon: const Icon(Icons.add, size: 18),
                            color: Colors.white,
                            disabledColor: Colors.white24,
                            constraints: const BoxConstraints(
                                minWidth: 36, minHeight: 36),
                            padding: EdgeInsets.zero,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // ── Add to cart button ──
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _canAdd ? _add : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _gold,
                      disabledBackgroundColor:
                          Colors.white.withValues(alpha: 0.08),
                      foregroundColor: Colors.black,
                      disabledForegroundColor: Colors.white24,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.shopping_bag_outlined, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          _canAdd
                              ? 'أضف للسلة'
                              : 'اختر ${_selectedSize == null && p.sizes.isNotEmpty ? sizeLabelForCategory(p.category) : "اللون"}',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
