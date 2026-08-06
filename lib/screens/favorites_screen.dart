import 'package:flutter/material.dart';
import 'package:my_fashion_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:my_fashion_app/features/favorites/domain/entities/favorite_entity.dart';
import 'package:my_fashion_app/features/favorites/presentation/providers/favorites_provider.dart';
import 'package:my_fashion_app/features/products/presentation/providers/products_provider.dart';
import 'package:my_fashion_app/models/product.dart';
import 'package:my_fashion_app/pages/product_detail_screen.dart';
import 'package:my_fashion_app/widgets/app_sliver_bar.dart';
import 'package:my_fashion_app/widgets/blocking_loader.dart';
import 'package:my_fashion_app/widgets/product_card.dart';
import 'package:my_fashion_app/widgets/quick_add_sheet.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

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
    final uid = context.read<AuthProvider>().user?.uid;
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

    final uid = context.read<AuthProvider>().user?.uid;
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

  // ── إضافة للسلة عبر Bottom Sheet ────────────────────────────────────────
  Future<void> _showQuickAdd(FavoriteEntity fav) async {
    final product = await runWithBlockingLoader<Product?>(
      context: context,
      action: () =>
          context.read<ProductsProvider>().getProductById(fav.productId),
      message: 'جاري التحميل...',
    );
    if (!mounted) return;
    if (product == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('المنتج لم يعد متاحاً'),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    showQuickAddSheet(context, product);
  }

  // ── فتح صفحة التفاصيل ─────────────────────────────────────────────────
  Future<void> _openDetail(FavoriteEntity fav) async {
    final messenger = ScaffoldMessenger.of(context);
    final product = await runWithBlockingLoader<Product?>(
      context: context,
      action: () =>
          context.read<ProductsProvider>().getProductById(fav.productId),
      message: 'جاري التحميل...',
    );

    if (!mounted) return;
    if (product == null) {
      messenger.showSnackBar(const SnackBar(
        content: Text('المنتج لم يعد متاحاً'),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductDetailScreen(product: product),
      ),
    );
  }

  double _cardRatio(BuildContext context) {
    const hPadding = 32.0;
    const hSpacing = 12.0;
    const infoHeight = 110.0;
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
    final user = context.watch<AuthProvider>().user;
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

        // ── Loading: Shimmer placeholders بدل الـ red flash ─────────────
        if (provider.isLoading && products.isEmpty && failure == null) {
          return CustomScrollView(
            slivers: [
              _appBar,
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: ratio,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (_, __) => const _ShimmerFavoriteCard(),
                    childCount: 4,
                  ),
                ),
              ),
            ],
          );
        }

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
                  crossAxisCount: MediaQuery.of(context).size.width >= 900
                      ? 4
                      : MediaQuery.of(context).size.width >= 600
                          ? 3
                          : 2,
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
                      imageUrls:
                          fav.imageUrl.isNotEmpty ? [fav.imageUrl] : const [],
                      description: '',
                      gender: '',
                    );

                    return AnimatedOpacity(
                      opacity: isRemoving ? 0.0 : 1.0,
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeOut,
                      child: ProductCard(
                        product: productView,
                        onTap: () => _openDetail(fav),
                        onFavoriteToggle: () => _removeFavorite(fav),
                        onAddToCart: () => _showQuickAdd(fav),
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

/// Shimmer placeholder — يظهر أثناء تحميل المفضلات بدل الوميض الأبيض.
class _ShimmerFavoriteCard extends StatelessWidget {
  const _ShimmerFavoriteCard();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFF1A1A1A),
      highlightColor: const Color(0xFF2A2A2A),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFF1A1A1A),
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(12)),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                      height: 12,
                      width: double.infinity,
                      color: const Color(0xFF2A2A2A)),
                  const SizedBox(height: 6),
                  Container(
                      height: 10,
                      width: 80,
                      color: const Color(0xFF2A2A2A)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
