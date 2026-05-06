import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
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

  // ── إلغاء صلاحيات الموظف ───────────────────────────────────────────
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
          'هل تريد إلغاء صلاحيات "$name"؟\nسيتم طرده من التطبيق فوراً.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء', style: TextStyle(color: Colors.white54)),
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
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'role': AppRole.user,
        'revokedAt': FieldValue.serverTimestamp(),
      });
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

  // ── ترقية مستخدم إلى subAdmin ─────────────────────────────────────
  void _showAddStaffDialog() {
    final emailCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isLoading = false;

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
                const Text(
                  'أدخل إيميل المستخدم الذي تريد ترقيته إلى موظف (subAdmin):',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'البريد الإلكتروني',
                    labelStyle: const TextStyle(color: Colors.white54),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.07),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon:
                        const Icon(Icons.email_outlined, color: Colors.white38),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'أدخل البريد الإلكتروني';
                    }
                    if (!v.contains('@')) return 'بريد إلكتروني غير صالح';
                    return null;
                  },
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
                          ctx, emailCtrl.text.trim().toLowerCase());
                      setDialogState(() => isLoading = false);
                    },
              child: isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          color: _gold, strokeWidth: 2),
                    )
                  : const Text('ترقية',
                      style: TextStyle(color: _gold, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _promoteToSubAdmin(BuildContext dialogCtx, String email) async {
    String? errorMsg;
    String? successMsg;

    try {
      final query = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        errorMsg = 'لا يوجد مستخدم بهذا البريد الإلكتروني';
      } else {
        final docRef = query.docs.first.reference;
        final currentRole =
            query.docs.first.data()['role'] as String? ?? AppRole.user;

        if (AppRole.isSuperAdmin(currentRole)) {
          errorMsg = 'لا يمكن تغيير دور السوبر أدمن';
        } else {
          // إزالة revokedAt إن وُجد + ترقية الدور
          await docRef.update({
            'role': AppRole.subAdmin,
            'revokedAt': FieldValue.delete(),
          });
          successMsg = 'تمت ترقية "$email" إلى موظف بنجاح';
        }
      }
    } catch (e) {
      errorMsg = 'خطأ: $e';
    }

    // إغلاق الـ Dialog ثم عرض النتيجة
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
      ));
    }
  }

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
                final createdAt = data['createdAt'] as Timestamp?;
                final dateStr = createdAt != null
                    ? '${createdAt.toDate().day}/${createdAt.toDate().month}/${createdAt.toDate().year}'
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
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: _gold.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.person,
                            color: _gold, size: 24),
                      ),
                      const SizedBox(width: 12),
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
                            Text(email,
                                style: const TextStyle(
                                    color: Colors.white54, fontSize: 12)),
                            const SizedBox(height: 2),
                            Text('أُضيف: $dateStr',
                                style: const TextStyle(
                                    color: Colors.white30, fontSize: 11)),
                          ],
                        ),
                      ),
                      // زر إلغاء الصلاحيات
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
