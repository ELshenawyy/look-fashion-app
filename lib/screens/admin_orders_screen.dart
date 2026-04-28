import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:my_fashion_app/screens/order_chat_screen.dart';

class AdminOrdersScreen extends StatefulWidget {
  const AdminOrdersScreen({Key? key}) : super(key: key);

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
    {'value': 'confirmed', 'label': 'تم التأكيد'},
    {'value': 'shipped', 'label': 'تم الشحن'},
    {'value': 'delivered', 'label': 'تم التسليم'},
    {'value': 'cancelled', 'label': 'ملغي'},
  ];

  Stream<QuerySnapshot> _getOrdersStream() {
    final collection = FirebaseFirestore.instance.collection('orders');
    if (_statusFilter == 'all') {
      return collection.snapshots();
    }
    return collection.where('status', isEqualTo: _statusFilter).snapshots();
  }

  Future<void> _updateOrderStatus(String orderId, String newStatus, String userId) async {
    try {
      await FirebaseFirestore.instance.collection('orders').doc(orderId).update({
        'status': newStatus,
      });

      // Notify the user about status change
      await FirebaseFirestore.instance.collection('notifications').add({
        'type': 'order_status',
        'title': 'تحديث حالة الطلب',
        'body': 'تم تحديث حالة طلبك إلى: ${_statusLabel(newStatus)}',
        'orderId': orderId,
        'forRole': null,
        'forUserId': userId,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم تحديث الحالة إلى: ${_statusLabel(newStatus)}'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'confirmed':
        return Colors.blue;
      case 'shipped':
        return Colors.purple;
      case 'delivered':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'قيد المعالجة';
      case 'confirmed':
        return 'تم التأكيد';
      case 'shipped':
        return 'تم الشحن';
      case 'delivered':
        return 'تم التسليم';
      case 'cancelled':
        return 'ملغي';
      default:
        return status;
    }
  }

  void _showStatusChangeDialog(String orderId, String currentStatus, String userId) {
    final statuses = ['pending', 'confirmed', 'shipped', 'delivered', 'cancelled'];

    showModalBottomSheet(
      context: context,
      backgroundColor: _panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'تغيير حالة الطلب',
              style: TextStyle(color: _gold, fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            ...statuses.map((status) => ListTile(
                  leading: Icon(
                    status == currentStatus ? Icons.radio_button_checked : Icons.radio_button_off,
                    color: _statusColor(status),
                  ),
                  title: Text(
                    _statusLabel(status),
                    style: TextStyle(
                      color: status == currentStatus ? _gold : Colors.white,
                      fontWeight: status == currentStatus ? FontWeight.w700 : FontWeight.normal,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    if (status != currentStatus) {
                      _updateOrderStatus(orderId, status, userId);
                    }
                  },
                )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('إدارة الطلبات'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _gold),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Status filter chips
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
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
                    side: BorderSide(color: isSelected ? _gold : Colors.white24),
                    onSelected: (_) {
                      setState(() => _statusFilter = opt['value']!);
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          // Orders list
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _getOrdersStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: _gold));
                }
                if (snapshot.hasError) {
                  return Center(child: Text('خطأ: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
                }

                final docs = snapshot.data?.docs ?? [];
                // Sort client-side (newest first)
                docs.sort((a, b) {
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
                        Text('لا توجد طلبات', style: TextStyle(color: Colors.white54, fontSize: 18)),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    return _buildOrderCard(doc.id, data);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(String orderId, Map<String, dynamic> data) {
    final status = data['status'] as String? ?? 'pending';
    final total = (data['total'] as num?)?.toDouble() ?? 0.0;
    final items = data['items'] as List<dynamic>? ?? [];
    final address = data['address'] as String? ?? '';
    final phone = data['phone'] as String? ?? '';
    final userEmail = data['userEmail'] as String? ?? '';
    final userName = data['userName'] as String? ?? userEmail;
    final userId = data['userId'] as String? ?? '';
    final createdAt = data['createdAt'] as Timestamp?;
    final dateStr = createdAt != null
        ? '${createdAt.toDate().day}/${createdAt.toDate().month}/${createdAt.toDate().year}  ${createdAt.toDate().hour}:${createdAt.toDate().minute.toString().padLeft(2, '0')}'
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
                    userName,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                GestureDetector(
                  onTap: () => _showStatusChangeDialog(orderId, status, userId),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _statusColor(status).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _statusColor(status).withValues(alpha: 0.5)),
                    ),
                    child: Text(
                      _statusLabel(status),
                      style: TextStyle(
                        color: _statusColor(status),
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
              '$dateStr  •  ${total.toStringAsFixed(2)} ج.م  •  ${items.length} منتج',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
        children: [
          // Customer info
          _infoRow(Icons.email_outlined, userEmail),
          if (phone.isNotEmpty) _infoRow(Icons.phone_outlined, phone),
          if (address.isNotEmpty) _infoRow(Icons.location_on_outlined, address),
          const Divider(color: Colors.white10, height: 20),
          // Order items
          ...items.map((item) {
            final m = item as Map<String, dynamic>;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  if (m['image'] != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.network(m['image'], width: 36, height: 36, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const SizedBox(width: 36, height: 36)),
                    ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(m['name'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 13)),
                  ),
                  Text(
                    'x${m['quantity']}  •  ${m['size']}  •  ${m['color']}',
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                ],
              ),
            );
          }),
          const Divider(color: Colors.white10, height: 20),
          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showStatusChangeDialog(orderId, status, userId),
                  icon: const Icon(Icons.swap_horiz, size: 18),
                  label: const Text('تغيير الحالة'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _gold,
                    side: const BorderSide(color: _gold),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                          orderId: orderId,
                          otherUserName: userName,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.chat_bubble_outline, size: 18),
                  label: const Text('محادثة'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.blue,
                    side: const BorderSide(color: Colors.blue),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
          Expanded(child: Text(text, style: const TextStyle(color: Colors.white70, fontSize: 13))),
        ],
      ),
    );
  }
}
