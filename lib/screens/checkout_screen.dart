import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:my_fashion_app/features/cart/presentation/providers/cart_provider.dart';
import 'package:my_fashion_app/features/orders/domain/repositories/order_repository.dart';
import 'package:my_fashion_app/features/orders/presentation/providers/orders_provider.dart';
import 'package:my_fashion_app/widgets/app_sliver_bar.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  static const Color _gold = Color(0xFFD4AF37);
  static const Color _maroon = Color(0xFF5A1010);
  static const Color _panel = Color(0xFF180808);

  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isPlacingOrder = false;
  String? _selectedState;

  static const double _localDelivery = 8000;      // نفس ولاية المنتج
  static const double _interStateDelivery = 11000; // ولاية مختلفة

  static const List<String> _sudanStates = [
    'الخرطوم', 'الجزيرة', 'النيل الأبيض', 'النيل الأزرق', 'نهر النيل',
    'البحر الأحمر', 'الشمالية', 'كسلا', 'القضارف', 'سنار',
    'شمال كردفان', 'جنوب كردفان', 'غرب كردفان',
    'شمال دارفور', 'جنوب دارفور', 'وسط دارفور', 'شرق دارفور', 'غرب دارفور',
  ];

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user?.displayName != null && user!.displayName!.isNotEmpty) {
      _nameController.text = user.displayName!;
    }
  }

  double _calculateDeliveryCost(CartProvider cart) {
    if (_selectedState == null) return 0;
    // توصيل محلي فقط لو كل منتجات السلة من نفس ولاية العميل
    final allLocal = cart.items.isNotEmpty &&
        cart.items.every(
          (item) =>
              item.productState.isNotEmpty &&
              item.productState == _selectedState,
        );
    return allLocal ? _localDelivery : _interStateDelivery;
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
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  /// Shows a summary bottom sheet and waits for user confirmation before placing order.
  Future<void> _showOrderSummaryModal(CartProvider cart) async {
    final enteredName = _nameController.text.trim();
    if (enteredName.isEmpty) {
      _showSnack('يرجى إدخال اسمك', Colors.orange);
      return;
    }
    if (enteredName.length < 3) {
      _showSnack('الاسم قصير جداً — يجب أن يكون 3 أحرف على الأقل', Colors.orange);
      return;
    }
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

    // Close keyboard before showing sheet
    FocusScope.of(context).unfocus();

    final deliveryCost = _calculateDeliveryCost(cart);
    final grandTotal = cart.totalPrice + deliveryCost;

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (_, scrollCtrl) {
            return Container(
              decoration: const BoxDecoration(
                color: Color(0xFF180808),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  // ── Handle ─────────────────────────────────
                  const SizedBox(height: 10),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Icon(Icons.receipt_long_rounded, color: Color(0xFFD4AF37), size: 22),
                        SizedBox(width: 10),
                        Text(
                          'مراجعة الطلب',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Divider(color: Colors.white12, height: 16),
                  // ── Scrollable content ───────────────────────
                  Expanded(
                    child: ListView(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      children: [
                        // Items
                        ...cart.items.map((item) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  item.image,
                                  width: 48,
                                  height: 48,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    width: 48,
                                    height: 48,
                                    color: Colors.white10,
                                    child: const Icon(Icons.image_not_supported,
                                        color: Colors.white24, size: 18),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600)),
                                    Text('${item.size} • ${item.color} • x${item.quantity}',
                                        style: const TextStyle(
                                            color: Colors.white54, fontSize: 11)),
                                  ],
                                ),
                              ),
                              Text(
                                '${(item.price * item.quantity).toStringAsFixed(0)} ج.س',
                                style: const TextStyle(
                                    color: Color(0xFFD4AF37),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13),
                              ),
                            ],
                          ),
                        )),
                        const Divider(color: Colors.white12),
                        // Delivery address & phone
                        _summaryRow(Icons.person_outline_rounded,
                            enteredName, Colors.white70),
                        const SizedBox(height: 6),
                        _summaryRow(Icons.location_on_outlined,
                            '${_addressController.text.trim()} — $_selectedState', Colors.white70),
                        const SizedBox(height: 6),
                        _summaryRow(Icons.phone_outlined,
                            _phoneController.text.trim(), Colors.white70),
                        const Divider(color: Colors.white12),
                        // Totals
                        _totalRow('المجموع الفرعي',
                            '${cart.totalPrice.toStringAsFixed(0)} ج.س', false),
                        const SizedBox(height: 6),
                        _totalRow('تكلفة التوصيل',
                            '${deliveryCost.toStringAsFixed(0)} ج.س', false),
                        const SizedBox(height: 6),
                        _totalRow('الإجمالي',
                            '${grandTotal.toStringAsFixed(0)} ج.س', true),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                  // ── Confirm button ───────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.of(sheetCtx).pop(true),
                        icon: const Icon(Icons.check_circle_outline_rounded),
                        label: const Text('تأكيد وإرسال الطلب'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD4AF37),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18)),
                          textStyle: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (confirmed == true) {
      await _placeOrder(cart);
    }
  }

  Widget _summaryRow(IconData icon, String text, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xFFD4AF37), size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text,
              style: TextStyle(color: color, fontSize: 13)),
        ),
      ],
    );
  }

  Widget _totalRow(String label, String value, bool isBold) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
              color: isBold ? Colors.white : Colors.white70,
              fontSize: isBold ? 15 : 13,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.normal,
            )),
        Text(value,
            style: TextStyle(
              color: isBold ? const Color(0xFFD4AF37) : Colors.white70,
              fontSize: isBold ? 17 : 13,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.normal,
            )),
      ],
    );
  }

  /// Places the order through the OrdersProvider use case.
  /// المعاملة الذرية الآن في FirestoreOrderDataSource.placeOrderTransaction.
  Future<void> _placeOrder(CartProvider cart) async {
    setState(() => _isPlacingOrder = true);

    final user = FirebaseAuth.instance.currentUser;
    final userName = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final deliveryCost = _calculateDeliveryCost(cart);
    final grandTotal = cart.totalPrice + deliveryCost;

    final input = PlaceOrderInput(
      userId: user?.uid,
      userEmail: user?.email,
      userName: userName,
      phone: phone,
      address: _addressController.text.trim(),
      state: _selectedState,
      items: cart.items,
      subtotal: cart.totalPrice,
      deliveryCost: deliveryCost,
      total: grandTotal,
      productStates: cart.items.map((i) => i.productState).toSet().toList(),
    );

    final ordersProvider = context.read<OrdersProvider>();
    final orderId = await ordersProvider.placeOrder(input);

    if (!mounted) return;
    setState(() => _isPlacingOrder = false);

    if (orderId != null) {
      cart.clear();
      _showOrderConfirmationDialog();
    } else if (ordersProvider.failure != null) {
      _showSnack(ordersProvider.failure!.message, Colors.red);
      ordersProvider.clearFailure();
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
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
    final cart = Provider.of<CartProvider>(context);

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: CustomScrollView(
          slivers: [
            AppSliverBar(
              title: 'إتمام الطلب',
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _gold),
                onPressed: () => Navigator.pop(context),
              ),
              automaticallyImplyLeading: false,
            ),
            SliverPadding(
              padding: const EdgeInsets.all(20),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
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
                          Text('${(item.price * item.quantity).toStringAsFixed(2)} ج.س',
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
                            : '${_calculateDeliveryCost(cart).toStringAsFixed(0)} ج.س',
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
                        '${(cart.totalPrice + _calculateDeliveryCost(cart)).toStringAsFixed(0)} ج.س',
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
              controller: _nameController,
              label: 'الاسم الكامل',
              icon: Icons.person_outline_rounded,
            ),
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
                  hint: const Row(
                    children: [
                      Icon(Icons.map_outlined, color: _gold, size: 20),
                      SizedBox(width: 12),
                      Text('اختر الولاية', style: TextStyle(color: Colors.white54)),
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
                    Expanded(
                      child: Text(
                        'تكلفة التوصيل إلى $_selectedState: ${_calculateDeliveryCost(cart).toStringAsFixed(0)} ج.س',
                        style: const TextStyle(color: _gold, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white12),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.schedule_rounded,
                            color: Colors.white54, size: 16),
                        SizedBox(width: 8),
                        Text(
                          'مدة التوصيل المتوقعة: من 1 إلى 15 يوم',
                          style: TextStyle(
                              color: Colors.white54, fontSize: 13),
                        ),
                      ],
                    ),
                    SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.payments_outlined,
                            color: Color(0xFF4CAF50), size: 16),
                        SizedBox(width: 8),
                        Text(
                          'الدفع عند الاستلام',
                          style: TextStyle(
                            color: Color(0xFF4CAF50),
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
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
                onPressed: _isPlacingOrder ? null : () => _showOrderSummaryModal(cart),
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
                ]),
              ),
            ),
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
