import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl_phone_field/country_picker_dialog.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:my_fashion_app/core/di/injection_container.dart';
import 'package:my_fashion_app/features/admin/data/repositories/admin_repository.dart';
import 'package:my_fashion_app/features/auth/domain/entities/user_role.dart';
import 'package:my_fashion_app/widgets/app_sliver_bar.dart';

/// نتيجة عملية async (success/error) — تُمرَّر من الـ Firebase action
/// إلى الـ caller لعرض SnackBar **بعد** إغلاق الـ loader، تجنباً
/// لتداخل overlays وأخطاء "presented off screen".
class _OpResult {
  final String? success;
  final String? error;
  const _OpResult._({this.success, this.error});
  factory _OpResult.success(String msg) => _OpResult._(success: msg);
  factory _OpResult.error(String msg) => _OpResult._(error: msg);
}

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

  final _repo = sl<AdminRepository>();

  // ─── Blocking Loader ───────────────────────────────────────────────────
  /// يعرض overlay يحجب التفاعل ويُظهر "جاري المعالجة..."
  /// يُستخدم أثناء أي عملية async مع Firebase لمنع الـ user من
  /// التفاعل ولتوضيح أن النظام يعمل.
  Future<T> _runWithBlockingLoader<T>(
    Future<T> Function() action, {
    String message = 'جاري المعالجة...',
  }) async {
    // اعرض overlay غير قابل للإغلاق
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      // أغمق من قبل عشان يخفي محتوى الشاشة اللي وراه (زي أيقونة
      // "لا يوجد موظفون") ويمنع تداخله مع كارت التحميل.
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (_) => PopScope(
        canPop: false,
        child: Center(
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 32, vertical: 26),
            decoration: BoxDecoration(
              // لون أفتح من الخلفية السودة عشان الكارت يبان كـ"بوكس" واضح
              // بدل ما يختفي ويسيب بس الدائرة الذهبية والنص عائمين.
              color: const Color(0xFF2A1414),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: _gold.withValues(alpha: 0.6), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: _gold.withValues(alpha: 0.18),
                  blurRadius: 24,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 36,
                  height: 36,
                  child: CircularProgressIndicator(
                      color: _gold, strokeWidth: 3),
                ),
                const SizedBox(height: 16),
                Text(
                  message,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      return await action();
    } finally {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
    }
  }

  // ── إلغاء صلاحيات الموظف ───────────────────────────────────────────────
  Future<void> _revokeAccess(String uid, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _panel,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'طرد وحظر الموظف',
          style: TextStyle(color: _gold, fontWeight: FontWeight.w700),
        ),
        content: Text(
          'هل تريد طرد "$name" وحظره نهائياً؟\n'
          'سيتم طرده من لوحة الإدارة فوراً ولن يتمكن من تسجيل الدخول '
          'إلى التطبيق مرة أخرى.',
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
            child: const Text('طرد وحظر',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;

    // مسك messenger قبل أي pop
    final messenger = ScaffoldMessenger.of(context);

    // انتظر إطار لينتهي dispose الـ AlertDialog
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;

    final result = await _runWithBlockingLoader<_OpResult>(
      () async {
        try {
          await _repo.revokeAdmin(uid);
          return _OpResult.success('تم طرد "$name" وحظره من استخدام التطبيق');
        } catch (e) {
          return _OpResult.error('خطأ: $e');
        }
      },
      message: 'جاري طرد الموظف وحظره...',
    );

    await Future<void>.delayed(const Duration(milliseconds: 50));
    if (!mounted) return;
    _showResultSnackBar(messenger, result);
  }

  // ── إضافة موظف جديد ────────────────────────────────────────────────────
  void _showAddStaffDialog() {
    final inputCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isEmail = true; // toggle بين إيميل ورقم هاتف
    // للهاتف: نخزّن الرقم الكامل بصيغة E.164 (+249...) من IntlPhoneField
    String completePhone = '';
    bool isPhoneValid = false;

    showDialog<void>(
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
                            completePhone = '';
                            isPhoneValid = false;
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
                            completePhone = '';
                            isPhoneValid = false;
                          });
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // ── حقل الإدخال: إيميل عادي أو IntlPhoneField مع علم/كود الدولة ──
                if (isEmail)
                  TextFormField(
                    controller: inputCtrl,
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
                      prefixIcon: const Icon(Icons.email_outlined,
                          color: Colors.white38),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'أدخل البريد الإلكتروني';
                      }
                      if (!v.contains('@')) {
                        return 'بريد إلكتروني غير صالح';
                      }
                      return null;
                    },
                  )
                else
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: IntlPhoneField(
                    // السودان (+249) افتراضياً
                    initialCountryCode: 'SD',
                    languageCode: 'ar',
                    showCountryFlag: true,
                    dropdownIcon: const Icon(Icons.arrow_drop_down,
                        color: Colors.white70),
                    dropdownTextStyle:
                        const TextStyle(color: Colors.white),
                    style: const TextStyle(color: Colors.white),
                    pickerDialogStyle: PickerDialogStyle(
                      backgroundColor: _panel,
                      countryNameStyle:
                          const TextStyle(color: Colors.white),
                      countryCodeStyle:
                          const TextStyle(color: Colors.white70),
                      searchFieldInputDecoration: const InputDecoration(
                        hintText: 'ابحث عن الدولة',
                        prefixIcon: Icon(Icons.search),
                      ),
                    ),
                    decoration: InputDecoration(
                      labelText: 'رقم الهاتف',
                      labelStyle: const TextStyle(color: Colors.white54),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.07),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (p) {
                      setDialogState(() {
                        completePhone = p.completeNumber
                            .replaceAll(RegExp(r'\s+'), '');
                        isPhoneValid = p.number.isNotEmpty &&
                            completePhone.startsWith('+') &&
                            p.number.length >= 7;
                      });
                    },
                  ),
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
              onPressed: () async {
                // للإيميل: نتحقّق عبر الـ Form. للهاتف: عبر isPhoneValid
                // (IntlPhoneField لا يدعم Form validators بنفس الطريقة).
                if (isEmail) {
                  if (!formKey.currentState!.validate()) return;
                } else {
                  if (!isPhoneValid) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('أدخل رقم هاتف صحيح'),
                        backgroundColor: Colors.orange,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    return;
                  }
                }
                final identifier =
                    isEmail ? inputCtrl.text.trim() : completePhone;
                // مسك الـ messenger من الـ State context (مش من dialog ctx)
                // قبل أي pop لأن الـ context هيبقى deactivated بعدين.
                final messenger = ScaffoldMessenger.of(context);
                Navigator.pop(ctx); // يقفل الـ dialog + يفعّل .then() → dispose

                // انتظر إطار واحد لكي تنتهي animation الـ dispose قبل
                // فتح overlay الـ loader (يمنع _dependents.isEmpty assertion).
                await Future<void>.delayed(
                    const Duration(milliseconds: 250));
                if (!mounted) return;

                // نفّذ العملية مع overlay وأرجع النتيجة
                final result = await _runWithBlockingLoader<_OpResult>(
                  () => _doPromote(identifier),
                  message: 'جاري ترقية الموظف...',
                );

                // الـ loader اتقفل. أنتظر إطار قبل عرض SnackBar
                // (يضمن أن messenger مش بيدوّر على dialog منسحب).
                await Future<void>.delayed(
                    const Duration(milliseconds: 50));
                if (!mounted) return;
                _showResultSnackBar(messenger, result);
              },
              child: const Text('ترقية',
                  style: TextStyle(
                      color: _gold, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    ).then((_) {
      // أجّل dispose للإطار التالي لتفادي السباق مع validators/builders
      // اللي بتشتغل أثناء animation الإغلاق.
      WidgetsBinding.instance
          .addPostFrameCallback((_) => inputCtrl.dispose());
    });
  }

  // ── منطق الترقية عبر AdminRepository ──────────────────────────────────
  Future<_OpResult> _doPromote(String identifier) async {
    try {
      final result = await _repo.findUserByEmailOrPhone(identifier);

      if (result == null) {
        return _OpResult.error(
            'لا يوجد حساب مرتبط بهذا البريد أو الرقم.\n'
            'تأكد من أن المستخدم سجّل في التطبيق أولاً.');
      } else if (!result.emailVerified) {
        return _OpResult.error(
            'البريد الإلكتروني لـ "${result.name}" غير مفعّل.\n'
            'يجب على المستخدم تفعيل بريده أولاً قبل ترقيته.');
      } else if (UserRole.fromString(result.role).isSuperAdmin) {
        return _OpResult.error('لا يمكن تغيير دور السوبر أدمن');
      } else if (result.role == UserRole.subAdmin.toFirestoreValue()) {
        return _OpResult.error('"${result.name}" موظف بالفعل.');
      } else {
        await _repo.promoteToSubAdmin(result.uid);
        return _OpResult.success(
            'تمت ترقية "${result.name}" إلى موظف بنجاح ✓');
      }
    } catch (e) {
      return _OpResult.error('خطأ: $e');
    }
  }

  // ── عرض SnackBar نتيجة عبر messenger مُلتقَط مسبقاً ───────────────────
  void _showResultSnackBar(
      ScaffoldMessengerState messenger, _OpResult result) {
    if (result.success != null) {
      messenger.showSnackBar(SnackBar(
        content: Text(result.success!),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ));
    } else if (result.error != null) {
      messenger.showSnackBar(SnackBar(
        content: Text(result.error!),
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
              .where('role', isEqualTo: UserRole.subAdmin.toFirestoreValue())
              .snapshots(),
          builder: (context, snapshot) {
            // أوّل تحميل فقط — لا data بعد ولا error دائم
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Center(
                  child: CircularProgressIndicator(color: _gold));
            }

            // لا نُظهر الـ stream error كشاشة حمراء كاملة:
            // Firestore يُصدر errors transient بعد كل update يلمس حقل في where().
            // نُسجّل للـ debug فقط ونستمر بعرض آخر cached data.
            if (snapshot.hasError) {
              debugPrint(
                  'staff stream transient error: ${snapshot.error}');
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
                        tooltip: 'طرد وحظر',
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
