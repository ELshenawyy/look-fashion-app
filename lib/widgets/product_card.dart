import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:my_fashion_app/features/favorites/presentation/providers/favorites_provider.dart';
import 'package:my_fashion_app/models/product.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

/// بطاقة منتج موحدة — تُستخدم في صفحة القائمة وصفحة المفضلة
///
/// تستخدم Selector داخلياً لمراقبة حالة المفضلة لمنتج محدّد فقط
/// (دون إعادة بناء الـ Card كاملةً عند تغيير أي favorite في القائمة).
class ProductCard extends StatelessWidget {
  const ProductCard({
    super.key,
    required this.product,
    required this.onTap,
    required this.onFavoriteToggle,
    required this.onAddToCart,
  });

  final Product product;
  final VoidCallback onTap;
  final VoidCallback onFavoriteToggle;
  final VoidCallback onAddToCart;

  static const Color _gold = Color(0xFFD4AF37);
  static const Color _panel = Color(0xFF180808);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        splashColor: _gold.withValues(alpha: 0.15),
        highlightColor: _gold.withValues(alpha: 0.07),
        child: Ink(
          decoration: BoxDecoration(
            color: _panel,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── صورة المنتج + أيقونة المفضلة ─────────────────────
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(16)),
                    child: AspectRatio(
                      aspectRatio: 1.0,
                      child: CachedNetworkImage(
                        imageUrl: product.imageUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Shimmer.fromColors(
                          baseColor: const Color(0xFF1E1E1E),
                          highlightColor: const Color(0xFF2A2A2A),
                          child: Container(color: Colors.black),
                        ),
                        errorWidget: (_, __, ___) => Container(
                          color: const Color(0xFF1E1E1E),
                          child: const Icon(Icons.broken_image,
                              color: Colors.white24, size: 32),
                        ),
                      ),
                    ),
                  ),
                  // Out-of-stock overlay
                  if (product.stockQuantity == 0)
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(16)),
                      child: AspectRatio(
                        aspectRatio: 1.0,
                        child: Container(
                          color: Colors.black.withValues(alpha: 0.58),
                          alignment: Alignment.center,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.75),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.white24),
                            ),
                            child: const Text(
                              'نفذت الكمية',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  // Favorite badge — أعلى اليمين
                  // ⚡ Selector ينعزل عن باقي الـ card: فقط الأيقونة
                  // تُعاد بنائها عند تغيير الـ favorite، الصورة + السعر
                  // + الزر يبقون كما هم (لا flicker).
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Selector<FavoritesProvider, bool>(
                      selector: (_, fav) =>
                          fav.isFavorite(product.docId ?? ''),
                      builder: (_, isFav, __) => GestureDetector(
                        onTap: onFavoriteToggle,
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isFav
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            color:
                                isFav ? Colors.redAccent : Colors.white70,
                            size: 17,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              // ── بيانات المنتج ─────────────────────────────────────
              // الارتفاع الثابت للقسم = 102px
              // 8 (top) + 32 (title 2 lines) + 4 + 16 (price) + 6 + 28 (btn) + 8 (bottom)
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // اسم المنتج — حد أقصى سطرين
                    Text(
                      product.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // السعر
                    Text(
                      '${product.price.toStringAsFixed(0)} ج.س',
                      style: const TextStyle(
                        color: _gold,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    // زر إضافة للسلة
                    SizedBox(
                      width: double.infinity,
                      height: 28,
                      child: ElevatedButton(
                        onPressed:
                            product.stockQuantity != 0 ? onAddToCart : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: product.stockQuantity != 0
                              ? _gold
                              : Colors.grey[800],
                          foregroundColor: product.stockQuantity != 0
                              ? Colors.black
                              : Colors.white38,
                          disabledBackgroundColor: Colors.grey[800],
                          disabledForegroundColor: Colors.white38,
                          padding: EdgeInsets.zero,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          product.stockQuantity != 0 ? 'أضف إلى السلة' : 'نفذت الكمية',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
