import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:my_fashion_app/constants/banner_constants.dart';
import 'package:my_fashion_app/constants/category_constants.dart';
import 'package:my_fashion_app/features/home/presentation/providers/home_ui_provider.dart';
import 'package:my_fashion_app/models/cartt.dart';
import 'package:my_fashion_app/models/product.dart';
import 'package:my_fashion_app/pages/product_detail_screen.dart';
import 'package:my_fashion_app/features/products/presentation/providers/products_provider.dart';
import 'package:my_fashion_app/features/cart/presentation/providers/cart_provider.dart';
import 'package:my_fashion_app/widgets/app_sliver_bar.dart';
import 'package:my_fashion_app/widgets/quick_add_sheet.dart';
import 'package:my_fashion_app/widgets/user_avatar.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:speech_to_text/speech_to_text.dart';

class ProductListScreen extends StatefulWidget {
  const ProductListScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _ProductListScreenState createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  static const Color _gold = Color(0xFFD4AF37);
  static const Color _panel = Color(0xFF180808);

  // ── Banner ────────────────────────────────────────────────────────────
  // قائمة الصور في lib/constants/banner_constants.dart (kBannerImages).
  // الـ banner page index في HomeUIProvider (notifier) بدل setState.
  late Timer _bannerTimer;
  final PageController _bannerController = PageController();

  // ── Scroll ────────────────────────────────────────────────────────────
  final ScrollController _scrollController = ScrollController();

  // ── Search ────────────────────────────────────────────────────────────
  final TextEditingController _searchController = TextEditingController();

  // ── Voice Search ──────────────────────────────────────────────────────
  // حالة _isListening في HomeUIProvider (notifier) بدل setState.
  final SpeechToText _speech = SpeechToText();

  // ── Lifecycle ─────────────────────────────────────────────────────────
  ProductsProvider? _productsProviderRef;
  VoidCallback? _productsListener;

