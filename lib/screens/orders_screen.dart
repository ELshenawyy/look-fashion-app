import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:my_fashion_app/screens/order_chat_screen.dart';
import 'package:my_fashion_app/services/role_service.dart';
import 'package:my_fashion_app/utils/order_utils.dart';
import 'package:my_fashion_app/widgets/app_sliver_bar.dart';

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  static const Color _gold = Color(0xFFD4AF37);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    final backButton = IconButton(
      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _gold),
      onPressed: () => Navigator.pop(context),
    );

    if (user == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: CustomScrollView(slivers: [
          AppSliverBar(title: 'طلباتي', leading: backButton, automaticallyImplyLeading: false),
          const SliverFillRemaining(
            child: Center(child: Text('يرجى تسجيل الدخول', style: TextStyle(color: Colors.white54))),
          ),
        ]),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          AppSliverBar(
            title: 'طلباتي',
            leading: backButton,
            automaticallyImplyLeading: false,
          ),
        ],
        body: _OrdersBody(userId: user.uid),
      ),
    );
  }
}

/// Separate stateful widget to load admin status once
class _OrdersBody extends StatefulWidget {
  final String userId;
  const _OrdersBody({required this.userId});

  @override
  State<_OrdersBody> createState() => _OrdersBodyState();
}

class _OrdersBodyState extends State<_OrdersBody> {
  static const Color _gold = Color(0xFFD4AF37);
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _checkAdmin();
  }

  Future<void> _checkAdmin() async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .get();
    final role = doc.data()?['role'] as String? ?? '';
    if (mounted) {
      setState(() => _isAdmin = AppRole.isAdminLevel(role));
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('userId', isEqualTo: widget.userId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _gold));
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('خطأ: ${snapshot.error}',
                style: const TextStyle(color: Colors.red)),
          );
        }

        final docs = List.of(snapshot.data?.docs ?? [])
          ..sort((a, b) {
            final aTime = (a.data() as Map)['createdAt'] as Timestamp?;
            final bTime = (b.data() as Map)['createdAt'] as Timestamp?;
            if (aTime == null || bTime == null) return 0;
            return bTime.compareTo(aTime);
          });

        if (docs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.receipt_long_outlined, color: Colors.white24, size: 72),
                SizedBox(height: 16),
                Text('لا توجد طلبات بعد',
                    style: TextStyle(
                        color: Colors.white54, fontSize: 18, fontWeight: FontWeight.w600)),
                SizedBox(height: 8),
                Text('ابدأ التسوق وستظهر طلباتك هنا',
                    style: TextStyle(color: Colors.white38)),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            return _OrderCard(orderId: doc.id, data: data, isAdmin: _isAdmin);
          },
        );
      },
    );
  }
}

class _OrderCard extends StatelessWidget {
  final String orderId;
  final Map<String, dynamic> data;
  final bool isAdmin;

  const _OrderCard({
    required this.orderId,
    required this.data,
    required this.isAdmin,
  });

  static const Color _gold = Color(0xFFD4AF37);
  static const Color _panel = Color(0xFF180808);

  Future<void> _cancelOrder(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _panel,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('إلغاء الطلب', style: TextStyle(color: Colors.white)),
        content: const Text(
          'هل أنت متأكد من إلغاء هذا الطلب؟\nلا يمكن التراجع عن هذه العملية.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('تراجع', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('إلغاء الطلب'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId)
          .update({'status': 'cancelled'});
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إلغاء الطلب بنجاح'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تعذر إلغاء الطلب: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = data['status'] as String? ?? 'pending';
    final total = (data['total'] as num?)?.toDouble() ?? 0.0;
    final items = data['items'] as List<dynamic>? ?? [];
    final address = data['address'] as String? ?? '';
    final createdAt = data['createdAt'] as Timestamp?;
    final dateStr = createdAt != null
        ? OrderUtils.formatDateTime(createdAt.toDate())
        : 'غير محدد';

    return Container(
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        iconColor: _gold,
        collapsedIconColor: Colors.white54,
        title: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(dateStr,
                      style:
                          const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text('${total.toStringAsFixed(2)} ج.س  •  ${items.length} منتج',
                      style: const TextStyle(color: Colors.white54, fontSize: 13)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: OrderUtils.statusColor(status).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: OrderUtils.statusColor(status).withValues(alpha: 0.5)),
              ),
              child: Text(
                OrderUtils.statusLabel(status),
                style: TextStyle(
                    color: OrderUtils.statusColor(status),
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        children: [
          if (address.isNotEmpty) ...[
            Row(
              children: [
                const Icon(Icons.location_on_outlined, color: _gold, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(address,
                      style: const TextStyle(color: Colors.white70, fontSize: 13)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Row(
              children: [
                Icon(Icons.schedule_rounded, color: Colors.white38, size: 16),
                SizedBox(width: 6),
                Text(
                  'مدة التوصيل: من 1 إلى 15 يوم',
                  style: TextStyle(color: Colors.white38, fontSize: 13),
                ),
              ],
            ),
            const Divider(color: Colors.white10, height: 20),
          ],
          ...items.map((item) {
            final itemMap = item as Map<String, dynamic>;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      itemMap['name'] as String? ?? '',
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ),
                  Text(
                    OrderUtils.buildItemLabel(itemMap),
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            );
          }),
          // Buttons — only for regular users, NOT for admin
          if (!isAdmin) ...[
            const Divider(color: Colors.white10, height: 16),
            // Chat button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => OrderChatScreen(
                        orderId: orderId,
                        otherUserName: 'الإدارة',
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.chat_bubble_outline, size: 18),
                label: const Text('تواصل مع الإدارة'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _gold,
                  side: const BorderSide(color: _gold),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
            // Cancel button — only for pending orders
            if (status == 'pending') ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _cancelOrder(context),
                  icon: const Icon(Icons.cancel_outlined, size: 18),
                  label: const Text('إلغاء الطلب'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
