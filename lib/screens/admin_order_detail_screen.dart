import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:my_fashion_app/core/di/injection_container.dart';
import 'package:my_fashion_app/features/orders/domain/entities/order_entity.dart';
import 'package:my_fashion_app/features/orders/domain/usecases/get_order_by_id.dart';
import 'package:my_fashion_app/features/orders/presentation/providers/orders_provider.dart';
import 'package:my_fashion_app/screens/order_chat_screen.dart';
import 'package:my_fashion_app/utils/order_utils.dart';
import 'package:my_fashion_app/widgets/app_sliver_bar.dart';
import 'package:provider/provider.dart';

/// شاشة تفاصيل طلب واحد — للأدمن (تُفتح من الإشعارات)
class AdminOrderDetailScreen extends StatefulWidget {
  final String orderId;

  const AdminOrderDetailScreen({super.key, required this.orderId});

  @override
  State<AdminOrderDetailScreen> createState() => _AdminOrderDetailScreenState();
}

class _AdminOrderDetailScreenState extends State<AdminOrderDetailScreen> {
  static const Color _gold = Color(0xFFD4AF37);
  static const Color _panel = Color(0xFF180808);

  OrderEntity? _order;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadOrder();
  }

  Future<void> _loadOrder() async {
    final res = await sl<GetOrderById>()(widget.orderId);
    if (!mounted) return;
    res.fold((f) {
      setState(() {
        _error = f.message;
        _loading = false;
      });
    }, (order) {
      setState(() {
        _order = order;
        _loading = false;
      });
    });
  }

  Future<void> _confirmDeleteOrder() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _panel,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('حذف الطلب',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        content: const Text(
          'هل أنت تأكد من حذف هذا الطلب نهائياً؟ هذا الإجراء لا يمكن التراجع عنه.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف نهائياً',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;

    final ok = await context.read<OrdersProvider>().deleteOrder(widget.orderId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok ? 'تم حذف الطلب بنجاح' : 'فشل حذف الطلب'),
      backgroundColor: ok ? Colors.green : Colors.red,
      behavior: SnackBarBehavior.floating,
    ));
    if (ok) Navigator.pop(context);
  }

  Future<void> _updateStatus(OrderStatus newStatus) async {
    final ok = await context.read<OrdersProvider>().updateStatus(
          orderId: widget.orderId,
          status: newStatus,
        );
    if (!mounted) return;
    if (ok && _order != null) {
      // إعادة تحميل الطلب بعد التحديث
      await _loadOrder();
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok
          ? 'تم تحديث الحالة إلى: ${OrderUtils.statusLabel(newStatus.toFirestoreValue())}'
          : 'فشل تحديث الحالة'),
      backgroundColor: ok ? Colors.green : Colors.red,
      behavior: SnackBarBehavior.floating,
    ));
  }

  void _showStatusDialog(OrderStatus current) {
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
      builder: (_) => SafeArea(
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
                                Navigator.pop(context);
                                if (s != current) _updateStatus(s);
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

  Widget _infoRow(IconData icon, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: _gold, size: 16),
            const SizedBox(width: 8),
            Expanded(
                child: Text(text,
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 13))),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          AppSliverBar(
            title: 'تفاصيل الطلب',
            leading: IconButton(
              icon:
                  const Icon(Icons.arrow_back_ios_new_rounded, color: _gold),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              if (!_loading && _order != null)
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: Colors.redAccent),
                  tooltip: 'حذف الطلب',
                  onPressed: _confirmDeleteOrder,
                ),
            ],
            automaticallyImplyLeading: false,
          ),
        ],
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: _gold))
            : _error != null
                ? Center(
                    child: Text(_error!,
                        style: const TextStyle(color: Colors.red)))
                : _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    final order = _order!;
    final statusStr = order.status.toFirestoreValue();
    final userName = order.userName.isNotEmpty
        ? order.userName
        : (order.userEmail ?? 'العميل');
    final userEmail = order.userEmail ?? '';
    final dateStr = order.createdAt != null
        ? OrderUtils.formatDateTime(order.createdAt!)
        : 'غير محدد';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: status + date
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _panel,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 17,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(dateStr,
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 12)),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => _showStatusDialog(order.status),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: OrderUtils.statusColor(statusStr)
                          .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: OrderUtils.statusColor(statusStr)
                              .withValues(alpha: 0.5)),
                    ),
                    child: Text(
                      OrderUtils.statusLabel(statusStr),
                      style: TextStyle(
                        color: OrderUtils.statusColor(statusStr),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Customer info
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _panel,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('بيانات العميل',
                    style: TextStyle(
                        color: _gold,
                        fontWeight: FontWeight.w700,
                        fontSize: 14)),
                const SizedBox(height: 10),
                if (userEmail.isNotEmpty)
                  _infoRow(Icons.email_outlined, userEmail),
                if (order.phone.isNotEmpty)
                  _infoRow(Icons.phone_outlined, order.phone),
                if (order.address.isNotEmpty)
                  _infoRow(Icons.location_on_outlined, order.address),
                if ((order.state ?? '').isNotEmpty)
                  _infoRow(Icons.map_outlined, order.state!),
                _infoRow(
                    Icons.schedule_rounded, 'مدة التوصيل: من 1 إلى 15 يوم'),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Items
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _panel,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('المنتجات (${order.items.length})',
                    style: const TextStyle(
                        color: _gold,
                        fontWeight: FontWeight.w700,
                        fontSize: 14)),
                const SizedBox(height: 10),
                ...order.items.map((item) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        if (item.image.isNotEmpty)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: CachedNetworkImage(
                              imageUrl: item.image,
                              width: 40,
                              height: 40,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => Container(
                                width: 40,
                                height: 40,
                                color: const Color(0xFF1E1E1E),
                              ),
                              errorWidget: (_, __, ___) =>
                                  const SizedBox(width: 40, height: 40),
                            ),
                          ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.name,
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 13)),
                              Text(
                                OrderUtils.buildItemLabel({
                                  'quantity': item.quantity,
                                  'size': item.size,
                                  'color': item.color,
                                }),
                                style: const TextStyle(
                                    color: Colors.white54, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${item.price.toStringAsFixed(2)} ج.س',
                          style: const TextStyle(
                              color: _gold,
                              fontSize: 13,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  );
                }),
                const Divider(color: Colors.white10, height: 20),
                _totalRow('المجموع الفرعي', order.subtotal),
                _totalRow('التوصيل', order.deliveryCost),
                const Divider(color: Colors.white10, height: 12),
                _totalRow('الإجمالي', order.total, bold: true),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Action buttons — زر "محادثة" يُخفى لو الأدمن نفسه صاحب الطلب
          Builder(
            builder: (context) {
              final currentUid = FirebaseAuth.instance.currentUser?.uid;
              final isOwnOrder =
                  currentUid != null && order.userId == currentUid;
              return Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _showStatusDialog(order.status),
                      icon: const Icon(Icons.swap_horiz, size: 18),
                      label: const Text('تغيير الحالة'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _gold,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  if (!isOwnOrder) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => OrderChatScreen(
                              orderId: widget.orderId,
                              otherUserName: userName,
                            ),
                          ),
                        ),
                        icon: const Icon(Icons.chat_bubble_outline,
                            size: 18),
                        label: const Text('محادثة'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.blue,
                          side: const BorderSide(color: Colors.blue),
                          padding:
                              const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _totalRow(String label, double amount, {bool bold = false}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: TextStyle(
                    color: bold ? Colors.white : Colors.white70,
                    fontSize: bold ? 14 : 13,
                    fontWeight:
                        bold ? FontWeight.w700 : FontWeight.normal)),
            Text(
              '${amount.toStringAsFixed(2)} ج.س',
              style: TextStyle(
                  color: bold ? _gold : Colors.white70,
                  fontSize: bold ? 14 : 13,
                  fontWeight: bold ? FontWeight.w700 : FontWeight.normal),
            ),
          ],
        ),
      );
}
