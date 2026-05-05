import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:my_fashion_app/constants/category_constants.dart';
import 'package:my_fashion_app/screens/product_listing_page.dart';
import 'package:my_fashion_app/widgets/app_sliver_bar.dart';

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({Key? key}) : super(key: key);

  static const Color _bg = Color(0xFF0D1117);

  Stream<Map<String, int>> _categoryCounts() {
    return FirebaseFirestore.instance
        .collection('products')
        .snapshots()
        .map((snapshot) {
      final counts = <String, int>{};
      for (final doc in snapshot.docs) {
        final cat = (doc.data()['category'] as String?) ?? '';
        if (cat.isNotEmpty) counts[cat] = (counts[cat] ?? 0) + 1;
      }
      return counts;
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
    final w = MediaQuery.of(context).size.width;
    const double cardHeight = 130.0;

    return Scaffold(
      backgroundColor: _bg,
      body: CustomScrollView(
        slivers: [
          AppSliverBar(
            title: 'الأقسام',
            backgroundColor: _bg,
            actions: const [NotificationBellAction()],
          ),
          StreamBuilder<Map<String, int>>(
            stream: _categoryCounts(),
            builder: (context, snapshot) {
              final counts = snapshot.data ?? {};

              return SliverPadding(
                padding: EdgeInsets.symmetric(
                    horizontal: w * 0.035, vertical: 12),
                sliver: SliverGrid(
                  gridDelegate:
                      SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    mainAxisExtent: cardHeight,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final category = kProductCategories[index];
                      final count = counts[category] ?? 0;

                      return _CategoryCard(
                        category: category,
                        count: count,
                        icon: Icons.shopping_bag_rounded,
                        onTap: () =>
                            _navigateToCategory(context, category),
                      );
                    },
                    childCount: kProductCategories.length,
                  ),
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

class _CategoryCard extends StatelessWidget {
  final String category;
  final int count;
  final IconData icon;
  final VoidCallback onTap;

  const _CategoryCard({
    required this.category,
    required this.count,
    required this.icon,
    required this.onTap,
  });

  static const Color _gold = Color(0xFFD4AF37);
  static const Color _cardBg = Color(0xFF161B22);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _cardBg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        splashColor: _gold.withValues(alpha: 0.12),
        highlightColor: _gold.withValues(alpha: 0.06),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.07),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.max,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: _gold.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _gold.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Icon(icon, color: _gold, size: 22),
              ),
              const SizedBox(height: 8),
              Text(
                category,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$count منتج',
                style: TextStyle(
                  color: count > 0 ? _gold : Colors.white30,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
