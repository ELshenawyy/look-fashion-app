import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:my_fashion_app/constants/category_constants.dart';
import 'package:my_fashion_app/core/utils/color_utils.dart';
import 'package:my_fashion_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:my_fashion_app/features/cart/presentation/providers/cart_provider.dart';
import 'package:my_fashion_app/features/favorites/presentation/providers/favorites_provider.dart';
import 'package:my_fashion_app/models/cartt.dart';
import 'package:my_fashion_app/models/product.dart';

class ProductDetailScreen extends StatefulWidget {
  final Product product;

  /// إذا != null → نحن في **edit mode** لعنصر سلة موجود.
  /// قيمته = index العنصر في `cart.items`. عند الإضافة، نحذف العنصر
  /// القديم ونضيف الجديد بنفس المعطيات الجديدة (size/color/quantity).
  final int? editCartIndex;

  /// المقاس المختار سابقاً (للـ edit mode) — يُعبَّأ افتراضياً.
  final String? initialSize;

  /// اللون المختار سابقاً (للـ edit mode) — يُعبَّأ افتراضياً.
  final String? initialColor;

  const ProductDetailScreen({
    super.key,
    required this.product,
    this.editCartIndex,
    this.initialSize,
    this.initialColor,
  });

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  static const Color _gold = Color(0xFFD4AF37);
  static const Color _panel = Color(0xFF180808);

  late final Product product;
  String? _selectedSize;
  String? _selectedColor;

  bool get _isEditMode => widget.editCartIndex != null;

