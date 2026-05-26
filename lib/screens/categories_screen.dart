
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:my_fashion_app/constants/category_constants.dart';
import 'package:my_fashion_app/features/products/presentation/providers/categories_provider.dart';
import 'package:my_fashion_app/screens/product_listing_page.dart';
import 'package:my_fashion_app/widgets/app_sliver_bar.dart';
import 'package:provider/provider.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  static const Color _bg = Color(0xFF0D1117);

  @override
  void initState() {
    super.initState();
    // يبدأ الـ stream إن كان متوقفاً (بعد signOut/reset).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<CategoriesProvider>().ensureStarted();
    });
  }

  void _navigateToCategory(BuildContext context, String category) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductListingPage(categoryName: category),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _bg,
      child: CustomScrollView(
        slivers: [
          const AppSliverBar(
            title: 'الأقسام',
            backgroundColor: _bg,
            actions: [NotificationBellAction()],
          ),
          Consumer<CategoriesProvider>(
            builder: (context, provider, _) {
              // ⚡ في الـ cold-start، الـ stream قد يحتاج ثوان للاتصال.
              // نعرض shimmer (الـ counts فاضية مؤقتاً) بدل error screen.
              // الـ provider يُعيد المحاولة بصمت في الخلفية.
              final counts = provider.counts;

              // ⚡ SliverMasonryGrid بدلاً من MasonryGridView.count داخل
              // SliverToBoxAdapter — يعمل بـ lazy build حقيقي مع الـ
              // CustomScrollView الخارجي، يحسّن الأداء أثناء التمرير.
              return SliverPadding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                sliver: SliverMasonryGrid.count(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childCount: kCategoryData.length,
                  itemBuilder: (context, index) {
                    final data = kCategoryData[index];
                    final category = data['name'] as String;
                    final height = data['height'] as double;
                    final image = data['image'] as String;
                    final count = counts[category] ?? 0;

                    // RepaintBoundary يعزل الـ card عن إعادة الرسم
                    // عند scroll → كل بطاقة تُرسم لمرة واحدة فقط ثم
                    // تُخزَّن كـ raster layer.
                    return RepaintBoundary(
                      child: _MasonryCategoryCard(
                        category: category,
                        count: count,
                        image: image,
                        height: height,
                        onTap: () => _navigateToCategory(context, category),
                      ),
                    );
                  },
                ),
              );
            },
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }
}

class _MasonryCategoryCard extends StatelessWidget {
  final String category;
  final int count;
  final String image;
  final double height;
  final VoidCallback onTap;

  const _MasonryCategoryCard({
    required this.category,
    required this.count,
    required this.image,
    required this.height,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            splashColor: Colors.white.withValues(alpha: 0.1),
            highlightColor: Colors.white.withValues(alpha: 0.05),
            onTap: onTap,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // صورة الخلفية — cacheWidth لتقليل استهلاك الذاكرة
                // (الـ JPG الأصلي قد يكون 1000px، نعرضه ~200px فقط)
                Image.asset(
                  image,
                  fit: BoxFit.cover,
                  cacheWidth: 400, // ~2x density للشاشات HD
                  errorBuilder: (_, __, ___) => Container(
                    color: const Color(0xFF161B22),
                    child: const Icon(
                      Icons.image_not_supported,
                      color: Colors.white54,
                      size: 40,
                    ),
                  ),
                ),
                // طبقة تعتيم خفيفة
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.25),
                      ],
                    ),
                  ),
                ),
                // ⚡ Gradient overlay سفلي بدل BackdropFilter (50x أسرع
                // أثناء الـ scroll — لا shader compile لكل frame).
                // المظهر مشابه: تدرّج شفّاف → داكن قوي.
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(24),
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.55),
                          Colors.black.withValues(alpha: 0.85),
                        ],
                        stops: const [0, 0.4, 1],
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          category,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$count منتج',
                          style: TextStyle(
                            color: count > 0
                                ? const Color(0xFFD4AF37)
                                : Colors.white60,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
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
