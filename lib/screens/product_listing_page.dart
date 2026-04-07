import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:my_fashion_app/models/product.dart';
import 'package:my_fashion_app/pages/product_detail_screen.dart';
import 'package:my_fashion_app/services/product_service.dart';

class ProductListingPage extends StatefulWidget {
  final String? categoryName;

  const ProductListingPage({
    Key? key,
    this.categoryName,
  }) : super(key: key);

  @override
  State<ProductListingPage> createState() => _ProductListingPageState();
}

class _ProductListingPageState extends State<ProductListingPage> {
  static const Color _gold = Color(0xFFD4AF37);
  static const Color _maroon = Color(0xFF800000);

  final ProductService _productService = ProductService();
  final Set<String> _optimisticFavorites = <String>{};
  final Set<String> _optimisticRemovals = <String>{};

  String _productKey(Product product) {
    return product.docId ?? product.id.toString();
  }

  Stream<Set<String>> _favoriteIdsStream(String userId) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('favorites')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.id).toSet());
  }

  bool _isFavorite(Product product, Set<String> savedFavoriteIds) {
    final productKey = _productKey(product);
    if (_optimisticRemovals.contains(productKey)) return false;
    if (_optimisticFavorites.contains(productKey)) return true;
    return savedFavoriteIds.contains(productKey);
  }

  Future<void> _toggleFavorite(Product product, bool isFavorite) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى تسجيل الدخول لحفظ المنتجات في المفضلة.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final productKey = _productKey(product);
    final favoriteRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('favorites')
        .doc(productKey);

    setState(() {
      if (isFavorite) {
        _optimisticFavorites.remove(productKey);
        _optimisticRemovals.add(productKey);
      } else {
        _optimisticRemovals.remove(productKey);
        _optimisticFavorites.add(productKey);
      }
    });

    try {
      if (isFavorite) {
        await favoriteRef.delete();
      } else {
        await favoriteRef.set({
          ...product.toJson(),
          'docId': productKey,
          'savedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (isFavorite) {
          _optimisticRemovals.remove(productKey);
        } else {
          _optimisticFavorites.remove(productKey);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر تحديث المفضلة: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _openProduct(Product product) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProductDetailScreen(product: product),
      ),
    );
  }

  Widget _buildProductCard(Product product, Set<String> favoriteIds) {
    final bool isFavorite = _isFavorite(product, favoriteIds);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(26),
        child: InkWell(
          borderRadius: BorderRadius.circular(26),
          onTap: () => _openProduct(product),
          splashColor: _gold.withOpacity(0.14),
          highlightColor: _gold.withOpacity(0.08),
          child: Ink(
            height: 156,
            decoration: BoxDecoration(
              color: _maroon,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(
                color: _gold.withOpacity(0.22),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.42),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 134,
                  height: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(26),
                      bottomLeft: Radius.circular(26),
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withOpacity(0.10),
                        Colors.black.withOpacity(0.18),
                      ],
                    ),
                  ),
                  child: Center(
                    child: Container(
                      width: 102,
                      height: 102,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.14),
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.network(
                          product.imageUrl,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return const Center(
                              child: CircularProgressIndicator(color: _gold),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return const Center(
                              child: Icon(
                                Icons.image_not_supported,
                                color: Colors.white70,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 18, 16, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          product.description,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            height: 1.45,
                          ),
                        ),
                        const Spacer(),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Text(
                                '${product.price.toStringAsFixed(2)} ج.م',
                                style: const TextStyle(
                                  color: _gold,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.16),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.12),
                                ),
                              ),
                              child: IconButton(
                                padding: const EdgeInsets.all(8),
                                constraints: const BoxConstraints(),
                                icon: Icon(
                                  isFavorite
                                      ? Icons.favorite_rounded
                                      : Icons.favorite_border_rounded,
                                  color: isFavorite
                                      ? Colors.redAccent
                                      : Colors.white70,
                                  size: 20,
                                ),
                                onPressed: () =>
                                    _toggleFavorite(product, isFavorite),
                              ),
                            ),
                          ],
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

  Widget _buildProductList(List<Product> products, Set<String> favoriteIds) {
    if (products.isEmpty) {
      final categoryLabel = widget.categoryName;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: Text(
            categoryLabel == null
                ? 'لا توجد منتجات'
                : 'لا توجد منتجات في قسم $categoryLabel',
            style: const TextStyle(color: Colors.white70, fontSize: 18),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: products.length,
      itemBuilder: (context, index) {
        return _buildProductCard(products[index], favoriteIds);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final title = widget.categoryName ?? 'كل المنتجات';

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        backgroundColor: const Color(0xFF000000),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: _gold),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: _gold,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: StreamBuilder<List<Product>>(
        stream: _productService.getProductsStream(category: widget.categoryName),
        builder: (context, productSnapshot) {
          if (productSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: _gold),
            );
          }

          if (productSnapshot.hasError) {
            return Center(
              child: Text(
                'حدث خطأ: ${productSnapshot.error}',
                style: const TextStyle(color: Colors.redAccent),
              ),
            );
          }

          final products = productSnapshot.data ?? const <Product>[];
          final favoriteIdsStream = user == null
              ? Stream.value(<String>{})
              : _favoriteIdsStream(user.uid);

          return StreamBuilder<Set<String>>(
            stream: favoriteIdsStream,
            builder: (context, favoritesSnapshot) {
              final favoriteIds = favoritesSnapshot.data ?? <String>{};

              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 36, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.only(top: 14, bottom: 10),
                      child: const Text(
                        'اختر القطعة التي تناسبك من بين منتجاتنا المتاحة.',
                        textAlign: TextAlign.start,
                        style: TextStyle(
                          color: _gold,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'times new roman',
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: const Text(
                        'هذه قائمة المنتجات المتوفرة لدينا',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    _buildProductList(products, favoriteIds),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
