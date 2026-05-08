import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:my_fashion_app/models/cartt.dart';
import 'package:my_fashion_app/models/product.dart';
import 'package:my_fashion_app/pages/product_detail_screen.dart';
import 'package:my_fashion_app/services/cart_provider.dart';
import 'package:my_fashion_app/services/product_service.dart';
import 'package:my_fashion_app/widgets/app_sliver_bar.dart';
import 'package:my_fashion_app/widgets/product_card.dart';
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

  final ProductService _productService = ProductService();
  final Set<String> _optimisticFavorites = <String>{};
  final Set<String> _optimisticRemovals = <String>{};

  // ── Favorites logic ───────────────────────────────────────────────────
  String _productKey(Product product) =>
      product.docId ?? product.id.toString();

  Stream<Set<String>> _favoriteIdsStream(String userId) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('favorites')
        .snapshots()
        .map((snap) => snap.docs.map((doc) => doc.id).toSet());
  }

  bool _isFavorite(Product product, Set<String> savedFavoriteIds) {
    final key = _productKey(product);
    if (_optimisticRemovals.contains(key)) return false;
    if (_optimisticFavorites.contains(key)) return true;
    return savedFavoriteIds.contains(key);
  }

  Future<void> _toggleFavorite(Product product, bool isFavorite) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى تسجيل الدخول لحفظ المنتجات في المفضلة.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final key = _productKey(product);
    final ref = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('favorites')
        .doc(key);

    setState(() {
      if (isFavorite) {
        _optimisticFavorites.remove(key);
        _optimisticRemovals.add(key);
      } else {
        _optimisticRemovals.remove(key);
        _optimisticFavorites.add(key);
      }
    });

    try {
      if (isFavorite) {
        await ref.delete();
      } else {
        await ref.set({
          ...product.toJson(),
          'docId': key,
          'savedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (isFavorite) {
          _optimisticRemovals.remove(key);
        } else {
          _optimisticFavorites.remove(key);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر تحديث المفضلة: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ── Cart logic ────────────────────────────────────────────────────────
  void _addToCart(Product product) {
    final cart = context.read<Cart>();
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

  // ── childAspectRatio computed from screen width ───────────────────────
  /// الارتفاع الثابت لقسم البيانات في الكارت = 102px
  /// (8 top + 32 title + 4 gap + 16 price + 6 gap + 28 btn + 8 bottom)
  double _cardRatio(BuildContext context) {
    const hPadding = 32.0; // 16 يسار + 16 يمين
    const hSpacing = 12.0; // المسافة بين العمودين
    const infoHeight = 102.0;
    final w = MediaQuery.of(context).size.width;
    final cardW = (w - hPadding - hSpacing) / 2;
    return cardW / (cardW + infoHeight);
  }

  // ── Build ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
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
        stream: _productService.getProductsStream(
            category: widget.categoryName),
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

          final products = productSnap.data ?? const <Product>[];
          final favStream = user == null
              ? Stream.value(<String>{})
              : _favoriteIdsStream(user.uid);

          return StreamBuilder<Set<String>>(
            stream: favStream,
            builder: (context, favSnap) {
              final favoriteIds = favSnap.data ?? <String>{};

              return CustomScrollView(
                slivers: [
                  sliverBar,
                  // Header subtitle
                  SliverToBoxAdapter(
                    child: Padding(
                      padding:
                          const EdgeInsets.fromLTRB(16, 16, 16, 4),
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

                  // ── Products Grid or Empty State ──
                  products.isEmpty
                      ? SliverFillRemaining(
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                    Icons.shopping_bag_outlined,
                                    color: Colors.white24,
                                    size: 72),
                                const SizedBox(height: 16),
                                Text(
                                  widget.categoryName == null
                                      ? 'لا توجد منتجات'
                                      : 'لا توجد منتجات في قسم ${widget.categoryName}',
                                  style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 16,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        )
                      : SliverPadding(
                          padding:
                              const EdgeInsets.fromLTRB(16, 12, 16, 24),
                          sliver: SliverGrid(
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: ratio,
                            ),
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final p = products[index];
                                final fav =
                                    _isFavorite(p, favoriteIds);
                                return ProductCard(
                                  product: p,
                                  isFavorite: fav,
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          ProductDetailScreen(
                                              product: p),
                                    ),
                                  ),
                                  onFavoriteToggle: () =>
                                      _toggleFavorite(p, fav),
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
          );
        },
      ),
    );
  }
}
