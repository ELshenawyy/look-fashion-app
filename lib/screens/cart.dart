import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:my_fashion_app/core/utils/color_utils.dart';
import 'package:my_fashion_app/features/products/presentation/providers/products_provider.dart';
import 'package:my_fashion_app/models/cartt.dart';
import 'package:my_fashion_app/features/cart/presentation/providers/cart_provider.dart';
import 'package:my_fashion_app/pages/product_detail_screen.dart';
import 'package:my_fashion_app/screens/checkout_screen.dart';
import 'package:my_fashion_app/widgets/app_sliver_bar.dart';
import 'package:my_fashion_app/widgets/blocking_loader.dart';

class CartPage extends StatelessWidget {
  const CartPage({super.key});

  static const Color _gold = Color(0xFFD4AF37);

  static const AppSliverBar _appBar = AppSliverBar(
    title: 'سلتي',
    actions: [NotificationBellAction()],
  );

  @override
  Widget build(BuildContext context) {
    return Consumer<CartProvider>(
      builder: (context, cart, child) {
        if (cart.items.isEmpty) {
          return CustomScrollView(
            slivers: [
              _appBar,
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 110,
                        height: 110,
                        decoration: BoxDecoration(
                          color: _gold.withValues(alpha: 0.08),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: _gold.withValues(alpha: 0.25), width: 1.5),
                        ),
                        child: const Icon(Icons.shopping_cart_outlined,
                            color: _gold, size: 52),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'السلة فارغة',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'أضف منتجات من المتجر لتظهر هنا',
                        style: TextStyle(color: Colors.white54, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        }

        return CustomScrollView(
          slivers: [
            _appBar,
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final item = cart.items[index];
                    return Padding(
                      padding: EdgeInsets.only(
                          bottom: index < cart.items.length - 1 ? 12 : 0),
                      child: _CartItemCard(item: item, index: index),
                    );
                  },
                  childCount: cart.items.length,
                ),
              ),
            ),
            SliverToBoxAdapter(child: _BottomBar(cart: cart)),
          ],
        );
      },
    );
  }
}

class _CartItemCard extends StatelessWidget {
  final CartItem item;
  final int index;

  static const Color _gold = Color(0xFFD4AF37);
  static const Color _maroon = Color(0xFF5A1010);
  static const Color _panel = Color(0xFF180808);

  const _CartItemCard({required this.item, required this.index});

  /// يفتح detail screen بـ edit mode — يحمّل المنتج الكامل من Firestore
  /// (للحصول على sizes/colors/stock الحالية)، ثم ينتقل بـ القيم الأولية
  /// من العنصر في السلة. عند الحفظ → يُستبدَل العنصر في نفس index.
  Future<void> _openInEditMode(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final product = await runWithBlockingLoader(
      context: context,
      action: () =>
          context.read<ProductsProvider>().getProductById(item.productId),
      message: 'جاري تحميل المنتج...',
    );

    if (!context.mounted) return;
    if (product == null) {
      messenger.showSnackBar(const SnackBar(
        content: Text('المنتج لم يعد متاحاً'),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductDetailScreen(
          product: product,
          editCartIndex: index,
          initialSize: item.size,
          initialColor: item.color,
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _panel,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('حذف المنتج', style: TextStyle(color: Colors.white)),
        content: Text(
          'هل تريد إزالة "${item.name}" من السلة؟',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('تراجع', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      Provider.of<CartProvider>(context, listen: false).removeItem(index);
    }
  }

  Widget _tag(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white60, fontSize: 12),
      ),
    );
  }

  Widget _quantityButton(
      {required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: _maroon,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: Colors.white, size: 16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final atStockLimit =
        item.stockQuantity > 0 && item.quantity >= item.stockQuantity;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        // ضغط الكارت → يفتح detail بـ edit mode (تعديل size/color)
        onTap: () => _openInEditMode(context),
        splashColor: _gold.withValues(alpha: 0.12),
        child: Ink(
          decoration: BoxDecoration(
            color: _panel,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white10),
          ),
          child: Row(
        children: [
          // Product image
          LayoutBuilder(
            builder: (context, constraints) {
              final imgSize =
                  (MediaQuery.of(context).size.width * 0.24).clamp(80.0, 110.0);
              return ClipRRect(
                borderRadius:
                    const BorderRadius.horizontal(left: Radius.circular(16)),
                child: CachedNetworkImage(
                  imageUrl: item.image,
                  width: imgSize,
                  height: imgSize,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Shimmer.fromColors(
                    baseColor: const Color(0xFF1E1E1E),
                    highlightColor: const Color(0xFF2A2A2A),
                    child:
                        SizedBox(width: imgSize, height: imgSize),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    width: imgSize,
                    height: imgSize,
                    color: Colors.grey[900],
                    child: const Icon(Icons.image_not_supported,
                        color: Colors.white24),
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 12),
          // Product info
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      if (item.size != 'افتراضي') _tag(item.size),
                      if (item.color != 'افتراضي')
                        _tag(ColorUtils.displayLabel(item.color)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${item.price.toStringAsFixed(2)} ج.س',
                    style: const TextStyle(
                      color: _gold,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  // Stock limit hint
                  if (atStockLimit)
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Text(
                        'وصلت للحد الأقصى المتاح',
                        style: TextStyle(color: Colors.orange, fontSize: 11),
                      ),
                    ),
                ],
              ),
            ),
          ),
          // Actions column
          Column(
            children: [
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    color: Colors.red, size: 20),
                onPressed: () => _confirmDelete(context),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _quantityButton(
                    icon: Icons.remove,
                    onTap: () => Provider.of<CartProvider>(context, listen: false)
                        .decrementQuantity(index),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      '${item.quantity}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  _quantityButton(
                    icon: Icons.add,
                    onTap: atStockLimit
                        ? () {} // زر معطّل بصرياً
                        : () => Provider.of<CartProvider>(context, listen: false)
                            .incrementQuantity(index),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  final CartProvider cart;

  static const Color _gold = Color(0xFFD4AF37);
  static const Color _panel = Color(0xFF180808);

  const _BottomBar({required this.cart});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      decoration: const BoxDecoration(
        color: _panel,
        border: Border(top: BorderSide(color: Colors.white10)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'الإجمالي',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
              Text(
                '${cart.totalPrice.toStringAsFixed(2)} ج.س',
                style: const TextStyle(
                  color: _gold,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CheckoutScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _gold,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: const Text('إتمام الطلب'),
            ),
          ),
        ],
      ),
    );
  }
}
