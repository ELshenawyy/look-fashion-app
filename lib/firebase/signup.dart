import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:intl_phone_field/country_picker_dialog.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:my_fashion_app/core/error/failures.dart';
import 'package:my_fashion_app/core/utils/password_validator.dart';
import 'package:my_fashion_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:my_fashion_app/firebase/otp_screen.dart';
import 'package:my_fashion_app/screens/app_shell.dart';
import 'package:provider/provider.dart';

import 'login.dart';

class Signup extends StatefulWidget {
  const Signup({super.key});

  @override
  State<Signup> createState() => _SignupState();
}

class _SignupState extends State<Signup> {
  static const Color _themeColor = Color(0xFF570707);

  // ── Tabs ──────────────────────────────────────────────────────────────
  int _tabIndex = 0; // 0 = هاتف, 1 = بريد
  final PageController _pageController = PageController();

  // ── Email signup ──────────────────────────────────────────────────────
  final _emailFormKey = GlobalKey<FormState>();
  String _name = '';
  String _email = '';
  String _password = '';
  String _confirmPassword = '';
  bool _obscureText = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  String? _emailError;

  // ── Phone signup ──────────────────────────────────────────────────────
  final _phoneFormKey = GlobalKey<FormState>();
  final _phoneNameController = TextEditingController();
  final _phoneController = TextEditingController();
  String _completePhoneNumber = '';
  bool _isPhoneValid = false;
  bool _isPhoneSending = false;

  /// يحدّد لو زر "إنشاء حساب" بالبريد يجب أن يكون enabled بصرياً
  /// (مطابق لسلوك زر الهاتف اللي يضيء لما الرقم صالح).
  bool get _isEmailSignupValid =>
      _emailError == null &&
      _name.trim().isNotEmpty &&
      _name.trim().length >= 3 &&
      _email.trim().isNotEmpty &&
      PasswordValidator.isStrong(_password) &&
      _password == _confirmPassword;

  @override
  void dispose() {
    _pageController.dispose();
    _phoneNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  // ── Real-time email validation ────────────────────────────────────────
  void _onEmailChanged(String value) {
    setState(() {
      _email = value;
      if (value.isEmpty) {
        _emailError = null;
      } else if (!RegExp(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")
          .hasMatch(value.trim())) {
        _emailError = 'بريد إلكتروني غير صالح';
      } else {
        _emailError = null;
      }
    });
  }

  // ── Password strength ─────────────────────────────────────────────────
  // نستخدم PasswordValidator المشترك (lib/core/utils/password_validator.dart)
  double _passwordStrength(String pwd) => PasswordValidator.strength(pwd);

  Color _strengthColor(double s) {
    if (s < 0.5) return Colors.red;
    if (s < 1.0) return Colors.orange;
    return Colors.green;
  }

  String _strengthLabel(double s) {
    if (s < 0.5) return 'ضعيفة';
    if (s < 1.0) return 'متوسطة';
    return 'قوية';
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
    ));
  }