  @override
  void initState() {
    super.initState();
    product = widget.product;
    // في edit mode → نستخدم القيم الأولية من السلة (الاختيار السابق).
    // غير ذلك → first item كـ default.
    _selectedSize = widget.initialSize ??
        (product.sizes.isNotEmpty ? product.sizes.first : null);
    _selectedColor = widget.initialColor ??
        (product.colors.isNotEmpty ? product.colors.first : null);

    // ابدأ مراقبة المفضلة (إن لم تكن مفعّلة) حتى أيقونة القلب تعكس
    // الحالة الصحيحة فور فتح الشاشة.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final uid = context.read<AuthProvider>().user?.uid;
      if (uid != null) {
        context.read<FavoritesProvider>().startWatching(uid);
      }
    });
  }

  Color _resolveColor(String colorCode) => ColorUtils.parse(colorCode);

  void _handleAddToCart() {
    if (product.stockQuantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('هذا المنتج غير متاح حالياً.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (product.sizes.isNotEmpty && _selectedSize == null) {
      final label = sizeLabelForCategory(product.category);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('يرجى اختيار $label أولًا.'),
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
      productState: product.state,
      stockQuantity: product.stockQuantity,
    );

    final cart = Provider.of<CartProvider>(context, listen: false);

    if (_isEditMode) {
      // edit mode: احذف العنصر القديم وأضف الجديد بنفس المعطيات الجديدة
      cart.removeItem(widget.editCartIndex!);
      cart.addItem(cartItem);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تحديث المنتج في السلة'),
          backgroundColor: Color(0xFF2E7D32),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context); // رجوع لشاشة السلة
      return;
    }

    cart.addItem(cartItem);

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
              ColorUtils.displayLabel(colorName),
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

  // ── Favorite toggle helper ────────────────────────────────────────────
  Future<void> _toggleFavorite(BuildContext ctx) async {
    final uid = ctx.read<AuthProvider>().user?.uid;
    if (uid == null) {
      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
        content: Text('يرجى تسجيل الدخول أولاً'),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    await ctx.read<FavoritesProvider>().toggle(
      userId: uid,
      productId: product.docId ?? product.id.toString(),
      title: product.title,
      imageUrl: product.imageUrl,
      price: product.price,
    );
  }

  // ── Stock badge ───────────────────────────────────────────────────────
  Widget _buildStockBadge() {
    final qty = product.stockQuantity;
    final Color bg;
    final Color fg;
    final String label;
    if (qty <= 0) {
      bg = Colors.red.withValues(alpha: 0.15);
      fg = Colors.redAccent;
      label = 'نفد المخزون';
    } else if (qty <= 5) {
      bg = Colors.orange.withValues(alpha: 0.15);
      fg = Colors.orange;
      label = 'آخر $qty قطع';
    } else {
      bg = Colors.green.withValues(alpha: 0.12);
      fg = const Color(0xFF4CAF50);
      label = 'متوفر ($qty)';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: fg.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 7, height: 7,
              decoration: BoxDecoration(color: fg, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  color: fg, fontSize: 12, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;
    final expandedHeight = screenH * 0.52;

    return Scaffold(
      backgroundColor: Colors.black,
      // ── زر السلة ثابت في الأسفل دائماً ──────────────────────────
      bottomNavigationBar: Container(
        color: _panel,
        padding: EdgeInsets.fromLTRB(
            20, 12, 20, MediaQuery.of(context).padding.bottom + 12),
        child: SizedBox(
          height: 54,
          child: ElevatedButton.icon(
            onPressed: product.stockQuantity > 0 ? _handleAddToCart : null,
            icon: Icon(
              product.stockQuantity > 0
                  ? (_isEditMode
                      ? Icons.save_rounded
                      : Icons.shopping_cart_checkout_rounded)
                  : Icons.block_rounded,
              size: 20,
            ),
            label: Text(
              product.stockQuantity > 0
                  ? (_isEditMode ? 'تحديث في السلة' : 'إضافة إلى السلة')
                  : 'نفد من المخزون',
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w800),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  product.stockQuantity > 0 ? _gold : Colors.grey[800],
              foregroundColor:
                  product.stockQuantity > 0 ? Colors.black : Colors.white54,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ),
      ),

      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── SliverAppBar مع Parallax ───────────────────────────────
          SliverAppBar(
            expandedHeight: expandedHeight,
            pinned: true,
            stretch: true,
            backgroundColor: Colors.black,
            elevation: 0,
            // زر الرجوع
            leading: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white, size: 20),
              ),
            ),            
            // أيقونة المفضلة
            actions: [
              Selector<FavoritesProvider, bool>(
                selector: (_, fav) =>
                    fav.isFavorite(product.docId ?? product.id.toString()),
                builder: (ctx, isFav, _) => GestureDetector(
                  onTap: () => _toggleFavorite(ctx),
                  child: Container(
                    margin: const EdgeInsets.only(right: 12, top: 8, bottom: 8),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: Icon(
                        isFav
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        key: ValueKey(isFav),
                        color: isFav ? Colors.redAccent : Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                ),
              ),
            ],
            // ── الصورة مع تأثير البارالاكس ──────────────────────────
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              stretchModes: const [StretchMode.zoomBackground],
              background: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: product.imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Shimmer.fromColors(
                      baseColor: const Color(0xFF1A1A1A),
                      highlightColor: const Color(0xFF2C2C2C),
                      child: Container(color: Colors.black),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      color: const Color(0xFF1A1A1A),
                      child: const Icon(Icons.image_not_supported,
                          color: Colors.white24, size: 60),
                    ),
                  ),
                  // gradient أسفل الصورة للانتقال السلس للبانل
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: 80,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            _panel.withValues(alpha: 0.9),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── محتوى المنتج ──────────────────────────────────────────
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                color: _panel,
                borderRadius: BorderRadius.vertical(top: Radius.circular(0)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Badge القسم ──────────────────────────────────
                  if (product.category.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _gold.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: _gold.withValues(alpha: 0.3)),
                          ),
                          child: Text(product.category,
                              style: const TextStyle(
                                  color: _gold,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600)),
                        ),
                        if (product.gender.isNotEmpty &&
                            product.gender != product.category)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: Text(product.gender,
                                style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600)),
                          ),
                      ],
                    ),

                  const SizedBox(height: 12),

                  // ── اسم المنتج ───────────────────────────────────
                  Text(
                    product.title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      height: 1.3,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── السعر + المخزون ──────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('السعر',
                              style: TextStyle(
                                  color: Colors.white38, fontSize: 11)),
                          const SizedBox(height: 2),
                          Text(
                            '${product.price.toStringAsFixed(0)} ج.س',
                            style: const TextStyle(
                              color: _gold,
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      ), // end Flexible
                      const SizedBox(width: 8),
                      _buildStockBadge(),
                    ],
                  ),

                  const SizedBox(height: 22),
                  const Divider(color: Colors.white10, height: 1),
                  const SizedBox(height: 22),

                  // ── الألوان ──────────────────────────────────────
                  if (product.colors.isNotEmpty) ...[
                    _buildSectionTitle('اللون'),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: product.colors.map(_buildColorOption).toList(),
                    ),
                    const SizedBox(height: 22),
                    const Divider(color: Colors.white10, height: 1),
                    const SizedBox(height: 22),
                  ],

                  // ── المقاسات ─────────────────────────────────────
                  if (product.sizes.isNotEmpty) ...[
                    _buildSectionTitle(sizeLabelForCategory(product.category)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: product.sizes.map(_buildSizeOption).toList(),
                    ),
                    const SizedBox(height: 22),
                    const Divider(color: Colors.white10, height: 1),
                    const SizedBox(height: 22),
                  ],

                  // ── الوصف ────────────────────────────────────────
                  _buildSectionTitle('الوصف'),
                  const SizedBox(height: 10),
                  Text(
                    product.description,
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 14,
                      height: 1.75,
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
