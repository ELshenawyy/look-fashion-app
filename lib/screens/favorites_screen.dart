import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:my_fashion_app/features/favorites/domain/entities/favorite_entity.dart';
import 'package:my_fashion_app/features/favorites/presentation/providers/favorites_provider.dart';
import 'package:my_fashion_app/models/cartt.dart';
import 'package:my_fashion_app/models/product.dart';
import 'package:my_fashion_app/pages/product_detail_screen.dart';
import 'package:my_fashion_app/features/cart/presentation/providers/cart_provider.dart';
import 'package:my_fashion_app/widgets/app_sliver_bar.dart';
import 'package:my_fashion_app/widgets/product_card.dart';
import 'package:provider/provider.dart';

/// شاشة المفضلة — لا تستدعي Firebase مباشرةً.
/// كل البيانات تأتي من FavoritesProvider الذي يستدعي use cases.
class FavoritesScreen extends StatefulWidget {
  final VoidCallback? onBrowseProducts;

  const FavoritesScreen({super.key, this.onBrowseProducts});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  static const Color _gold = Color(0xFFD4AF37);
  final Set<String> _removingIds = {};

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      // ابدأ مراقبة المفضلات فور فتح الشاشة
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<FavoritesProvider>().startWatching(uid);
      });
    }
  }

  // ── حذف مع تأثير fade ───────────────────────────────────────────────────
  Future<void> _removeFavorite(FavoriteEntity fav) async {
    final id = fav.productId;
    if (_removingIds.contains(id)) return;

    setState(() => _removingIds.add(id));
    await Future.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    await context.read<FavoritesProvider>().toggle(
          userId: uid,
          productId: id,
          title: fav.title,
          imageUrl: fav.imageUrl,
          price: fav.price,
        );

    if (!mounted) return;
    setState(() => _removingIds.remove(id));

    final failure = context.read<FavoritesProvider>().failure;
    if (failure != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(failure.message),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      context.read<FavoritesProvider>().clearFailure();
    }
  }

  // ── إضافة لـ السلة ──────────────────────────────────────────────────────
  void _addToCart(FavoriteEntity fav) {
    context.read<CartProvider>().addItem(CartItem(
          productId: fav.productId,
          name: fav.title,
          price: fav.price,
          image: fav.imageUrl,
          size: 'افتراضي',
          color: 'افتراضي',
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

  double _cardRatio(BuildContext context) {
    const hPadding = 32.0;
    const hSpacing = 12.0;
    const infoHeight = 102.0;
    final w = MediaQuery.of(context).size.width;
    final cardW = (w - hPadding - hSpacing) / 2;
    return cardW / (cardW + infoHeight);
  }

  static const AppSliverBar _appBar = AppSliverBar(
    title: 'المفضلة',
    actions: [NotificationBellAction()],
  );

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final ratio = _cardRatio(context);

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

    return Consumer<FavoritesProvider>(
      builder: (context, provider, _) {
        final products = provider.favorites;
        final failure = provider.failure;

        if (failure != null && products.isEmpty) {
          return CustomScrollView(
            slivers: [
              _appBar,
              SliverFillRemaining(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'حدث خطأ: ${failure.message}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  ),
                ),
              ),
            ],
          );
        }

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

        return CustomScrollView(
          slivers: [
            _appBar,
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
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
                          color: Colors.white54, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: ratio,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final fav = products[index];
                    final isRemoving = _removingIds.contains(fav.productId);
                    final productView = Product(
                      id: 0,
                      docId: fav.productId,
                      title: fav.title,
                      price: fav.price,
                      imageUrl: fav.imageUrl,
                      description: '',
                      gender: '',
                    );

                    return AnimatedOpacity(
                      opacity: isRemoving ? 0.0 : 1.0,
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeOut,
                      child: ProductCard(
                        product: productView,
                        isFavorite: true,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                ProductDetailScreen(product: productView),
                          ),
                        ),
                        onFavoriteToggle: () => _removeFavorite(fav),
                        onAddToCart: () => _addToCart(fav),
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
            OutlinedButton.icon(
              onPressed: onBrowse,
              icon: const Icon(Icons.explore_outlined, size: 18),
              label: const Text('تصفح المنتجات'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _gold,
                side: const BorderSide(color: _gold),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
