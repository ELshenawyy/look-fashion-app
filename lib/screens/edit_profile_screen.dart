import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl_phone_field/country_picker_dialog.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:my_fashion_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:my_fashion_app/features/profile/presentation/providers/profile_provider.dart';
import 'package:my_fashion_app/shared/widgets/otp_pin_field.dart';
import 'package:my_fashion_app/widgets/app_sliver_bar.dart';
import 'package:my_fashion_app/widgets/user_avatar.dart';
import 'package:provider/provider.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  static const Color _gold = Color(0xFFD4AF37);
  static const Color _panel = Color(0xFF180808);

  final _nameController = TextEditingController();
  final _currentPassController = TextEditingController();
  final _newPassController = TextEditingController();
  final _confirmPassController = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void initState() {
    super.initState();
    _nameController.text =
        context.read<AuthProvider>().user?.displayName ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _currentPassController.dispose();
    _newPassController.dispose();
    _confirmPassController.dispose();
    super.dispose();
  }

  // ── Pick Image ────────────────────────────────────────────────────────
  Future<void> _pickImage(ImageSource source) async {
    Navigator.pop(context); // close bottom sheet
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      imageQuality: 75,
      maxWidth: 800,
    );
    if (picked == null || !mounted) return;

    final provider = context.read<ProfileProvider>();
    final uid = context.read<AuthProvider>().user?.uid;
    if (uid == null) return;
    final success = await provider.uploadProfileImage(uid, File(picked.path));

    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('تم تحديث صورة الملف الشخصي'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(provider.errorMessage ?? 'فشل رفع الصورة'),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  void _showImageSourceSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined, color: _gold),
                title: const Text('معرض الصور',
                    style: TextStyle(color: Colors.white)),
                onTap: () => _pickImage(ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined, color: _gold),
                title: const Text('الكاميرا',
                    style: TextStyle(color: Colors.white)),
                onTap: () => _pickImage(ImageSource.camera),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Save Name ─────────────────────────────────────────────────────────
  Future<void> _saveName() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showSnack('يرجى إدخال الاسم', Colors.orange);
      return;
    }
    if (name.length < 3) {
      _showSnack('الاسم قصير جداً — 3 أحرف على الأقل', Colors.orange);
      return;
    }

    final provider = context.read<ProfileProvider>();
    final uid = context.read<AuthProvider>().user?.uid;
    if (uid == null) return;
    final success = await provider.updateName(uid, name);

    if (!mounted) return;
    if (success) {
      _showSnack('تم تحديث الاسم بنجاح', Colors.green);
    } else {
      _showSnack(provider.errorMessage ?? 'فشل التحديث', Colors.red);
    }
  }

  // ── Change Password ───────────────────────────────────────────────────
  Future<void> _changePassword() async {
    final current = _currentPassController.text;
    final newPass = _newPassController.text;
    final confirm = _confirmPassController.text;

    if (current.isEmpty || newPass.isEmpty || confirm.isEmpty) {
      _showSnack('يرجى ملء جميع حقول كلمة المرور', Colors.orange);
      return;
    }
    if (newPass.length < 8) {
      _showSnack('كلمة المرور الجديدة يجب أن تكون 8 أحرف على الأقل', Colors.orange);
      return;
    }
    if (newPass != confirm) {
      _showSnack('كلمة المرور الجديدة وتأكيدها غير متطابقتين', Colors.orange);
      return;
    }

    final provider = context.read<ProfileProvider>();
    final success = await provider.changePassword(
      currentPassword: current,
      newPassword: newPass,
    );

    if (!mounted) return;
    if (success) {
      _currentPassController.clear();
      _newPassController.clear();
      _confirmPassController.clear();
      _showSnack('تم تغيير كلمة المرور بنجاح', Colors.green);
    } else {
      _showSnack(provider.errorMessage ?? 'فشل تغيير كلمة المرور', Colors.red);
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
    ));
  }

  // ── Build ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: CustomScrollView(
        slivers: [
          AppSliverBar(
            title: 'تعديل الملف الشخصي',
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
                // ── Profile Image ──────────────────────────────────────
                _sectionTitle('صورة الملف الشخصي'),
                const SizedBox(height: 16),
                Center(
                  child: Consumer<ProfileProvider>(
                    builder: (_, provider, __) {
                      return Stack(
                        children: [
                          const UserAvatarWidget(radius: 50),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: provider.isUploadingImage
                                  ? null
                                  : _showImageSourceSheet,
                              child: Container(
                                width: 34,
                                height: 34,
                                decoration: const BoxDecoration(
                                  color: _gold,
                                  shape: BoxShape.circle,
                                ),
                                child: provider.isUploadingImage
                                    ? const Padding(
                                        padding: EdgeInsets.all(8),
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.black,
                                        ),
                                      )
                                    : const Icon(Icons.camera_alt,
                                        color: Colors.black, size: 18),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 32),

                // ── Edit Name ──────────────────────────────────────────
                _sectionTitle('تعديل الاسم'),
                const SizedBox(height: 12),
                _inputField(
                  controller: _nameController,
                  label: 'الاسم الكامل',
                  icon: Icons.person_outline_rounded,
                ),
                const SizedBox(height: 12),
                Consumer<ProfileProvider>(
                  builder: (_, provider, __) => SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: provider.isSavingName ? null : _saveName,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _gold,
                        foregroundColor: Colors.black,
                        disabledBackgroundColor: Colors.grey[700],
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        textStyle: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                      child: provider.isSavingName
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.black),
                            )
                          : const Text('حفظ الاسم'),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                const Divider(color: Colors.white12),
                const SizedBox(height: 24),

                // ── Change Password — فقط لمستخدمي البريد ──
                // مستخدمو الـ OTP لا يملكون كلمة سر — Firebase Phone Auth
                // يستخدم credential مؤقت لكل دخول. نخفي هذا الـ section
                // ونعرض بدلاً منه card تعديل رقم الهاتف.
                Builder(
                  builder: (context) {
                    final user = context.watch<AuthProvider>().user;
                    final hasEmail = (user?.email ?? '').isNotEmpty;
                    final hasPhone = (user?.phone ?? '').isNotEmpty;

                    if (hasEmail) {
                      return _buildPasswordSection();
                    } else if (hasPhone) {
                      return _buildPhoneInfoCard(user!.phone!);
                    }
                    // مستخدم بدون email ولا phone — لا نعرض شيء
                    return const SizedBox.shrink();
                  },
                ),
                const SizedBox(height: 32),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ── Password section (لمستخدمي البريد فقط) ─────────────────────────
  Widget _buildPasswordSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('تغيير كلمة المرور'),
        const SizedBox(height: 12),
        _passwordField(
          controller: _currentPassController,
          label: 'كلمة المرور الحالية',
          obscure: _obscureCurrent,
          onToggle: () =>
              setState(() => _obscureCurrent = !_obscureCurrent),
        ),
        const SizedBox(height: 12),
        _passwordField(
          controller: _newPassController,
          label: 'كلمة المرور الجديدة',
          obscure: _obscureNew,
          onToggle: () => setState(() => _obscureNew = !_obscureNew),
        ),
        const SizedBox(height: 12),
        _passwordField(
          controller: _confirmPassController,
          label: 'تأكيد كلمة المرور الجديدة',
          obscure: _obscureConfirm,
          onToggle: () =>
              setState(() => _obscureConfirm = !_obscureConfirm),
        ),
        const SizedBox(height: 12),
        Consumer<ProfileProvider>(
          builder: (_, provider, __) => SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed:
                  provider.isChangingPassword ? null : _changePassword,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5A1010),
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey[700],
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                textStyle: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 15),
              ),
              child: provider.isChangingPassword
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('تغيير كلمة المرور'),
            ),
          ),
        ),
      ],
    );
  }

  // ── Phone info card (لمستخدمي OTP) ─────────────────────────────────
  Widget _buildPhoneInfoCard(String phone) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('رقم الهاتف'),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: _panel,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _gold.withValues(alpha: 0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _gold.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.phone_iphone,
                        color: _gold, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'رقمك الحالي',
                          style: TextStyle(
                              color: Colors.white60, fontSize: 12),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          phone,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                          textDirection: TextDirection.ltr,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Text(
                'يمكنك تغيير رقم هاتفك. ستُرسل لك رسالة OTP على الرقم الجديد للتحقّق منه قبل التحديث.',
                style: TextStyle(
                  color: Colors.white60,
                  fontSize: 12,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _startPhoneUpdateFlow,
                  icon: const Icon(Icons.edit_outlined,
                      color: _gold, size: 20),
                  label: const Text(
                    'تعديل رقم الهاتف',
                    style: TextStyle(
                        color: _gold, fontWeight: FontWeight.w700),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                        color: _gold.withValues(alpha: 0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Phone Update Flow (3 خطوات: رقم جديد → OTP → تحديث) ─────────
  Future<void> _startPhoneUpdateFlow() async {
    // الخطوة 1: dialog لإدخال الرقم الجديد
    final newPhone = await _showNewPhoneDialog();
    if (newPhone == null || newPhone.isEmpty || !mounted) return;

    // إرسال OTP للرقم الجديد
    final messenger = ScaffoldMessenger.of(context);
    final auth = context.read<AuthProvider>();
    final result = await auth.requestPhoneUpdate(newPhone);
    if (!mounted) return;
    if (result == null) {
      messenger.showSnackBar(SnackBar(
        content: Text(auth.failure?.message ?? 'فشل إرسال الرمز'),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    // الخطوة 2: dialog لإدخال OTP المُستلَم
    final smsCode = await _showOtpDialog(newPhone);
    if (smsCode == null || smsCode.length < 6 || !mounted) return;

    // الخطوة 3: تأكيد التحديث
    final ok = await auth.confirmPhoneUpdate(
      verificationId: result.verificationId,
      smsCode: smsCode,
    );
    if (!mounted) return;
    if (ok) {
      messenger.showSnackBar(const SnackBar(
        content: Text('تم تحديث رقم الهاتف بنجاح ✓'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ));
    } else {
      messenger.showSnackBar(SnackBar(
        content: Text(auth.failure?.message ?? 'فشل تحديث الرقم'),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
      ));
    }
  }

  Future<String?> _showNewPhoneDialog() async {
    String complete = '';
    bool isValid = false;
    return showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          backgroundColor: _panel,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18)),
          title: const Text('رقم الهاتف الجديد',
              style:
                  TextStyle(color: _gold, fontWeight: FontWeight.w700)),
          content: SizedBox(
            width: double.maxFinite,
            child: IntlPhoneField(
              initialCountryCode: 'SD',
              languageCode: 'ar',
              showCountryFlag: true,
              dropdownIcon:
                  const Icon(Icons.arrow_drop_down, color: Colors.white70),
              dropdownTextStyle: const TextStyle(color: Colors.white),
              style: const TextStyle(color: Colors.white),
              pickerDialogStyle: PickerDialogStyle(
                searchFieldInputDecoration: const InputDecoration(
                  hintText: 'ابحث عن الدولة',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
              decoration: InputDecoration(
                hintText: 'رقم الهاتف',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.07),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (p) {
                setSt(() {
                  complete = p.completeNumber.replaceAll(RegExp(r'\s+'), '');
                  isValid =
                      p.number.isNotEmpty && complete.startsWith('+');
                });
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء',
                  style: TextStyle(color: Colors.white54)),
            ),
            TextButton(
              onPressed: isValid ? () => Navigator.pop(ctx, complete) : null,
              child: const Text('إرسال OTP',
                  style: TextStyle(
                      color: _gold, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _showOtpDialog(String phone) async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: _panel,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18)),
        title: const Text('أدخل رمز التحقّق',
            style: TextStyle(color: _gold, fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'أدخل الرمز المرسَل إلى $phone',
              style:
                  const TextStyle(color: Colors.white70, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            OtpPinField(
              controller: ctrl,
              length: 6,
              themeColor: _gold,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء',
                style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('تأكيد',
                style:
                    TextStyle(color: _gold, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    ).then((v) {
      ctrl.dispose();
      return v;
    });
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: _gold,
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _inputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
  }) {
    return TextField(
      controller: controller,
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

  Widget _passwordField({
    required TextEditingController controller,
    required String label,
    required bool obscure,
    required VoidCallback onToggle,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54),
        prefixIcon: const Icon(Icons.lock_outline_rounded, color: _gold),
        suffixIcon: IconButton(
          icon: Icon(
            obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            color: Colors.white38,
          ),
          onPressed: onToggle,
        ),
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

