import 'package:flutter/material.dart';
import 'package:my_fashion_app/models/cartt.dart';
import 'package:my_fashion_app/models/product.dart';
import 'package:my_fashion_app/pages/product_detail_screen.dart';
import 'package:my_fashion_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:my_fashion_app/features/cart/presentation/providers/cart_provider.dart';
import 'package:my_fashion_app/features/favorites/presentation/providers/favorites_provider.dart';
import 'package:my_fashion_app/features/products/domain/usecases/watch_products.dart';
import 'package:my_fashion_app/core/di/injection_container.dart';
import 'package:my_fashion_app/constants/category_constants.dart';
import 'package:my_fashion_app/widgets/app_sliver_bar.dart';
import 'package:my_fashion_app/widgets/product_card.dart';
import 'package:my_fashion_app/widgets/quick_add_sheet.dart';
import 'package:provider/provider.dart';

class ProductListingPage extends StatefulWidget {
  final String? categoryName;

  const ProductListingPage({
    super.key,
    this.categoryName,
  });

  @override
  State<ProductListingPage> createState() => _ProductListingPageState();
}

class _ProductListingPageState extends State<ProductListingPage> {
  static const Color _gold = Color(0xFFD4AF37);

  final WatchProducts _watchProducts = sl<WatchProducts>();
  // ── Favorites logic — يستخدم FavoritesProvider مع Selector ──────────
  // لا StreamBuilder، لا optimistic sets، لا setState عند toggle
  // → فقط أيقونة كل كارت تُعاد بناؤها عبر Selector الموجود في ProductCard
  Future<void> _toggleFavorite(Product product) async {
    final uid = context.read<AuthProvider>().user?.uid;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى تسجيل الدخول لحفظ المنتجات في المفضلة.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final fav = context.read<FavoritesProvider>();
    await fav.toggle(
      userId: uid,
      productId: product.docId ?? product.id.toString(),
      title: product.title,
      imageUrl: product.imageUrl,
      price: product.price,
    );
  }

  // ── Cart logic ────────────────────────────────────────────────────────
  /// نفس منطق `_quickAddToCart` في product_list_screen — يفتح
  /// QuickAddSheet للمنتجات اللي تحتاج اختيار size/color، ويُضيف
  /// مباشرة للمنتجات بدون variants (عطور، تجميل، إلكترونيات).
  void _addToCart(Product product) {
    if (_productNeedsSelection(product)) {
      showQuickAddSheet(context, product);
      return;
    }

    final cart = context.read<CartProvider>();
    cart.addItem(CartItem(
      productId: product.docId ?? '',
      name: product.title,
      price: product.price,
      image: product.imageUrl,
      size: product.sizes.isNotEmpty ? product.sizes.first : 'افتراضي',
      color: product.colors.isNotEmpty ? product.colors.first : 'افتراضي',
      productState: product.state,
      stockQuantity: product.stockQuantity,
      quantity: 1,
    ));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تمت الإضافة إلى السلة'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 1),
      ),
    );
  }

  bool _productNeedsSelection(Product p) {
    return kCategoriesWithVariants.contains(p.category) ||
        p.sizes.length > 1 ||
        p.colors.length > 1;
  }

  // ── childAspectRatio computed from screen width ───────────────────────
  /// الارتفاع الثابت لقسم البيانات في الكارت = 102px
  /// (8 top + 32 title + 4 gap + 16 price + 6 gap + 28 btn + 8 bottom)
  // عدد الأعمدة حسب عرض الشاشة
  int _crossAxisCount(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    if (w >= 900) return 4;
    if (w >= 600) return 3;
    return 2;
  }

  double _cardRatio(BuildContext context) {
    const hPadding = 32.0;
    const hSpacing = 12.0;
    const infoHeight = 102.0;
    final w = MediaQuery.of(context).size.width;
    final cols = _crossAxisCount(context);
    final cardW = (w - hPadding - (hSpacing * (cols - 1))) / cols;
    return cardW / (cardW + infoHeight);
  }

  // ── Build ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    // user غير مستخدم هنا — FavoritesProvider يتولى الـ auth
    final title = widget.categoryName ?? 'كل المنتجات';
    final ratio = _cardRatio(context);

    final sliverBar = AppSliverBar(
      title: title,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _gold),
        onPressed: () => Navigator.of(context).pop(),
      ),
      automaticallyImplyLeading: false,
    );

    return Scaffold(
      backgroundColor: Colors.black,
      body: StreamBuilder<List<Product>>(
        stream: _watchProducts(category: widget.categoryName),
        builder: (context, productSnap) {
          // ── Loading ──
          if (productSnap.connectionState == ConnectionState.waiting) {
            return CustomScrollView(slivers: [
              sliverBar,
              const SliverFillRemaining(
                child: Center(
                    child: CircularProgressIndicator(color: _gold)),
              ),
            ]);
          }

          // ── Error ──
          if (productSnap.hasError) {
            return CustomScrollView(slivers: [
              sliverBar,
              SliverFillRemaining(
                child: Center(
                  child: Text('حدث خطأ: ${productSnap.error}',
                      style:
                          const TextStyle(color: Colors.redAccent)),
                ),
              ),
            ]);
          }

          // ⚡ لا StreamBuilder هنا — كل ProductCard يستخدم
          // Selector<FavoritesProvider, bool> داخلياً → فقط
          // أيقونة المفضلة الخاصة بالمنتج تُعاد بناؤها عند التغيير
          final products = productSnap.data ?? const <Product>[];

          return CustomScrollView(
            slivers: [
              sliverBar,
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'اختر القطعة التي تناسبك',
                        style: TextStyle(
                          color: _gold,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${products.length} منتج متاح',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              products.isEmpty
                  ? SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.shopping_bag_outlined,
                                color: Colors.white24, size: 72),
                            const SizedBox(height: 16),
                            Text(
                              widget.categoryName == null
                                  ? 'لا توجد منتجات'
                                  : 'لا توجد منتجات في قسم ${widget.categoryName}',
                              style: const TextStyle(
                                  color: Colors.white54, fontSize: 16),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  : SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      sliver: SliverGrid(
                        gridDelegate:
                            SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: _crossAxisCount(context),
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: ratio,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final p = products[index];
                            return ProductCard(
                              product: p,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      ProductDetailScreen(product: p),
                                ),
                              ),
                              onFavoriteToggle: () => _toggleFavorite(p),
                              onAddToCart: () => _addToCart(p),
                            );
                          },
                          childCount: products.length,
                        ),
                      ),
                    ),
            ],
          );
        },
      ),
    );
  }
}