  // ── Email signup submit ───────────────────────────────────────────────
  Future<void> _submitEmailSignUp() async {
    if (_emailFormKey.currentState == null ||
        !_emailFormKey.currentState!.validate()) {
      return;
    }

    if (_password != _confirmPassword) {
      _showSnack('كلمة المرور وتأكيدها غير متطابقين', Colors.red);
      return;
    }

    setState(() => _isLoading = true);

    final auth = context.read<AuthProvider>();
    final ok = await auth.signUpWithEmail(
      email: _email.trim(),
      password: _password,
      name: _name.trim(),
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (ok) {
      _showSnack('تم إنشاء الحساب بنجاح.', Colors.green);
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AppShell()),
        (route) => false,
      );
    } else if (auth.failure != null) {
      _showSnack(auth.failure!.message, Colors.red);
      auth.clearFailure();
    }
  }

  // ── Phone signup submit ───────────────────────────────────────────────
  Future<void> _submitPhoneSignUp() async {
    if (!(kIsWeb ||
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS)) {
      _showSnack(
        'التسجيل عبر الهاتف متاح فقط على أندرويد وiOS والويب.',
        Colors.orange,
      );
      return;
    }

    if (!(_phoneFormKey.currentState?.validate() ?? false)) return;

    final name = _phoneNameController.text.trim();
    final phone = _completePhoneNumber.replaceAll(RegExp(r'\s+'), '');

    if (phone.isEmpty || !_isPhoneValid) {
      _showSnack('يرجى إدخال رقم هاتف صحيح مع مفتاح الدولة.', Colors.orange);
      return;
    }
    if (name.isEmpty || name.length < 3) {
      _showSnack('الاسم قصير جداً — 3 أحرف على الأقل.', Colors.orange);
      return;
    }

    setState(() => _isPhoneSending = true);
    final auth = context.read<AuthProvider>();
    try {
      // ⚠️ sendOtpForSignUp يفحص أولاً هل الرقم مسجَّل مسبقاً (Firestore) قبل
      // إرسال OTP — يمنع ثغرة تداخل الحسابات عند التسجيل برقم مسجَّل بالفعل.
      final result = await auth.sendOtpForSignUp(phone);

      if (!mounted) return;

      if (result != null) {
        // pendingDisplayName → سيُمرَّر لـ verifyOtp ليُنشئ مستند users جديد
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OTPScreen(
              verificationId: result.verificationId,
              phoneNumber: _completePhoneNumber,
              pendingDisplayName: name,
            ),
          ),
        );
      } else if (auth.failure is PhoneAlreadyRegisteredFailure) {
        _showSnack(auth.failure!.message, Colors.orange);
        auth.clearFailure();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginPage()),
        );
      } else if (auth.failure != null) {
        _showSnack(auth.failure!.message, Colors.red);
        auth.clearFailure();
      }
    } finally {
      // يُعاد الزر لوضعه الطبيعي في كل المسارات (نجاح/فشل/استثناء).
      if (mounted) setState(() => _isPhoneSending = false);
    }
  }

  // ── Segmented Tab ─────────────────────────────────────────────────────
  Widget _segTab(IconData icon, String label, int index) {
    final active = _tabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _tabIndex = index);
          _pageController.animateToPage(
            index,
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeInOut,
          );
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: active ? _themeColor : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: _themeColor.withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    )
                  ]
                : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 16, color: active ? Colors.white : Colors.white38),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: active ? Colors.white : Colors.white38,
                  fontWeight: active ? FontWeight.w700 : FontWeight.normal,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Field decoration helper ───────────────────────────────────────────
  InputDecoration _fieldDecoration({
    required String label,
    required IconData icon,
    Widget? suffix,
    String? errorText,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white54),
      prefixIcon: Icon(icon, color: Colors.white54),
      suffixIcon: suffix,
      errorText: errorText,
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.10),
      // نفس الـ contentPadding المستخدم في حقل الهاتف → ارتفاع موحَّد لكل الحقول
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.white24),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: _themeColor, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
      ),
    );
  }

  // ── Phone tab body ────────────────────────────────────────────────────
  Widget _buildPhoneTab() {
    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Form(
        key: _phoneFormKey,
        child: Column(
          children: [
            const SizedBox(height: 20),
            const Text(
              'تسجيل بالهاتف',
              style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.bold,
                fontFamily: 'arial',
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'سجّل حسابك برقم هاتفك واستلم رمز تحقق آمن.',
              style: TextStyle(color: Colors.white60, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // ── Name ──
            TextFormField(
              controller: _phoneNameController,
              style: const TextStyle(color: Colors.white),
              cursorColor: Colors.white,
              decoration: _fieldDecoration(
                label: 'الاسم الكامل',
                icon: Icons.person_outline_rounded,
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'يرجى إدخال الاسم';
                if (v.trim().length < 3) {
                  return 'الاسم قصير جداً — 3 أحرف على الأقل';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // العلم ورقم الدولة على اليسار — LTR على الـ field فقط
            Directionality(
              textDirection: TextDirection.ltr,
              child: IntlPhoneField(
                controller: _phoneController,
                initialCountryCode: 'SD',
                showCountryFlag: true,
                languageCode: 'ar',
                invalidNumberMessage: 'رقم الهاتف غير صحيح',
                // تمركز عمودي مظبوط — نفس الـ vertical padding بتاع الحقل
                flagsButtonPadding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 18),
                flagsButtonMargin: EdgeInsets.zero,
                textAlignVertical: TextAlignVertical.center,
                pickerDialogStyle: PickerDialogStyle(
                  searchFieldInputDecoration: const InputDecoration(
                    hintText: 'ابحث عن الدولة',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
                dropdownIcon:
                    const Icon(Icons.arrow_drop_down, color: Colors.white70),
                // نفس العائلة والحجم و height للرقم ورمز الدولة → baseline موحّد
                dropdownTextStyle: const TextStyle(
                    color: Colors.white, fontSize: 16, height: 1.0),
                style: const TextStyle(
                    color: Colors.white, fontSize: 16, height: 1.0),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.10),
                  hintText: 'رقم الهاتف',
                  hintStyle:
                      const TextStyle(color: Colors.white38, fontSize: 16),
                  // إخفاء عدّاد "10/10" — مساحته أسفل الحقل كانت تزيح رمز
                  // الدولة لأسفل فيظهر غير محاذٍ للرقم. (maxLength يبقى فعّالاً)
                  counterText: '',
                  // نفس الـ contentPadding بتاع حقول البريد/كلمة المرور →
                  // ارتفاع موحَّد مع تمركز الرقم عمودياً بمحاذاة العلم.
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 18),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Colors.white24),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: _themeColor, width: 1.5),
                  ),
                ),
                keyboardType: TextInputType.phone,
                onChanged: (phone) {
                  setState(() {
                    _completePhoneNumber =
                        phone.completeNumber.replaceAll(RegExp(r'\s+'), '');
                    _isPhoneValid = phone.number.isNotEmpty &&
                        _completePhoneNumber.startsWith('+');
                  });
                },
              ),
            ),
            const SizedBox(height: 24),

            // ── Submit button ──
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: (_isPhoneValid && !_isPhoneSending)
                      ? _themeColor
                      : Colors.white24,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: (_isPhoneValid && !_isPhoneSending)
                    ? _submitPhoneSignUp
                    : null,
                child: _isPhoneSending
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : const Text(
                        'إرسال رمز التحقق',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'arial',
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'سنرسل رمز تحقق يستخدم مرة واحدة إلى هاتفك.',
              style: TextStyle(color: Colors.white38, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ── Email tab body ────────────────────────────────────────────────────
  Widget _buildEmailTab() {
    final strength = _passwordStrength(_password);
    final strengthColor = _strengthColor(strength);

    Widget? emailSuffix;
    if (_email.isNotEmpty) {
      emailSuffix = Icon(
        _emailError == null
            ? Icons.check_circle_outline
            : Icons.cancel_outlined,
        color: _emailError == null ? Colors.green : Colors.redAccent,
        size: 20,
      );
    }

    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Form(
        key: _emailFormKey,
        child: Column(
          children: [
            const SizedBox(height: 20),
            const Text(
              'تسجيل بالبريد',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 26,
                fontFamily: 'arial',
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'أنشئ حسابك باستخدام البريد الإلكتروني.',
              style: TextStyle(color: Colors.white60, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // ── Name ──
            TextFormField(
              style: const TextStyle(color: Colors.white),
              cursorColor: Colors.white,
              onChanged: (v) => setState(() => _name = v),
              decoration: _fieldDecoration(
                label: 'الاسم الكامل',
                icon: Icons.person_outline_rounded,
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'يرجى إدخال الاسم' : null,
            ),
            const SizedBox(height: 16),

            // ── Email ──
            TextFormField(
              style: const TextStyle(color: Colors.white),
              cursorColor: Colors.white,
              keyboardType: TextInputType.emailAddress,
              onChanged: _onEmailChanged,
              decoration: _fieldDecoration(
                label: 'البريد الإلكتروني',
                icon: Icons.email_outlined,
                suffix: emailSuffix,
                errorText: _emailError,
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'يرجى إدخال البريد الإلكتروني';
                }
                if (!RegExp(r"^[^@\s]+@[^@\s]+\.[^@\s]+$").hasMatch(v.trim())) {
                  return 'يرجى إدخال بريد إلكتروني صحيح';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // ── Password ──
            TextFormField(
              style: const TextStyle(color: Colors.white),
              cursorColor: Colors.white,
              obscureText: _obscureText,
              textDirection: TextDirection.ltr, // الباسورد دايماً LTR عشان الرموز متتقلبش
              onChanged: (v) => setState(() => _password = v),
              decoration: _fieldDecoration(
                label: 'كلمة المرور',
                icon: Icons.lock_outline_rounded,
                suffix: IconButton(
                  icon: Icon(
                    _obscureText
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: Colors.white38,
                    size: 20,
                  ),
                  onPressed: () => setState(() => _obscureText = !_obscureText),
                ),
              ),
              validator: PasswordValidator.validate,
            ),

            // ── متطلبات كلمة المرور (تظهر دائماً قبل الكتابة، وtick أخضر لما تتحقق) ──
            const SizedBox(height: 10),
            PasswordRequirementsChecklist(password: _password),

            if (_password.isNotEmpty) ...[
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: strength,
                        backgroundColor: Colors.white24,
                        color: strengthColor,
                        minHeight: 5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'قوة كلمة المرور: ${_strengthLabel(strength)}',
                      style: TextStyle(
                        color: strengthColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),

            // ── Confirm password ──
            TextFormField(
              style: const TextStyle(color: Colors.white),
              cursorColor: Colors.white,
              obscureText: _obscureConfirm,
              textDirection: TextDirection.ltr, // الباسورد دايماً LTR عشان الرموز متتقلبش
              onChanged: (v) => setState(() => _confirmPassword = v),
              decoration: _fieldDecoration(
                label: 'تأكيد كلمة المرور',
                icon: Icons.lock_outline_rounded,
                suffix: IconButton(
                  icon: Icon(
                    _obscureConfirm
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: Colors.white38,
                    size: 20,
                  ),
                  onPressed: () =>
                      setState(() => _obscureConfirm = !_obscureConfirm),
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'يرجى تأكيد كلمة المرور';
                if (v != _password) return 'كلمتا المرور غير متطابقتين';
                return null;
              },
            ),
            const SizedBox(height: 24),

            // ── Submit — مطابق 100% لزر "إرسال رمز التحقق" في تاب الهاتف:
            // - رمادي شفاف لما الحقول غير صالحة
            // - أحمر themeColor لما الحقول صالحة + spinner أبيض
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      _isEmailSignupValid ? _themeColor : Colors.white24,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: (_isEmailSignupValid && !_isLoading)
                    ? _submitEmailSignUp
                    : null,
                child: _isLoading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : const Text(
                        'إنشاء حساب',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'arial',
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background
          Image.asset(
            'assets/backkk.png',
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(color: Colors.black),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.55),
                  Colors.black.withValues(alpha: 0.78),
                ],
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 600),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  children: [
                    const SizedBox(height: 8),

                    // Logo
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.asset(
                        'assets/icon.png',
                        height: 58,
                        width: 58,
                        errorBuilder: (_, __, ___) => Container(
                          height: 58,
                          width: 58,
                          color: const Color(0xFF570707),
                          child: const Icon(Icons.storefront,
                              color: Colors.white, size: 28),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Title
                    const Text(
                      'إنشاء حساب',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 28,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'اختر طريقة التسجيل المناسبة لك.',
                      style: TextStyle(color: Colors.white60, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),

                    // Segmented control
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: Colors.white12,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(children: [
                        _segTab(Icons.phone_outlined, 'الهاتف', 0),
                        _segTab(Icons.email_outlined, 'البريد', 1),
                      ]),
                    ),
                    const SizedBox(height: 12),

                    // PageView
                    Expanded(
                      child: PageView(
                        controller: _pageController,
                        onPageChanged: (i) => setState(() => _tabIndex = i),
                        children: [
                          _buildPhoneTab(),
                          _buildEmailTab(),
                        ],
                      ),
                    ),

                    // Login link
                    Center(
                      child: RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          text: 'لديك حساب بالفعل؟ ',
                          style: const TextStyle(
                              color: Colors.white60, fontSize: 15),
                          children: [
                            TextSpan(
                              text: 'تسجيل الدخول',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF9B0B19),
                              ),
                              recognizer: TapGestureRecognizer()
                                ..onTap = () {
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) =>
                                            const LoginPage()),
                                  );
                                },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