  @override
  void initState() {
    super.initState();

    _bannerTimer = Timer.periodic(const Duration(seconds: 4), _onBannerTick);
    _scrollController.addListener(_onScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<ProductsProvider>();
      _productsProviderRef = provider;

      // ⚠️ Sync controller مع provider state — إذا تم reset (signOut)
      // → searchQuery يصبح '' → نُفرغ controller text لمنع تسرّب فلتر
      // الحساب القديم (مثلاً "أطفال" تظل في خانة البحث).
      _productsListener = () {
        if (!mounted) return;
        if (provider.searchQuery.isEmpty &&
            _searchController.text.isNotEmpty) {
          _searchController.clear();
        }
      };
      provider.addListener(_productsListener!);
      provider.init();
    });
  }

  void _onBannerTick(Timer _) {
    if (!mounted || !_bannerController.hasClients) return;
    final currentIndex = context.read<HomeUIProvider>().bannerIndex;
    final next = (currentIndex + 1) % kBannerImages.length;
    _bannerController.animateToPage(
      next,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  /// يُعاد تشغيل الـ Timer عند أي تفاعل يدوي حتى لا يفرض الـ auto-scroll
  /// نفسه فوراً بعد سحب المستخدم.
  void _restartBannerTimer() {
    _bannerTimer.cancel();
    _bannerTimer = Timer.periodic(const Duration(seconds: 4), _onBannerTick);
  }

  @override
  void dispose() {
    if (_productsListener != null && _productsProviderRef != null) {
      _productsProviderRef!.removeListener(_productsListener!);
    }
    _bannerTimer.cancel();
    _bannerController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    _speech.stop();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 300) {
      context.read<ProductsProvider>().loadMore();
    }
  }

  // ── Voice Search ──────────────────────────────────────────────────────
  Future<void> _startListening() async {
    final isAvailable = await _speech.initialize(
      onStatus: (status) {
        if (!mounted) return;
        context
            .read<HomeUIProvider>()
            .setListening(status == 'listening');
      },
      onError: (error) {
        if (!mounted) return;
        context.read<HomeUIProvider>().setListening(false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'عذراً، حدث خطأ في التعرف على الصوت. تحقق من صلاحيات الميكروفون.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
    );

    if (!isAvailable) {
      if (mounted) await _showSpeechPermissionDialog();
      return;
    }

    _speech.listen(onResult: (result) {
      if (!mounted) return;
      final words = result.recognizedWords;
      // TextEditingController له notifier خاص — لا يحتاج Provider
      _searchController.text = words;
      _searchController.selection =
          TextSelection.fromPosition(TextPosition(offset: words.length));
      context.read<ProductsProvider>().setSearchQuery(words);
    });
  }

  void _stopListening() {
    _speech.stop();
    if (!mounted) return;
    context.read<HomeUIProvider>().setListening(false);
  }

  Future<void> _showSpeechPermissionDialog() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ترخيص الميكروفون مطلوب'),
        content: const Text(
            'التعرف الصوتي غير مفعل. الرجاء السماح بالوصول إلى الميكروفون من إعدادات التطبيق ثم إعادة المحاولة.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _startListening();
            },
            child: const Text('إعادة المحاولة'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  // ── Quick Add to Cart ─────────────────────────────────────────────────
  /// إذا المنتج له variants فعلية (مقاس/لون متعدد) أو فئته من
  /// `kCategoriesWithVariants` → نفتح bottom sheet للاختيار.
  /// خلاف ذلك (عطور، تجميل، إلكترونيات...) → إضافة فورية.
  void _quickAddToCart(Product product) {
    if (_productNeedsSelection(product)) {
      showQuickAddSheet(context, product);
      return;
    }

    // Path سريع للمنتجات بلا variants
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

  // ── Build ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Consumer<ProductsProvider>(
      builder: (context, provider, _) {
        return RefreshIndicator(
          color: _gold,
          backgroundColor: _panel,
          onRefresh: provider.refresh,
          child: CustomScrollView(
            controller: _scrollController,
            slivers: [
              _buildAppBar(),
              SliverToBoxAdapter(child: _buildSearchBar(provider)),
              SliverToBoxAdapter(child: _buildBanner()),
              SliverToBoxAdapter(
                child: _buildSectionHeader('تسوق حسب الفئة'),
              ),
              SliverToBoxAdapter(child: _buildCategories(provider)),
              SliverToBoxAdapter(child: _buildSortTabs(provider)),
              if (provider.isLoading)
                SliverToBoxAdapter(child: _buildShimmerGrid())
              else if (provider.failure != null)
                SliverToBoxAdapter(child: _buildErrorState(provider))
              else if (provider.products.isEmpty)
                SliverToBoxAdapter(child: _buildEmptyState())
              else
                _buildProductGrid(provider.products),
              if (provider.isLoadingMore)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(
                      child: CircularProgressIndicator(color: _gold),
                    ),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          ),
        );
      },
    );
  }

  // ── AppBar ────────────────────────────────────────────────────────────
  SliverAppBar _buildAppBar() {
    final user = FirebaseAuth.instance.currentUser;

    return SliverAppBar(
      backgroundColor: Colors.black,
      floating: true,
      snap: true,
      toolbarHeight: 64,
      automaticallyImplyLeading: false,
      title: Row(
        children: [
          // ── Avatar — ديناميكي من Firestore ──────────────────────────
          const UserAvatarWidget(radius: 20),
          const SizedBox(width: 10),
          // ── Greeting — ديناميكي من Firestore ────────────────────────
          if (user != null)
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .snapshots(),
              builder: (_, snap) {
                final data = snap.data?.data();
                final fullName = data?['name'] as String? ??
                    user.displayName ?? '';
                final first = fullName.trim().isNotEmpty
                    ? fullName.trim().split(' ').first
                    : 'أهلاً';
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'مرحباً، $first',
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 12),
                    ),
                    const TalaAppBarTitle(),
                  ],
                );
              },
            )
          else
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('مرحباً',
                    style:
                        TextStyle(color: Colors.white70, fontSize: 12)),
                TalaAppBarTitle(),
              ],
            ),
        ],
      ),
      actions: [
        // Cart badge
        Consumer<CartProvider>(
          builder: (context, cart, _) => Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_bag_outlined,
                    color: Colors.white, size: 26),
                onPressed: () {
                  // navigate to cart tab — handled by AppShell index
                },
              ),
              if (cart.itemCount > 0)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                        color: _gold, shape: BoxShape.circle),
                    constraints: const BoxConstraints(
                        minWidth: 16, minHeight: 16),
                    child: Text(
                      '${cart.itemCount}',
                      style: const TextStyle(
                          color: Colors.black,
                          fontSize: 9,
                          fontWeight: FontWeight.w700),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ),
        // Notification bell
        const NotificationBellAction(),
        const SizedBox(width: 4),
      ],
    );
  }

  // ── Search Bar ────────────────────────────────────────────────────────
  Widget _buildSearchBar(ProductsProvider provider) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1A0A0A),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _gold.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'ابحث عن المنتجات...',
                  hintStyle: TextStyle(color: Colors.white38),
                  border: InputBorder.none,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  prefixIcon:
                      Icon(Icons.search, color: Colors.white38),
                ),
                onChanged: (v) {
                  provider.setSearchQuery(v);
                },
              ),
            ),
            // أيقونة الميكروفون — تستمع لـ HomeUIProvider
            Consumer<HomeUIProvider>(
              builder: (context, ui, _) => IconButton(
                icon: Icon(
                  ui.isListening ? Icons.mic : Icons.mic_none,
                  color: ui.isListening ? _gold : Colors.white38,
                ),
                onPressed:
                    ui.isListening ? _stopListening : _startListening,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Banner ────────────────────────────────────────────────────────────
  Widget _buildBanner() {
    final h = MediaQuery.of(context).size.height;
    return Container(
      margin: const EdgeInsets.only(top: 16),
      height: h * 0.27,
      child: PageView.builder(
        controller: _bannerController,
        itemCount: kBannerImages.length,
        onPageChanged: (newIndex) {
          if (!mounted) return;
          context.read<HomeUIProvider>().setBannerIndex(newIndex);
          _restartBannerTimer();
        },
        itemBuilder: (context, index) {
          // Scale ناعم للصفحة الجانبية (Zara-style parallax)
          return AnimatedBuilder(
            animation: _bannerController,
            builder: (context, child) {
              double scale = 1.0;
              if (_bannerController.position.haveDimensions) {
                final page = _bannerController.page ?? 0;
                scale = (1 - (page - index).abs() * 0.06).clamp(0.94, 1.0);
              }
              return Transform.scale(scale: scale, child: child);
            },
            child: Stack(
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      // ظلّ سفلي ناعم لرفع البانر بصرياً
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.45),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                      // glow ذهبي خفيف جداً (لمسة برمنج)
                      BoxShadow(
                        color: _gold.withValues(alpha: 0.10),
                        blurRadius: 28,
                        spreadRadius: -4,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.asset(
                      kBannerImages[index],
                      fit: BoxFit.cover,
                      width: double.infinity,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 6,
                  left: 16,
                  right: 16,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(20)),
                    child: Container(
                      height: 60,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.6),
                          ],
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.22),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color:
                                      Colors.white.withValues(alpha: 0.15)),
                            ),
                            child: const Text(
                              'استكشف',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          // Dots indicator — مرتبط بـ HomeUIProvider
                          Consumer<HomeUIProvider>(
                            builder: (context, ui, _) {
                              return Row(
                                mainAxisSize: MainAxisSize.min,
                                children: List.generate(
                                  kBannerImages.length,
                                  (i) {
                                    final active = i == ui.bannerIndex;
                                    return AnimatedContainer(
                                      duration: const Duration(
                                          milliseconds: 280),
                                      curve: Curves.easeOutCubic,
                                      width: active ? 18 : 6,
                                      height: 6,
                                      margin:
                                          const EdgeInsets.only(left: 3),
                                      decoration: BoxDecoration(
                                        borderRadius:
                                            BorderRadius.circular(4),
                                        color: active
                                            ? _gold
                                            : Colors.white38,
                                        boxShadow: active
                                            ? [
                                                BoxShadow(
                                                  color: _gold.withValues(
                                                      alpha: 0.55),
                                                  blurRadius: 6,
                                                  offset: Offset.zero,
                                                ),
                                              ]
                                            : null,
                                      ),
                                    );
                                  },
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Section Header ────────────────────────────────────────────────────
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Icon(Icons.grid_view_rounded, color: _gold, size: 20),
        ],
      ),
    );
  }

  // ── Categories ────────────────────────────────────────────────────────
  Widget _buildCategories(ProductsProvider provider) {
    return SizedBox(
      height: 110,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: kCategoryData.length + 1, // +1 for "الكل"
        itemBuilder: (context, index) {
          final isAll = index == 0;
          final name =
              isAll ? null : kCategoryData[index - 1]['name'] as String;
          final image =
              isAll ? null : kCategoryData[index - 1]['image'] as String;
          final isSelected = provider.selectedCategory == name;

          return GestureDetector(
            onTap: () => provider.setCategory(name),
            child: Container(
              width: 80,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? _gold : Colors.transparent,
                  width: 2,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Background image or icon
                    isAll
                        ? Container(
                            color: const Color(0xFF1A1A1A),
                            child: const Icon(Icons.grid_view_rounded,
                                color: _gold, size: 32),
                          )
                        : Image.asset(
                            image!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: const Color(0xFF1A1A1A),
                            ),
                          ),
                    // Glass label
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding:
                            const EdgeInsets.symmetric(vertical: 5),
                        color: Colors.black54,
                        child: Text(
                          isAll ? 'الكل' : name!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Sort Tabs ─────────────────────────────────────────────────────────
  Widget _buildSortTabs(ProductsProvider provider) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          _sortTab('جديد', HomeSortMode.newArrivals, provider),
          const SizedBox(width: 10),
          _sortTab('الأكثر مبيعاً', HomeSortMode.topSelling, provider),
        ],
      ),
    );
  }

  Widget _sortTab(String label, HomeSortMode mode, ProductsProvider provider) {
    final isActive = provider.sortMode == mode;
    return GestureDetector(
      onTap: () => provider.setSortMode(mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? _gold : Colors.white10,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: isActive ? _gold : Colors.white24),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.black : Colors.white,
            fontWeight:
                isActive ? FontWeight.w700 : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  // ── Product Grid ──────────────────────────────────────────────────────
  Widget _buildProductGrid(List<Product> products) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
      sliver: SliverMasonryGrid.count(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childCount: products.length,
        itemBuilder: (context, index) =>
            _buildProductCard(products[index]),
      ),
    );
  }

  // ── Product Card ──────────────────────────────────────────────────────
  Widget _buildProductCard(Product product) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProductDetailScreen(product: product),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: _panel,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product image
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16)),
              child: AspectRatio(
                aspectRatio: 0.9,
                child: CachedNetworkImage(
                  imageUrl: product.imageUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, __) =>
                      Container(color: const Color(0xFF1E1E1E)),
                  errorWidget: (_, __, ___) => Container(
                    color: const Color(0xFF1E1E1E),
                    child: const Icon(Icons.broken_image,
                        color: Colors.white24),
                  ),
                ),
              ),
            ),
            // Product info
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${product.price.toStringAsFixed(0)} ج.م',
                        style: const TextStyle(
                          color: _gold,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      // Quick add to cart
                      GestureDetector(
                        onTap: () => _quickAddToCart(product),
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: const BoxDecoration(
                              color: _gold, shape: BoxShape.circle),
                          child: const Icon(Icons.add,
                              size: 16, color: Colors.black),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Shimmer Loading Grid ──────────────────────────────────────────────
  Widget _buildShimmerGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Shimmer.fromColors(
        baseColor: const Color(0xFF1E1E1E),
        highlightColor: const Color(0xFF303030),
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.72,
          ),
          itemCount: 6,
          itemBuilder: (_, __) => Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
    );
  }

  // ── Empty State ───────────────────────────────────────────────────────
  Widget _buildEmptyState() {
    final provider = context.read<ProductsProvider>();
    final categoryLabel = provider.selectedCategory;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.shopping_bag_outlined,
                color: Colors.white24, size: 72),
            const SizedBox(height: 16),
            Text(
              categoryLabel == null
                  ? 'لا توجد منتجات'
                  : 'لا توجد منتجات في قسم "$categoryLabel"',
              style: const TextStyle(color: Colors.white54, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            if (categoryLabel != null) ...[
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () => provider.setCategory(null),
                icon: const Icon(Icons.grid_view_rounded, size: 16),
                label: const Text('عرض كل المنتجات'),
                style: TextButton.styleFrom(foregroundColor: _gold),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Error State ───────────────────────────────────────────────────────
  Widget _buildErrorState(ProductsProvider provider) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded,
                color: Colors.white24, size: 64),
            const SizedBox(height: 16),
            const Text(
              'تعذر تحميل المنتجات',
              style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: provider.refresh,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('إعادة المحاولة'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _gold,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
