import 'package:flutter/material.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:my_fashion_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:my_fashion_app/features/orders/domain/entities/order_entity.dart';
import 'package:my_fashion_app/features/orders/presentation/providers/orders_provider.dart';
import 'package:my_fashion_app/screens/order_chat_screen.dart';
import 'package:my_fashion_app/utils/order_utils.dart';
import 'package:my_fashion_app/widgets/app_sliver_bar.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  static const Color _gold = Color(0xFFD4AF37);
  bool _reviewChecked = false;

  @override
  void initState() {
    super.initState();
    final uid = context.read<AuthProvider>().user?.uid;
    if (uid != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<OrdersProvider>().watchForUser(uid);
      });
    }
  }

  Future<void> _maybeRequestReview(List<OrderEntity> orders) async {
    if (_reviewChecked) return;
    _reviewChecked = true;

    final hasDelivered =
        orders.any((o) => o.status == OrderStatus.delivered);
    if (!hasDelivered) return;

    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('hasRequestedReview') == true) return;

    final review = InAppReview.instance;
    if (!await review.isAvailable()) return;

    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    await review.requestReview();
    await prefs.setBool('hasRequestedReview', true);
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;

    final backButton = IconButton(
      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _gold),
      onPressed: () => Navigator.pop(context),
    );

    if (user == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: CustomScrollView(slivers: [
          AppSliverBar(
              title: 'طلباتي',
              leading: backButton,
              automaticallyImplyLeading: false),
          const SliverFillRemaining(
            child: Center(
                child: Text('يرجى تسجيل الدخول',
                    style: TextStyle(color: Colors.white54))),
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
        body: Consumer<OrdersProvider>(
          builder: (context, provider, _) {
            final orders = provider.userOrders;

            if (!_reviewChecked) {
              WidgetsBinding.instance.addPostFrameCallback(
                (_) => _maybeRequestReview(orders),
              );
            }

            if (orders.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.receipt_long_outlined,
                        color: Colors.white24, size: 72),
                    SizedBox(height: 16),
                    Text('لا توجد طلبات بعد',
                        style: TextStyle(
                            color: Colors.white54,
                            fontSize: 18,
                            fontWeight: FontWeight.w600)),
                    SizedBox(height: 8),
                    Text('ابدأ التسوق وستظهر طلباتك هنا',
                        style: TextStyle(color: Colors.white38)),
                  ],
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: orders.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) =>
                  _OrderCard(order: orders[i], isAdmin: user.isAdmin),
            );
          },
        ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final OrderEntity order;
  final bool isAdmin;

  const _OrderCard({required this.order, required this.isAdmin});

  static const Color _gold = Color(0xFFD4AF37);
  static const Color _panel = Color(0xFF180808);

  Future<void> _cancelOrder(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _panel,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title:
            const Text('إلغاء الطلب', style: TextStyle(color: Colors.white)),
        content: const Text(
          'هل أنت متأكد من إلغاء هذا الطلب؟\nلا يمكن التراجع عن هذه العملية.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child:
                const Text('تراجع', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('إلغاء الطلب'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final ok = await context.read<OrdersProvider>().updateStatus(
          orderId: order.id,
          status: OrderStatus.cancelled,
          customerId: order.userId,
        );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'تم إلغاء الطلب بنجاح' : 'تعذر إلغاء الطلب'),
        backgroundColor: ok ? Colors.green : Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final statusStr = order.status.toFirestoreValue();
    final dateStr = order.createdAt != null
        ? OrderUtils.formatDateTime(order.createdAt!)
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
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(
                    '${order.total.toStringAsFixed(2)} ج.س  •  ${order.items.length} منتج',
                    style:
                        const TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: OrderUtils.statusColor(statusStr).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color:
                        OrderUtils.statusColor(statusStr).withValues(alpha: 0.5)),
              ),
              child: Text(
                OrderUtils.statusLabel(statusStr),
                style: TextStyle(
                    color: OrderUtils.statusColor(statusStr),
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        children: [
          if (order.address.isNotEmpty) ...[
            Row(
              children: [
                const Icon(Icons.location_on_outlined,
                    color: _gold, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(order.address,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 13)),
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
          ...order.items.map((item) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      item.name,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 13),
                    ),
                  ),
                  Text(
                    OrderUtils.buildItemLabel({
                      'quantity': item.quantity,
                      'size': item.size,
                      'color': item.color,
                    }),
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            );
          }),
          if (!isAdmin) ...[
            const Divider(color: Colors.white10, height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => OrderChatScreen(
                        orderId: order.id,
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
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
            if (order.status == OrderStatus.pending) ...[
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
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
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
