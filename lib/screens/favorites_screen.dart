import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:my_fashion_app/models/cartt.dart';
import 'package:my_fashion_app/models/product.dart';
import 'package:my_fashion_app/pages/product_detail_screen.dart';
import 'package:my_fashion_app/services/cart_provider.dart';
import 'package:my_fashion_app/widgets/app_sliver_bar.dart';
import 'package:my_fashion_app/widgets/product_card.dart';
import 'package:provider/provider.dart';

class FavoritesScreen extends StatefulWidget {
  /// يُستدعى عند الضغط على "تصفح المنتجات" لتبديل التبويب للرئيسية
  final VoidCallback? onBrowseProducts;

  const FavoritesScreen({super.key, this.onBrowseProducts});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  static const Color _gold = Color(0xFFD4AF37);

  /// IDs التي يجري حذفها حاليًا — تُستخدم لتأثير التلاشي
  final Set<String> _removingIds = {};

  // ── Firestore stream ──────────────────────────────────────────────────
  Stream<List<Product>> _favoritesStream(String userId) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('favorites')
        .orderBy('savedAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs.map((doc) {
            final data = doc.data();
            return Product.fromJson({
              ...data,
              'docId': data['docId'] ?? doc.id,
            });
          }).toList(),
        );
  }

  // ── Remove with animation ─────────────────────────────────────────────
  Future<void> _removeFavorite(Product product) async {
    final id = product.docId ?? product.id.toString();
    if (_removingIds.contains(id)) return; // منع النقر المزدوج

    // 1. بدء تأثير التلاشي
    setState(() => _removingIds.add(id));

    // 2. الانتظار حتى تنتهي الأنيميشن (350ms)
    await Future.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;

    // 3. الحذف من Firestore — سيُحدَّث الـ stream تلقائيًا
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('favorites')
          .doc(id)
          .delete();
    } catch (e) {
      if (!mounted) return;
      setState(() => _removingIds.remove(id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر إزالة المنتج من المفضلة: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ── Cart ──────────────────────────────────────────────────────────────
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

  // ── childAspectRatio ──────────────────────────────────────────────────
  double _cardRatio(BuildContext context) {
    const hPadding = 32.0;
    const hSpacing = 12.0;
    const infoHeight = 102.0;
    final w = MediaQuery.of(context).size.width;
    final cardW = (w - hPadding - hSpacing) / 2;
    return cardW / (cardW + infoHeight);
  }

  // ── App bar (static since it has no deps) ─────────────────────────────
  static const AppSliverBar _appBar = AppSliverBar(
    title: 'المفضلة',
    actions: [NotificationBellAction()],
  );

  // ── Build ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final ratio = _cardRatio(context);

    // ── Not logged in ──
    if (user == null) {
      return CustomScrollView(
        slivers: [
          _appBar,
          SliverFillRemaining(
            child: _EmptyState(
              icon: Icons.person_outline_rounded,
              title: 'يرجى تسجيل الدخول',
              subtitle: 'سجّل دخولك لترى منتجاتك المفضلة',
              onBrowse: widget.onBrowseProducts,
            ),
          ),
        ],
      );
    }

    return StreamBuilder<List<Product>>(
      stream: _favoritesStream(user.uid),
      builder: (context, snapshot) {
        // ── Loading ──
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CustomScrollView(
            slivers: [
              _appBar,
              SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(color: _gold),
                ),
              ),
            ],
          );
        }

        // ── Error ──
        if (snapshot.hasError) {
          return CustomScrollView(
            slivers: [
              _appBar,
              SliverFillRemaining(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'حدث خطأ: ${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  ),
                ),
              ),
            ],
          );
        }

        final products = snapshot.data ?? const <Product>[];

        // ── Empty state ──
        if (products.isEmpty) {
          return CustomScrollView(
            slivers: [
              _appBar,
              SliverFillRemaining(
                child: _EmptyState(
                  icon: Icons.favorite_border_rounded,
                  title: 'قائمة المفضلة فارغة',
                  subtitle: 'احفظ القطع التي تعجبك\nوارجع إليها في أي وقت',
                  onBrowse: widget.onBrowseProducts,
                ),
              ),
            ],
          );
        }

        // ── Grid ──
        return CustomScrollView(
          slivers: [
            _appBar,
            // Header
            SliverToBoxAdapter(
              child: Padding(
                padding:
                    const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'منتجاتك المفضلة',
                      style: TextStyle(
                        color: _gold,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${products.length} منتج محفوظ',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Grid
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
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
                    final id = p.docId ?? p.id.toString();
                    final isRemoving = _removingIds.contains(id);

                    return AnimatedOpacity(
                      opacity: isRemoving ? 0.0 : 1.0,
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeOut,
                      child: ProductCard(
                        product: p,
                        isFavorite: true, // دائمًا في المفضلة
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                ProductDetailScreen(product: p),
                          ),
                        ),
                        onFavoriteToggle: () => _removeFavorite(p),
                        onAddToCart: () => _addToCart(p),
                      ),
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
  }
}

// ── Empty State Widget ────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onBrowse,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onBrowse;

  static const Color _gold = Color(0xFFD4AF37);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Animated heart container
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: _gold.withValues(alpha: 0.08),
                shape: BoxShape.circle,
                border: Border.all(
                    color: _gold.withValues(alpha: 0.25), width: 1.5),
              ),
              child: Icon(icon, color: _gold, size: 48),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 14,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 32),
            // CTA
            OutlinedButton.icon(
              onPressed: onBrowse,
              icon: const Icon(Icons.explore_outlined, size: 18),
              label: const Text('تصفح المنتجات'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _gold,
                side: const BorderSide(color: _gold),
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
