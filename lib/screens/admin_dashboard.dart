import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:my_fashion_app/core/di/injection_container.dart';
import 'package:my_fashion_app/features/admin/data/repositories/admin_repository.dart';
import 'package:my_fashion_app/screens/add_product_screen.dart';
import 'package:my_fashion_app/screens/admin_orders_screen.dart';
import 'package:my_fashion_app/utils/order_utils.dart';
import 'package:my_fashion_app/widgets/app_sliver_bar.dart';

class AdminDashboard extends StatefulWidget {
  /// إن كان true → superAdmin (يرى زر الحذف)
  /// إن كان false → subAdmin (زر الحذف مخفي)
  final bool isSuperAdmin;

  const AdminDashboard({super.key, required this.isSuperAdmin});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  static const Color _gold = Color(0xFFD4AF37);

  late Stream<QuerySnapshot> _productsStream;
  String _searchQuery = '';
  final _adminRepo = sl<AdminRepository>();

  @override
  void initState() {
    super.initState();
    _productsStream =
        FirebaseFirestore.instance.collection('products').snapshots();
  }

  Future<void> _deleteProduct(String docId, String imageUrl) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف المنتج', style: TextStyle(color: _gold)),
        content: const Text(
          'هل أنت متأكد من رغبتك في حذف هذا المنتج؟',
          style: TextStyle(color: Colors.white70),
        ),
        backgroundColor: Colors.grey[900],
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء', style: TextStyle(color: _gold)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _adminRepo.deleteProduct(docId, imageUrl: imageUrl);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم حذف المنتج بنجاح'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _editProduct(String docId, Map<String, dynamic> productData) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddProductScreen(
          productId: docId,
          productData: productData,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          AppSliverBar(
            titleWidget: const Text(
              'لوحة الإدارة',
              style: TextStyle(
                  color: _gold, fontSize: 20, fontWeight: FontWeight.w700),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _gold),
              onPressed: () => Navigator.pop(context),
            ),
            automaticallyImplyLeading: false,
            actions: [
              TextButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const AdminOrdersScreen()),
                ),
                icon: const Icon(Icons.receipt_long,
                    color: Colors.blue, size: 20),
                label:
                    const Text('الطلبات', style: TextStyle(color: Colors.blue)),
              ),
            ],
          ),
          // ── شريط البحث ──────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: TextField(
                style: const TextStyle(color: Colors.white),
                cursorColor: _gold,
                decoration: InputDecoration(
                  hintText: 'ابحث عن منتج...',
                  hintStyle: const TextStyle(color: Colors.white38),
                  prefixIcon:
                      const Icon(Icons.search, color: Colors.white38),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear,
                              color: Colors.white38, size: 18),
                          onPressed: () => setState(() => _searchQuery = ''),
                        )
                      : null,
                  filled: true,
                  fillColor: const Color(0xFF180808),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:
                        const BorderSide(color: _gold, width: 1),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                ),
                onChanged: (v) => setState(() => _searchQuery = v),
              ),
            ),
          ),
        ],
        body: StreamBuilder<QuerySnapshot>(
          stream: _productsStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: _gold),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'حدث خطأ: ${snapshot.error}',
                  style: const TextStyle(color: Colors.white),
                ),
              );
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(
                child: Text(
                  'لا توجد منتجات',
                  style: TextStyle(color: Colors.white70),
                ),
              );
            }

            // ترتيب ثم تصفية بالبحث
            var products = snapshot.data!.docs.toList()
              ..sort((a, b) {
                final aDate =
                    OrderUtils.resolveDate(a.data() as Map<String, dynamic>);
                final bDate =
                    OrderUtils.resolveDate(b.data() as Map<String, dynamic>);
                return bDate.compareTo(aDate);
              });

            if (_searchQuery.trim().isNotEmpty) {
              final q = _searchQuery.trim().toLowerCase();
              products = products.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final title =
                    (data['title'] as String? ?? '').toLowerCase();
                final category =
                    (data['category'] as String? ?? '').toLowerCase();
                return title.contains(q) || category.contains(q);
              }).toList();
            }

            if (products.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.search_off,
                        color: Colors.white24, size: 56),
                    const SizedBox(height: 12),
                    Text(
                      'لا توجد نتائج لـ "$_searchQuery"',
                      style: const TextStyle(color: Colors.white54),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: products.length,
              itemBuilder: (context, index) {
                final doc = products[index];
                final data = doc.data() as Map<String, dynamic>;

                return Card(
                  color: Colors.grey[900],
                  margin:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(12),
                    leading: ((data['imageUrl'] as String?) ?? '').isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: SizedBox(
                              width: 60,
                              height: 60,
                              child: Image.network(
                                data['imageUrl'] as String,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  color: Colors.white12,
                                  child: const Icon(Icons.broken_image,
                                      color: Colors.white38),
                                ),
                              ),
                            ),
                          )
                        : Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: Colors.white12,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.image,
                                color: Colors.white38),
                          ),
                    title: Text(
                      data['title'] ?? 'غير معروف',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          '${data['price'] ?? 0} ج.س',
                          style: const TextStyle(
                            color: _gold,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'المخزون: ${data['stockQuantity'] ?? 0}',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12),
                        ),
                        if (data['sizes'] != null &&
                            (data['sizes'] as List).isNotEmpty)
                          Text(
                            'المقاسات: ${(data['sizes'] as List).join(', ')}',
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                    trailing: SizedBox(
                      width: widget.isSuperAdmin ? 100 : 50,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          IconButton(
                            icon:
                                const Icon(Icons.edit, color: Colors.blue),
                            tooltip: 'تعديل',
                            onPressed: () => _editProduct(doc.id, data),
                          ),
                          if (widget.isSuperAdmin)
                            IconButton(
                              icon: const Icon(Icons.delete,
                                  color: Colors.red),
                              tooltip: 'حذف',
                              onPressed: () => _deleteProduct(
                                  doc.id, data['imageUrl'] ?? ''),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
