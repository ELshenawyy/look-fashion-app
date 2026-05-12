import 'package:flutter/material.dart';
import 'package:my_fashion_app/features/orders/domain/entities/order_entity.dart';
import 'package:my_fashion_app/features/orders/presentation/providers/orders_provider.dart';
import 'package:my_fashion_app/screens/order_chat_screen.dart';
import 'package:my_fashion_app/utils/order_utils.dart';
import 'package:my_fashion_app/widgets/app_sliver_bar.dart';
import 'package:provider/provider.dart';

class AdminOrdersScreen extends StatefulWidget {
  const AdminOrdersScreen({super.key});

  @override
  State<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends State<AdminOrdersScreen> {
  static const Color _gold = Color(0xFFD4AF37);
  static const Color _panel = Color(0xFF180808);

  String _statusFilter = 'all';

  static const _statusOptions = [
    {'value': 'all', 'label': 'الكل'},
    {'value': 'pending', 'label': 'قيد المعالجة'},
    {'value': 'preparing', 'label': 'قيد التحضير'},
    {'value': 'shipped', 'label': 'تم الشحن'},
    {'value': 'delivered', 'label': 'تم التسليم'},
    {'value': 'cancelled', 'label': 'ملغي'},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<OrdersProvider>().watchAll();
    });
  }

  Future<void> _updateOrderStatus(
      String orderId, OrderStatus newStatus) async {
    final ok = await context.read<OrdersProvider>().updateStatus(
          orderId: orderId,
          status: newStatus,
        );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok
            ? 'تم تحديث الحالة إلى: ${OrderUtils.statusLabel(newStatus.toFirestoreValue())}'
            : 'فشل تحديث الحالة'),
        backgroundColor: ok ? Colors.green : Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showStatusChangeDialog(String orderId, OrderStatus current) {
    final statuses = [
      OrderStatus.pending,
      OrderStatus.preparing,
      OrderStatus.shipped,
      OrderStatus.delivered,
      OrderStatus.cancelled,
    ];

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _panel,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'تغيير حالة الطلب',
                style: TextStyle(
                    color: _gold, fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: statuses
                        .map((s) => ListTile(
                              leading: Icon(
                                s == current
                                    ? Icons.radio_button_checked
                                    : Icons.radio_button_off,
                                color: OrderUtils.statusColor(
                                    s.toFirestoreValue()),
                              ),
                              title: Text(
                                OrderUtils.statusLabel(s.toFirestoreValue()),
                                style: TextStyle(
                                  color: s == current ? _gold : Colors.white,
                                  fontWeight: s == current
                                      ? FontWeight.w700
                                      : FontWeight.normal,
                                ),
                              ),
                              onTap: () {
                                Navigator.pop(ctx);
                                if (s != current) {
                                  _updateOrderStatus(orderId, s);
                                }
                              },
                            ))
                        .toList(),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  List<OrderEntity> _filtered(List<OrderEntity> orders) {
    if (_statusFilter == 'all') return orders;
    return orders
        .where((o) => o.status.toFirestoreValue() == _statusFilter)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          AppSliverBar(
            title: 'إدارة الطلبات',
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _gold),
              onPressed: () => Navigator.pop(context),
            ),
            automaticallyImplyLeading: false,
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 56,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                children: _statusOptions.map((opt) {
                  final isSelected = _statusFilter == opt['value'];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Text(opt['label']!),
                      selected: isSelected,
                      selectedColor: _gold,
                      backgroundColor: _panel,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.black : Colors.white70,
                        fontWeight: FontWeight.w600,
                      ),
                      side: BorderSide(
                          color: isSelected ? _gold : Colors.white24),
                      onSelected: (_) =>
                          setState(() => _statusFilter = opt['value']!),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
        body: Consumer<OrdersProvider>(
          builder: (context, provider, _) {
            final orders = _filtered(provider.allOrders);

            if (orders.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.receipt_long_outlined,
                        color: Colors.white24, size: 72),
                    SizedBox(height: 16),
                    Text('لا توجد طلبات',
                        style:
                            TextStyle(color: Colors.white54, fontSize: 18)),
                  ],
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: orders.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _buildOrderCard(orders[i]),
            );
          },
        ),
      ),
    );
  }

  Widget _buildOrderCard(OrderEntity order) {
    final status = order.status.toFirestoreValue();
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    order.userName,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                GestureDetector(
                  onTap: () =>
                      _showStatusChangeDialog(order.id, order.status),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color:
                          OrderUtils.statusColor(status).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: OrderUtils.statusColor(status)
                              .withValues(alpha: 0.5)),
                    ),
                    child: Text(
                      OrderUtils.statusLabel(status),
                      style: TextStyle(
                        color: OrderUtils.statusColor(status),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '$dateStr  •  ${order.total.toStringAsFixed(2)} ج.س  •  ${order.items.length} منتج',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
        children: [
          if (order.userEmail != null && order.userEmail!.isNotEmpty)
            _infoRow(Icons.email_outlined, order.userEmail!),
          if (order.phone.isNotEmpty)
            _infoRow(Icons.phone_outlined, order.phone),
          if (order.address.isNotEmpty)
            _infoRow(Icons.location_on_outlined, order.address),
          _infoRow(Icons.schedule_rounded, 'مدة التوصيل: من 1 إلى 15 يوم'),
          const Divider(color: Colors.white10, height: 20),
          ...order.items.map((item) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  if (item.image.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.network(item.image,
                          width: 36,
                          height: 36,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              const SizedBox(width: 36, height: 36)),
                    ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(item.name,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 13)),
                  ),
                  Text(
                    OrderUtils.buildItemLabel({
                      'quantity': item.quantity,
                      'size': item.size,
                      'color': item.color,
                    }),
                    style:
                        const TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                ],
              ),
            );
          }),
          const Divider(color: Colors.white10, height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () =>
                      _showStatusChangeDialog(order.id, order.status),
                  icon: const Icon(Icons.swap_horiz, size: 18),
                  label: const Text('تغيير الحالة'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _gold,
                    side: const BorderSide(color: _gold),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => OrderChatScreen(
                          orderId: order.id,
                          otherUserName: order.userName,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.chat_bubble_outline, size: 18),
                  label: const Text('محادثة'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.blue,
                    side: const BorderSide(color: Colors.blue),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, color: _gold, size: 16),
          const SizedBox(width: 8),
          Expanded(
              child: Text(text,
                  style: const TextStyle(color: Colors.white70, fontSize: 13))),
        ],
      ),
    );
  }
}
