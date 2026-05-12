import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:my_fashion_app/features/addresses/domain/entities/address_entity.dart';
import 'package:my_fashion_app/features/addresses/presentation/providers/addresses_provider.dart';
import 'package:my_fashion_app/widgets/app_sliver_bar.dart';
import 'package:provider/provider.dart';

class AddressesScreen extends StatefulWidget {
  const AddressesScreen({super.key});

  @override
  State<AddressesScreen> createState() => _AddressesScreenState();
}

class _AddressesScreenState extends State<AddressesScreen> {
  static const Color _gold = Color(0xFFD4AF37);
  static const Color _panel = Color(0xFF180808);

  static const List<String> _sudanStates = [
    'الخرطوم', 'الجزيرة', 'النيل الأبيض', 'النيل الأزرق', 'نهر النيل',
    'البحر الأحمر', 'الشمالية', 'كسلا', 'القضارف', 'سنار',
    'شمال كردفان', 'جنوب كردفان', 'غرب كردفان',
    'شمال دارفور', 'جنوب دارفور', 'وسط دارفور', 'شرق دارفور', 'غرب دارفور',
  ];

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    final uid = _uid;
    if (uid != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<AddressesProvider>().startWatching(uid);
      });
    }
  }

  Future<void> _showAddSheet(BuildContext context) async {
    final labelCtrl = TextEditingController();
    final streetCtrl = TextEditingController();
    final buildingCtrl = TextEditingController();
    String? selectedState;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFF180808),
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(24)),
                ),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'إضافة عنوان جديد',
                      style: TextStyle(
                        color: _gold,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _sheetField(
                      ctrl: labelCtrl,
                      label: 'التسمية (مثال: المنزل، العمل)',
                      icon: Icons.label_outline,
                    ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF121212),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white12),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedState,
                          isExpanded: true,
                          dropdownColor: const Color(0xFF1E1010),
                          icon: const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: _gold),
                          hint: const Row(
                            children: [
                              Icon(Icons.map_outlined,
                                  color: _gold, size: 20),
                              SizedBox(width: 12),
                              Text('اختر الولاية',
                                  style:
                                      TextStyle(color: Colors.white54)),
                            ],
                          ),
                          items: _sudanStates
                              .map((s) => DropdownMenuItem(
                                    value: s,
                                    child: Text(s,
                                        style: const TextStyle(
                                            color: Colors.white)),
                                  ))
                              .toList(),
                          onChanged: (v) =>
                              setSheetState(() => selectedState = v),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _sheetField(
                      ctrl: streetCtrl,
                      label: 'الشارع / الحي',
                      icon: Icons.route_outlined,
                    ),
                    const SizedBox(height: 12),
                    _sheetField(
                      ctrl: buildingCtrl,
                      label: 'رقم البناية / المنزل',
                      icon: Icons.home_outlined,
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          final label = labelCtrl.text.trim();
                          final street = streetCtrl.text.trim();
                          final building = buildingCtrl.text.trim();
                          if (label.isEmpty ||
                              selectedState == null ||
                              street.isEmpty) {
                            ScaffoldMessenger.of(context)
                                .showSnackBar(const SnackBar(
                              content: Text(
                                  'يرجى ملء التسمية والولاية والشارع على الأقل'),
                              backgroundColor: Colors.orange,
                              behavior: SnackBarBehavior.floating,
                            ));
                            return;
                          }
                          final uid = _uid;
                          if (uid == null) return;
                          final ok = await ctx
                              .read<AddressesProvider>()
                              .add(
                                userId: uid,
                                label: label,
                                region: selectedState!,
                                street: street,
                                building: building,
                              );
                          if (!ctx.mounted) return;
                          if (ok) {
                            Navigator.pop(ctx);
                          } else {
                            final f = ctx
                                .read<AddressesProvider>()
                                .failure;
                            if (f != null) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(
                                  content: Text(f.message),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              ctx.read<AddressesProvider>().clearFailure();
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _gold,
                          foregroundColor: Colors.black,
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          textStyle: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                        child: const Text('حفظ العنوان'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    labelCtrl.dispose();
    streetCtrl.dispose();
    buildingCtrl.dispose();
  }

  Future<void> _deleteAddress(
      BuildContext context, String docId, String label) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _panel,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('حذف العنوان',
            style: TextStyle(color: _gold, fontWeight: FontWeight.w700)),
        content: Text(
          'هل تريد حذف عنوان "$label"؟',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء',
                style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final uid = _uid;
    if (uid == null) return;
    if (!context.mounted) return;
    await context
        .read<AddressesProvider>()
        .delete(userId: uid, addressId: docId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: CustomScrollView(
        slivers: [
          AppSliverBar(
            title: 'عناوين الشحن',
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: _gold),
              onPressed: () => Navigator.pop(context),
            ),
            automaticallyImplyLeading: false,
          ),
          Consumer<AddressesProvider>(
            builder: (ctx, provider, _) {
              if (provider.loading) {
                return const SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(color: _gold),
                  ),
                );
              }

              final addresses = provider.addresses;

              if (addresses.isEmpty) {
                return SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 90,
                          height: 90,
                          decoration: BoxDecoration(
                            color: _gold.withValues(alpha: 0.08),
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: _gold.withValues(alpha: 0.25),
                                width: 1.5),
                          ),
                          child: const Icon(Icons.location_off_outlined,
                              color: _gold, size: 40),
                        ),
                        const SizedBox(height: 20),
                        const Text('لا توجد عناوين محفوظة',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        const Text(
                          'أضف عنوانك لتسريع عملية الشراء',
                          style: TextStyle(
                              color: Colors.white54, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) {
                      final AddressEntity addr = addresses[i];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _panel,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: _gold.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                  Icons.location_on_outlined,
                                  color: _gold,
                                  size: 22),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(addr.label,
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${addr.region} — ${addr.street}'
                                    '${addr.building.isNotEmpty ? ' — ${addr.building}' : ''}',
                                    style: const TextStyle(
                                        color: Colors.white54,
                                        fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  color: Colors.redAccent, size: 22),
                              onPressed: () =>
                                  _deleteAddress(context, addr.id, addr.label),
                            ),
                          ],
                        ),
                      );
                    },
                    childCount: addresses.length,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddSheet(context),
        backgroundColor: _gold,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add),
        label: const Text('إضافة عنوان',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }

  static Widget _sheetField({
    required TextEditingController ctrl,
    required String label,
    required IconData icon,
  }) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54),
        prefixIcon: Icon(icon, color: _gold),
        filled: true,
        fillColor: const Color(0xFF121212),
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
