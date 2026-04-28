import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:my_fashion_app/services/cart_provider.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({Key? key}) : super(key: key);

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  static const Color _gold = Color(0xFFD4AF37);
  static const Color _maroon = Color(0xFF5A1010);
  static const Color _panel = Color(0xFF180808);

  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isPlacingOrder = false;
  String? _selectedState;

  static const double _khartoumDelivery = 7000;
  static const double _otherStateDelivery = 1000;

  static const List<String> _sudanStates = [
    'الخرطوم', 'الجزيرة', 'النيل الأبيض', 'النيل الأزرق', 'نهر النيل',
    'البحر الأحمر', 'الشمالية', 'كسلا', 'القضارف', 'سنار',
    'شمال كردفان', 'جنوب كردفان', 'غرب كردفان',
    'شمال دارفور', 'جنوب دارفور', 'وسط دارفور', 'شرق دارفور', 'غرب دارفور',
  ];

  double get _deliveryCost {
    if (_selectedState == null) return 0;
    return _selectedState == 'الخرطوم' ? _khartoumDelivery : _otherStateDelivery;
  }

  /// Validates Sudanese phone number: 09XXXXXXXX (10 digits) or +249XXXXXXXXX
  bool _isValidSudanesePhone(String phone) {
    final cleaned = phone.replaceAll(RegExp(r'[\s\-]'), '');
    // +249XXXXXXXXX = 12 digits after +
    if (RegExp(r'^\+249[0-9]{9}$').hasMatch(cleaned)) return true;
    // 249XXXXXXXXX = 12 digits without +
    if (RegExp(r'^249[0-9]{9}$').hasMatch(cleaned)) return true;
    // 09XXXXXXXX = 10 digits
    if (RegExp(r'^09[0-9]{8}$').hasMatch(cleaned)) return true;
    return false;
  }

  @override
  void dispose() {
    _addressController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  /// Validates that all items have sufficient stock before placing order.
  Future<String?> _validateStock(Cart cart) async {
    final firestore = FirebaseFirestore.instance;

    for (final item in cart.items) {
      final docRef = firestore.collection('products').doc(item.productId);
      final docSnap = await docRef.get();

      if (!docSnap.exists) {
        return 'المنتج "${item.name}" لم يعد متاحاً.';
      }

      final data = docSnap.data()!;
      final currentStock = (data['stockQuantity'] as num?)?.toInt() ?? 0;

      if (currentStock < item.quantity) {
        if (currentStock == 0) {
          return 'المنتج "${item.name}" نفد من المخزون.';
        }
        return 'المنتج "${item.name}" متاح فقط $currentStock قطعة، لكن طلبت ${item.quantity}.';
      }
    }
    return null; // all good
  }

  /// Decrements stock for all ordered items using a batch write.
  Future<void> _decrementStock(Cart cart) async {
    final firestore = FirebaseFirestore.instance;
    final batch = firestore.batch();

    for (final item in cart.items) {
      final docRef = firestore.collection('products').doc(item.productId);
      batch.update(docRef, {
        'stockQuantity': FieldValue.increment(-item.quantity),
      });
    }

    await batch.commit();
  }

  /// Creates a notification for all admins about the new order.
  Future<void> _notifyAdmins(String orderId, Cart cart, String userName) async {
    final firestore = FirebaseFirestore.instance;
    final itemNames = cart.items.map((i) => '${i.name} x${i.quantity}').join('، ');

    await firestore.collection('notifications').add({
      'type': 'new_order',
      'title': 'طلب جديد',
      'body': 'طلب جديد من $userName: $itemNames',
      'orderId': orderId,
      'forRole': 'admin',
      'forUserId': null,
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _placeOrder(Cart cart) async {
    if (_addressController.text.trim().isEmpty) {
      _showSnack('يرجى إدخال عنوان التوصيل', Colors.orange);
      return;
    }
    if (_selectedState == null) {
      _showSnack('يرجى اختيار الولاية', Colors.orange);
      return;
    }
    if (_phoneController.text.trim().isEmpty) {
      _showSnack('يرجى إدخال رقم الهاتف', Colors.orange);
      return;
    }
    if (!_isValidSudanesePhone(_phoneController.text.trim())) {
      _showSnack('رقم الهاتف غير صحيح — يرجى إدخال رقم سوداني صحيح (مثال: 0912345678)', Colors.orange);
      return;
    }

    setState(() => _isPlacingOrder = true);

    try {
      // 1) Validate stock
      final stockError = await _validateStock(cart);
      if (stockError != null) {
        if (!mounted) return;
        _showSnack(stockError, Colors.red);
        setState(() => _isPlacingOrder = false);
        return;
      }

      // 2) Create order
      final user = FirebaseAuth.instance.currentUser;
      final userName = user?.displayName ?? user?.email ?? 'مستخدم';
      final orderItems = cart.items
          .map((item) => {
                'productId': item.productId,
                'name': item.name,
                'price': item.price,
                'quantity': item.quantity,
                'size': item.size,
                'color': item.color,
                'image': item.image,
              })
          .toList();

      final deliveryCost = _deliveryCost;
      final grandTotal = cart.totalPrice + deliveryCost;

      final orderRef = await FirebaseFirestore.instance.collection('orders').add({
        'userId': user?.uid,
        'userEmail': user?.email,
        'userName': userName,
        'items': orderItems,
        'subtotal': cart.totalPrice,
        'deliveryCost': deliveryCost,
        'total': grandTotal,
        'address': _addressController.text.trim(),
        'state': _selectedState,
        'phone': _phoneController.text.trim(),
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 3) Decrement stock
      await _decrementStock(cart);

      // 4) Notify admins
      await _notifyAdmins(orderRef.id, cart, userName);

      // 5) Clear cart & show confirmation
      cart.clear();

      if (!mounted) return;
      _showOrderConfirmationDialog();
    } catch (e) {
      if (!mounted) return;
      _showSnack('حدث خطأ أثناء تأكيد الطلب: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isPlacingOrder = false);
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  void _showOrderConfirmationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: _panel,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.green, size: 64),
            const SizedBox(height: 16),
            const Text(
              'تم تأكيد طلبك!',
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'سيتم التواصل معك قريباً لتأكيد التوصيل.',
              style: TextStyle(color: Colors.white60, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop(); // close dialog
                  Navigator.of(context).pop(); // go back to cart (now empty)
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _gold,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text('حسناً', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<Cart>(context);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('إتمام الطلب'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _gold),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('ملخص الطلب'),
            const SizedBox(height: 12),
            ...cart.items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _panel,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          item.image,
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 56,
                            height: 56,
                            color: Colors.grey[900],
                            child: const Icon(Icons.image_not_supported,
                                color: Colors.white24, size: 20),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.name,
                                style: const TextStyle(
                                    color: Colors.white, fontWeight: FontWeight.w600)),
                            Text('${item.size} • ${item.color}',
                                style: const TextStyle(color: Colors.white54, fontSize: 12)),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('x${item.quantity}',
                              style: const TextStyle(color: Colors.white70)),
                          Text('${(item.price * item.quantity).toStringAsFixed(2)} ج.م',
                              style: const TextStyle(color: _gold, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: _maroon.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _gold.withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('المجموع الفرعي',
                          style: TextStyle(color: Colors.white70, fontSize: 14)),
                      Text('${cart.totalPrice.toStringAsFixed(0)} ج.س',
                          style: const TextStyle(color: Colors.white70, fontSize: 14)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('التوصيل',
                          style: TextStyle(color: Colors.white70, fontSize: 14)),
                      Text(
                        _selectedState == null
                            ? 'اختر الولاية أولاً'
                            : '${_deliveryCost.toStringAsFixed(0)} ج.س',
                        style: TextStyle(
                          color: _selectedState == null ? Colors.white38 : Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white24, height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('الإجمالي',
                          style: TextStyle(
                              color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                      Text(
                        '${(cart.totalPrice + _deliveryCost).toStringAsFixed(0)} ج.س',
                        style: const TextStyle(
                            color: _gold, fontSize: 20, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            _sectionTitle('بيانات التوصيل'),
            const SizedBox(height: 12),
            _inputField(
              controller: _addressController,
              label: 'عنوان التوصيل التفصيلي',
              icon: Icons.location_on_outlined,
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            // Sudan State Dropdown
            Container(
              decoration: BoxDecoration(
                color: _panel,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedState,
                  isExpanded: true,
                  dropdownColor: const Color(0xFF1E1010),
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, color: _gold),
                  hint: Row(
                    children: [
                      const Icon(Icons.map_outlined, color: _gold, size: 20),
                      const SizedBox(width: 12),
                      const Text('اختر الولاية', style: TextStyle(color: Colors.white54)),
                    ],
                  ),
                  items: _sudanStates.map((state) {
                    return DropdownMenuItem<String>(
                      value: state,
                      child: Text(state, style: const TextStyle(color: Colors.white)),
                    );
                  }).toList(),
                  onChanged: (value) => setState(() => _selectedState = value),
                ),
              ),
            ),
            if (_selectedState != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _gold.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _gold.withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.local_shipping_outlined, color: _gold, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'تكلفة التوصيل إلى $_selectedState: ${_deliveryCost.toStringAsFixed(0)} ج.س',
                      style: const TextStyle(color: _gold, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            _inputField(
              controller: _phoneController,
              label: 'رقم الهاتف (سوداني)',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 6),
            const Padding(
              padding: EdgeInsets.only(right: 4),
              child: Text(
                'مثال: 0912345678 أو +249912345678',
                style: TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isPlacingOrder ? null : () => _placeOrder(cart),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _gold,
                  foregroundColor: Colors.black,
                  disabledBackgroundColor: Colors.grey[700],
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                child: _isPlacingOrder
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.black),
                      )
                    : const Text('تأكيد الطلب'),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: _gold,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _inputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54),
        prefixIcon: Icon(icon, color: _gold),
        filled: true,
        fillColor: _panel,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.white12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.white12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _gold),
        ),
      ),
    );
  }
}
