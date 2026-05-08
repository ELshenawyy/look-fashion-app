import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:my_fashion_app/screens/order_chat_screen.dart';
import 'package:my_fashion_app/utils/order_utils.dart';
import 'package:my_fashion_app/widgets/app_sliver_bar.dart';

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

  Map<String, dynamic>? _orderData;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadOrder();
  }

  Future<void> _loadOrder() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.orderId)
          .get();
      if (!mounted) return;
      if (!doc.exists) {
        setState(() {
          _error = 'الطلب غير موجود';
          _loading = false;
        });
        return;
      }
      setState(() {
        _orderData = doc.data();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'خطأ: $e';
        _loading = false;
      });
    }
  }

  // ── تغيير الحالة ─────────────────────────────────────────────────────
  Future<void> _updateStatus(String newStatus) async {
    final userId = _orderData?['userId'] as String? ?? '';
    try {
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.orderId)
          .update({'status': newStatus});

      await FirebaseFirestore.instance.collection('notifications').add({
        'type': 'order_status',
        'title': 'تحديث حالة الطلب',
        'body': 'تم تحديث حالة طلبك إلى: ${OrderUtils.statusLabel(newStatus)}',
        'orderId': widget.orderId,
        'forRole': null,
        'forUserId': userId,
        'read': false,
        'senderName': 'فريق خدمة العملاء',
        'senderId': '',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      setState(() => _orderData = {...?_orderData, 'status': newStatus});
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('تم تحديث الحالة إلى: ${OrderUtils.statusLabel(newStatus)}'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('خطأ: $e'),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  void _showStatusDialog(String currentStatus) {
    const statuses = [
      'pending',
      'confirmed',
      'shipped',
      'delivered',
      'cancelled',
    ];
    showModalBottomSheet(
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
                    children: statuses.map((s) => ListTile(
                          leading: Icon(
                            s == currentStatus
                                ? Icons.radio_button_checked
                                : Icons.radio_button_off,
                            color: OrderUtils.statusColor(s),
                          ),
                          title: Text(
                            OrderUtils.statusLabel(s),
                            style: TextStyle(
                              color: s == currentStatus ? _gold : Colors.white,
                              fontWeight: s == currentStatus
                                  ? FontWeight.w700
                                  : FontWeight.normal,
                            ),
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            if (s != currentStatus) _updateStatus(s);
                          },
                        )).toList(),
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

  // ── helpers ──────────────────────────────────────────────────────────
  Widget _infoRow(IconData icon, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: _gold, size: 16),
            const SizedBox(width: 8),
            Expanded(
                child: Text(text,
                    style: const TextStyle(color: Colors.white70, fontSize: 13))),
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
    final data = _orderData!;
    final status = data['status'] as String? ?? 'pending';
    final userName = data['userName'] as String? ??
        data['userEmail'] as String? ??
        'العميل';
    final userEmail = data['userEmail'] as String? ?? '';
    final phone = data['phone'] as String? ?? '';
    final address = data['address'] as String? ?? '';
    final state = data['state'] as String? ?? '';
    final subtotal = (data['subtotal'] as num?)?.toDouble() ?? 0.0;
    final deliveryCost = (data['deliveryCost'] as num?)?.toDouble() ?? 0.0;
    final total = (data['total'] as num?)?.toDouble() ?? 0.0;
    final items = data['items'] as List<dynamic>? ?? [];
    final createdAt = data['createdAt'] as Timestamp?;
    final dateStr = createdAt != null
        ? OrderUtils.formatDateTime(createdAt.toDate())
        : 'غير محدد';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header: status + date ───────────────────────────────────
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
                  onTap: () => _showStatusDialog(status),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: OrderUtils.statusColor(status).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: OrderUtils.statusColor(status).withValues(alpha: 0.5)),
                    ),
                    child: Text(
                      OrderUtils.statusLabel(status),
                      style: TextStyle(
                        color: OrderUtils.statusColor(status),
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

          // ── Customer info ───────────────────────────────────────────
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
                if (phone.isNotEmpty) _infoRow(Icons.phone_outlined, phone),
                if (address.isNotEmpty)
                  _infoRow(Icons.location_on_outlined, address),
                if (state.isNotEmpty) _infoRow(Icons.map_outlined, state),
                _infoRow(
                    Icons.schedule_rounded, 'مدة التوصيل: من 1 إلى 15 يوم'),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Items ───────────────────────────────────────────────────
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
                Text('المنتجات (${items.length})',
                    style: const TextStyle(
                        color: _gold,
                        fontWeight: FontWeight.w700,
                        fontSize: 14)),
                const SizedBox(height: 10),
                ...items.map((item) {
                  final m = item as Map<String, dynamic>;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        if (m['image'] != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Image.network(
                              m['image'],
                              width: 40,
                              height: 40,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  const SizedBox(width: 40, height: 40),
                            ),
                          ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(m['name'] ?? '',
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 13)),
                              Text(
                                OrderUtils.buildItemLabel(m),
                                style: const TextStyle(
                                    color: Colors.white54, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${(m['price'] as num?)?.toStringAsFixed(2) ?? 0} ج.س',
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
                // Totals
                _totalRow('المجموع الفرعي', subtotal),
                _totalRow('التوصيل', deliveryCost),
                const Divider(color: Colors.white10, height: 12),
                _totalRow('الإجمالي', total, bold: true),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Action buttons ──────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showStatusDialog(status),
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
                  icon: const Icon(Icons.chat_bubble_outline, size: 18),
                  label: const Text('محادثة'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.blue,
                    side: const BorderSide(color: Colors.blue),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _totalRow(String label, double amount, {bool bold = false}) => Padding(
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
