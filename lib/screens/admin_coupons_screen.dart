import 'package:flutter/material.dart';
import 'package:my_fashion_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:my_fashion_app/features/coupons/domain/entities/coupon_entity.dart';
import 'package:my_fashion_app/features/coupons/domain/repositories/coupon_repository.dart';
import 'package:my_fashion_app/features/coupons/presentation/providers/coupons_provider.dart';
import 'package:my_fashion_app/widgets/app_sliver_bar.dart';
import 'package:provider/provider.dart';

/// شاشة إدارة الكوبونات للأدمن.
class AdminCouponsScreen extends StatefulWidget {
  const AdminCouponsScreen({super.key});

  @override
  State<AdminCouponsScreen> createState() => _AdminCouponsScreenState();
}

class _AdminCouponsScreenState extends State<AdminCouponsScreen> {
  static const Color _gold = Color(0xFFD4AF37);
  static const Color _panel = Color(0xFF180808);
  static const Color _bg = Color(0xFF000000);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<CouponsProvider>().startWatching();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      floatingActionButton: FloatingActionButton(
        backgroundColor: _gold,
        onPressed: _showCreateDialog,
        tooltip: 'إنشاء كوبون',
        child: const Icon(Icons.local_offer, color: Colors.black),
      ),
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          AppSliverBar(
            title: 'إدارة الكوبونات',
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: _gold),
              onPressed: () => Navigator.pop(context),
            ),
            automaticallyImplyLeading: false,
          ),
        ],
        body: Consumer<CouponsProvider>(
          builder: (context, provider, _) {
            if (provider.loading) {
              return const Center(
                  child: CircularProgressIndicator(color: _gold));
            }
            if (provider.coupons.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.local_offer_outlined,
                        color: Colors.white24, size: 72),
                    SizedBox(height: 16),
                    Text('لا توجد كوبونات حالياً',
                        style: TextStyle(
                            color: Colors.white54, fontSize: 18)),
                    SizedBox(height: 8),
                    Text('اضغط + لإنشاء كوبون جديد',
                        style: TextStyle(
                            color: Colors.white30, fontSize: 14)),
                  ],
                ),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: provider.coupons.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) =>
                  _CouponCard(coupon: provider.coupons[index]),
            );
          },
        ),
      ),
    );
  }

  // ── Dialog إنشاء كوبون ───────────────────────────────────────────────
  void _showCreateDialog() {
    final codeCtrl = TextEditingController();
    final valueCtrl = TextEditingController();
    final minOrderCtrl = TextEditingController();
    final maxDiscountCtrl = TextEditingController();
    final usageLimitCtrl = TextEditingController();
    final perUserLimitCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    CouponType type = CouponType.percent;
    DateTime? expiresAt;
    bool active = true;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: _panel,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('إنشاء كوبون جديد',
              style: TextStyle(
                  color: _gold, fontWeight: FontWeight.w700)),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _textField(
                    controller: codeCtrl,
                    label: 'كود الكوبون (WELCOME20)',
                    textCapitalization: TextCapitalization.characters,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
                  ),
                  const SizedBox(height: 12),
                  // Type selector
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        _typeTab(
                          label: 'نسبة %',
                          active: type == CouponType.percent,
                          onTap: () => setDialogState(
                              () => type = CouponType.percent),
                        ),
                        _typeTab(
                          label: 'مبلغ ثابت',
                          active: type == CouponType.fixed,
                          onTap: () => setDialogState(
                              () => type = CouponType.fixed),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _textField(
                    controller: valueCtrl,
                    label: type == CouponType.percent
                        ? 'النسبة (1-100)'
                        : 'قيمة الخصم (ج.س)',
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'مطلوب';
                      final n = double.tryParse(v);
                      if (n == null || n <= 0) return 'قيمة غير صالحة';
                      if (type == CouponType.percent && n > 100) {
                        return 'النسبة لا تتجاوز 100';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  _textField(
                    controller: minOrderCtrl,
                    label: 'أقل قيمة سلة (اختياري)',
                    keyboardType: TextInputType.number,
                  ),
                  if (type == CouponType.percent) ...[
                    const SizedBox(height: 12),
                    _textField(
                      controller: maxDiscountCtrl,
                      label: 'حد أقصى للخصم (اختياري)',
                      keyboardType: TextInputType.number,
                    ),
                  ],
                  const SizedBox(height: 12),
                  _textField(
                    controller: usageLimitCtrl,
                    label: 'عدد الاستخدامات الكلي (0 = بلا حد)',
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  _textField(
                    controller: perUserLimitCtrl,
                    label: 'حد لكل مستخدم (0 = بلا حد)',
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  // Expiry date
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          expiresAt == null
                              ? 'بلا تاريخ انتهاء'
                              : 'ينتهي: ${expiresAt!.day}/${expiresAt!.month}/${expiresAt!.year}',
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: ctx,
                            initialDate: DateTime.now()
                                .add(const Duration(days: 30)),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now()
                                .add(const Duration(days: 365 * 2)),
                            builder: (context, child) => Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: const ColorScheme.dark(
                                  primary: _gold,
                                  onPrimary: Colors.black,
                                  surface: _panel,
                                ),
                              ),
                              child: child!,
                            ),
                          );
                          if (picked != null) {
                            setDialogState(() => expiresAt = picked);
                          }
                        },
                        child: const Text('تحديد',
                            style: TextStyle(color: _gold)),
                      ),
                      if (expiresAt != null)
                        IconButton(
                          icon: const Icon(Icons.clear,
                              color: Colors.white54, size: 18),
                          onPressed: () =>
                              setDialogState(() => expiresAt = null),
                        ),
                    ],
                  ),
                  // Active toggle
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('مفعَّل',
                        style: TextStyle(color: Colors.white)),
                    value: active,
                    activeColor: _gold,
                    onChanged: (v) => setDialogState(() => active = v),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء',
                  style: TextStyle(color: Colors.white54)),
            ),
            Consumer<CouponsProvider>(
              builder: (_, p, __) => TextButton(
                onPressed: p.busy
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        final auth = context.read<AuthProvider>();
                        final adminUid = auth.user?.uid ?? '';
                        final input = CouponInput(
                          code: codeCtrl.text.trim().toUpperCase(),
                          type: type,
                          value: double.parse(valueCtrl.text),
                          minOrderValue:
                              double.tryParse(minOrderCtrl.text) ?? 0,
                          maxDiscount:
                              double.tryParse(maxDiscountCtrl.text) ?? 0,
                          expiresAt: expiresAt,
                          usageLimit:
                              int.tryParse(usageLimitCtrl.text) ?? 0,
                          perUserLimit:
                              int.tryParse(perUserLimitCtrl.text) ?? 0,
                          active: active,
                        );
                        final messenger = ScaffoldMessenger.of(context);
                        final ok = await context
                            .read<CouponsProvider>()
                            .createCoupon(input, adminUid);
                        if (!ctx.mounted) return;
                        Navigator.pop(ctx);
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(ok
                                ? 'تم إنشاء الكوبون ✓'
                                : (p.failure?.message ?? 'فشل الإنشاء')),
                            backgroundColor: ok
                                ? Colors.green
                                : Colors.orange,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                child: p.busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            color: _gold, strokeWidth: 2),
                      )
                    : const Text('إنشاء',
                        style: TextStyle(
                            color: _gold, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String label,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      style: const TextStyle(color: Colors.white),
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54, fontSize: 13),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.07),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _typeTab({
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? _gold : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: active ? Colors.black : Colors.white54,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}

class _CouponCard extends StatelessWidget {
  final CouponEntity coupon;
  const _CouponCard({required this.coupon});

  static const Color _gold = Color(0xFFD4AF37);
  static const Color _panel = Color(0xFF180808);

  @override
  Widget build(BuildContext context) {
    final isExpired = coupon.isExpired;
    final isUsedUp = coupon.hasReachedUsageLimit;
    final isInactive = !coupon.active || isExpired || isUsedUp;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color:
                isInactive ? Colors.red.withValues(alpha: 0.3) : Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _gold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _gold.withValues(alpha: 0.5)),
                ),
                child: Text(
                  coupon.code,
                  style: const TextStyle(
                      color: _gold,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      letterSpacing: 1.2),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                coupon.type == CouponType.percent
                    ? 'خصم ${coupon.value.toStringAsFixed(0)}%'
                    : 'خصم ${coupon.value.toStringAsFixed(0)} ج.س',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => _confirmDelete(context),
                icon: const Icon(Icons.delete_outline,
                    color: Colors.red, size: 22),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (coupon.minOrderValue > 0)
            _infoRow(
                'الحد الأدنى:', '${coupon.minOrderValue.toStringAsFixed(0)} ج.س'),
          if (coupon.maxDiscount > 0)
            _infoRow('حد أقصى للخصم:',
                '${coupon.maxDiscount.toStringAsFixed(0)} ج.س'),
          if (coupon.usageLimit > 0)
            _infoRow('الاستخدامات:',
                '${coupon.usedCount} / ${coupon.usageLimit}'),
          if (coupon.perUserLimit > 0)
            _infoRow('لكل مستخدم:', '${coupon.perUserLimit} مرة'),
          if (coupon.expiresAt != null)
            _infoRow('ينتهي في:',
                '${coupon.expiresAt!.day}/${coupon.expiresAt!.month}/${coupon.expiresAt!.year}'),
          if (isInactive) ...[
            const SizedBox(height: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                isExpired
                    ? 'منتهي الصلاحية'
                    : isUsedUp
                        ? 'استُنفد'
                        : 'معطّل',
                style: const TextStyle(
                    color: Colors.red,
                    fontSize: 11,
                    fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoRow(String k, String v) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          children: [
            Text(k,
                style:
                    const TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(width: 6),
            Text(v,
                style: const TextStyle(
                    color: Colors.white, fontSize: 12)),
          ],
        ),
      );

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _panel,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('حذف الكوبون',
            style: TextStyle(color: Colors.white)),
        content: Text(
          'هل تريد حذف الكوبون "${coupon.code}" نهائياً؟',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child:
                const Text('إلغاء', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!context.mounted) return;
    final ok =
        await context.read<CouponsProvider>().deleteCoupon(coupon.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'تم الحذف ✓' : 'فشل الحذف'),
        backgroundColor: ok ? Colors.green : Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
