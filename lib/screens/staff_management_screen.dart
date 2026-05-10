import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:my_fashion_app/repositories/admin_repository.dart';
import 'package:my_fashion_app/services/role_service.dart';
import 'package:my_fashion_app/widgets/app_sliver_bar.dart';

/// شاشة إدارة الموظفين — متاحة للـ superAdmin فقط.
/// تعرض قائمة الـ subAdmins وتتيح إضافتهم أو إلغاء صلاحياتهم.
class StaffManagementScreen extends StatefulWidget {
  const StaffManagementScreen({super.key});

  @override
  State<StaffManagementScreen> createState() => _StaffManagementScreenState();
}

class _StaffManagementScreenState extends State<StaffManagementScreen> {
  static const Color _gold = Color(0xFFD4AF37);
  static const Color _panel = Color(0xFF180808);

  final _repo = AdminRepository();

  // ── إلغاء صلاحيات الموظف ───────────────────────────────────────────────
  Future<void> _revokeAccess(String uid, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _panel,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'إلغاء الصلاحيات',
          style: TextStyle(color: _gold, fontWeight: FontWeight.w700),
        ),
        content: Text(
          'هل تريد إلغاء صلاحيات "$name"؟\nسيتم طرده من لوحة الإدارة فوراً.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child:
                const Text('إلغاء', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('إلغاء الصلاحيات',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _repo.revokeAdmin(uid);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم إلغاء صلاحيات "$name" بنجاح'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ── إضافة موظف جديد ────────────────────────────────────────────────────
  void _showAddStaffDialog() {
    final inputCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isLoading = false;
    bool isEmail = true; // toggle بين إيميل ورقم هاتف

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: _panel,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            'إضافة موظف جديد',
            style: TextStyle(color: _gold, fontWeight: FontWeight.w700),
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Toggle: إيميل أو هاتف ──
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      _toggleTab(
                        label: 'البريد الإلكتروني',
                        icon: Icons.email_outlined,
                        isActive: isEmail,
                        onTap: () {
                          setDialogState(() {
                            isEmail = true;
                            inputCtrl.clear();
                          });
                        },
                      ),
                      _toggleTab(
                        label: 'رقم الهاتف',
                        icon: Icons.phone_outlined,
                        isActive: !isEmail,
                        onTap: () {
                          setDialogState(() {
                            isEmail = false;
                            inputCtrl.clear();
                          });
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // ── حقل الإدخال ──
                TextFormField(
                  controller: inputCtrl,
                  keyboardType: isEmail
                      ? TextInputType.emailAddress
                      : TextInputType.phone,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: isEmail
                        ? 'البريد الإلكتروني'
                        : 'رقم الهاتف (مثال: 0912345678)',
                    labelStyle: const TextStyle(color: Colors.white54),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.07),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon: Icon(
                      isEmail ? Icons.email_outlined : Icons.phone_outlined,
                      color: Colors.white38,
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return isEmail
                          ? 'أدخل البريد الإلكتروني'
                          : 'أدخل رقم الهاتف';
                    }
                    if (isEmail && !v.contains('@')) {
                      return 'بريد إلكتروني غير صالح';
                    }
                    if (!isEmail && v.trim().length < 9) {
                      return 'رقم هاتف غير صالح';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                const Text(
                  'سيتم البحث عن الحساب في قاعدة البيانات وترقيته فوراً.',
                  style: TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء',
                  style: TextStyle(color: Colors.white54)),
            ),
            TextButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => isLoading = true);
                      await _promoteToSubAdmin(
                          ctx, inputCtrl.text.trim());
                      if (ctx.mounted) {
                        setDialogState(() => isLoading = false);
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          color: _gold, strokeWidth: 2),
                    )
                  : const Text('ترقية',
                      style: TextStyle(
                          color: _gold, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  // ── منطق الترقية عبر AdminRepository ──────────────────────────────────
  Future<void> _promoteToSubAdmin(
      BuildContext dialogCtx, String identifier) async {
    String? errorMsg;
    String? successMsg;

    try {
      final result = await _repo.findUserByEmailOrPhone(identifier);

      if (result == null) {
        errorMsg = 'لا يوجد حساب مرتبط بهذا البريد أو الرقم.\n'
            'تأكد من أن المستخدم سجّل في التطبيق أولاً.';
      } else if (AppRole.isSuperAdmin(result.role)) {
        errorMsg = 'لا يمكن تغيير دور السوبر أدمن';
      } else if (result.role == AppRole.subAdmin) {
        errorMsg = '"${result.name}" موظف بالفعل.';
      } else {
        await _repo.promoteToSubAdmin(result.uid);
        successMsg = 'تمت ترقية "${result.name}" إلى موظف بنجاح ✓';
      }
    } catch (e) {
      errorMsg = 'خطأ: $e';
    }

    if (!mounted) return;
    if (dialogCtx.mounted) Navigator.pop(dialogCtx);

    if (successMsg != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(successMsg),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ));
    } else if (errorMsg != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(errorMsg),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
      ));
    }
  }

  // ── Toggle Tab Helper ──────────────────────────────────────────────────
  Widget _toggleTab({
    required String label,
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isActive ? _gold : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 14,
                  color: isActive ? Colors.black : Colors.white54),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isActive ? Colors.black : Colors.white54,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      floatingActionButton: FloatingActionButton(
        backgroundColor: _gold,
        onPressed: _showAddStaffDialog,
        tooltip: 'إضافة موظف',
        child: const Icon(Icons.person_add_alt_1, color: Colors.black),
      ),
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          AppSliverBar(
            title: 'إدارة الموظفين',
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _gold),
              onPressed: () => Navigator.pop(context),
            ),
            automaticallyImplyLeading: false,
          ),
        ],
        body: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .where('role', isEqualTo: AppRole.subAdmin)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                  child: CircularProgressIndicator(color: _gold));
            }
            if (snapshot.hasError) {
              return Center(
                child: Text('خطأ: ${snapshot.error}',
                    style: const TextStyle(color: Colors.red)),
              );
            }

            final docs = snapshot.data?.docs ?? [];

            if (docs.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.manage_accounts,
                        color: Colors.white24, size: 72),
                    SizedBox(height: 16),
                    Text('لا يوجد موظفون حالياً',
                        style:
                            TextStyle(color: Colors.white54, fontSize: 18)),
                    SizedBox(height: 8),
                    Text('اضغط + لإضافة موظف جديد',
                        style:
                            TextStyle(color: Colors.white30, fontSize: 14)),
                  ],
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: docs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final data = docs[index].data() as Map<String, dynamic>;
                final uid = docs[index].id;
                final name = data['name'] as String? ?? 'موظف';
                final email = data['email'] as String? ?? '';
                final phone = data['phone'] as String? ?? '';
                final promotedAt = data['promotedAt'] as Timestamp?;
                final dateStr = promotedAt != null
                    ? '${promotedAt.toDate().day}/'
                        '${promotedAt.toDate().month}/'
                        '${promotedAt.toDate().year}'
                    : 'غير محدد';

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _panel,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Row(
                    children: [
                      // Avatar
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: _gold.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.person, color: _gold, size: 24),
                      ),
                      const SizedBox(width: 12),
                      // Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 2),
                            if (email.isNotEmpty)
                              Text(email,
                                  style: const TextStyle(
                                      color: Colors.white54, fontSize: 12)),
                            if (phone.isNotEmpty)
                              Text(phone,
                                  style: const TextStyle(
                                      color: Colors.white38, fontSize: 12)),
                            const SizedBox(height: 2),
                            Text('تاريخ الإضافة: $dateStr',
                                style: const TextStyle(
                                    color: Colors.white30, fontSize: 11)),
                          ],
                        ),
                      ),
                      // Revoke button
                      IconButton(
                        onPressed: () => _revokeAccess(uid, name),
                        icon: const Icon(Icons.person_remove,
                            color: Colors.red, size: 22),
                        tooltip: 'إلغاء الصلاحيات',
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
