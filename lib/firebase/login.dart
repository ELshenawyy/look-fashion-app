import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl_phone_field/country_picker_dialog.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:my_fashion_app/core/utils/locale_country.dart';
import 'package:my_fashion_app/core/utils/phone_number_validator.dart';
import 'package:my_fashion_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:my_fashion_app/firebase/otp_screen.dart';
import 'package:my_fashion_app/firebase/signup.dart';
import 'package:my_fashion_app/screens/app_shell.dart';
import 'package:provider/provider.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  static const Color _themeColor = Color(0xFF9B0B19);

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final PageController _pageController = PageController();

  int _tabIndex = 0;
  bool _obscureText = true;
  bool _isLoading = false;
  bool _isPhoneValid = false;
  bool _isPhoneSending = false; // حماية زر الهاتف من الضغط المتكرر أثناء الإرسال
  String _completePhoneNumber = '';

  // ── Real-time email validation ────────────────────────────────────────
  String? _emailError;

  /// يحدّد لو زر "تسجيل الدخول" بالبريد يجب أن يكون enabled بصرياً
  /// (مطابق لسلوك زر الهاتف اللي يضيء لما الرقم صالح).
  bool get _isEmailLoginValid =>
      _emailError == null &&
      _emailController.text.trim().isNotEmpty &&
      _passwordController.text.length >= 6;

  void _onEmailChanged(String value) {
    setState(() {
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

  @override
  void initState() {
    super.initState();
    // listeners لتحديث UI زر الـ login مع كل تغيير في الحقول
    _emailController.addListener(_onFieldChanged);
    _passwordController.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _emailController.removeListener(_onFieldChanged);
    _passwordController.removeListener(_onFieldChanged);
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  // ── OTP ───────────────────────────────────────────────────────────────
  Future<void> _sendOTP() async {
    if (!(kIsWeb ||
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('تسجيل الدخول عبر الهاتف متاح فقط على أندرويد وiOS والويب.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final phoneNumber = _completePhoneNumber.replaceAll(RegExp(r'\s+'), '');
    if (phoneNumber.isEmpty || !_isPhoneValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى إدخال رقم هاتف صحيح مع مفتاح الدولة.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final auth = context.read<AuthProvider>();

    // نعطّل الزر ونعرض spinner طوال العملية (تحقق الرقم + إرسال OTP) لمنع
    // الضغط المتكرر الذي يُطلق طلبات SMS متعددة ويسبّب خنق too-many-requests.
    setState(() => _isPhoneSending = true);
    try {
      // ── تحقق أولاً: هل الرقم مسجَّل؟ ──────────────────────────────────────
      // نمنع إرسال OTP (وتكلفة SMS) لرقم بلا حساب، ونوجّه المستخدم للتسجيل.
      final registered = await auth.isPhoneRegistered(phoneNumber);
      if (!mounted) return;
      if (registered == null) {
        // خطأ في الاتصال/الخادم
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('تعذّر التحقق من الرقم: ${auth.failure?.message ?? ''}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        auth.clearFailure();
        return;
      }
      if (!registered) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('لا يوجد حساب مسجَّل بهذا الرقم. أنشئ حساباً جديداً.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const Signup()),
        );
        return;
      }

      final result = await auth.sendOtp(phoneNumber);
      if (!mounted) return;
      if (result != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OTPScreen(
              verificationId: result.verificationId,
              phoneNumber: _completePhoneNumber,
            ),
          ),
        );
      } else if (auth.failure != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ: ${auth.failure!.message}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        auth.clearFailure();
      }
    } finally {
      // يُعاد الزر لوضعه الطبيعي في كل المسارات (نجاح/فشل/رجوع).
      if (mounted) setState(() => _isPhoneSending = false);
    }
  }

  // ── Forgot Password ───────────────────────────────────────────────────
  Future<void> _showForgotPasswordDialog(BuildContext context) async {
    const panel = Color(0xFF180808);
    const gold = Color(0xFFD4AF37);
    final emailCtrl = TextEditingController(text: _emailController.text.trim());

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: panel,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'استعادة كلمة المرور',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'أدخل بريدك الإلكتروني وسنُرسل لك رابط إعادة تعيين كلمة المرور.',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailCtrl,
              keyboardType: TextInputType.emailAddress,
              textDirection: TextDirection.ltr, // الإيميل دايماً LTR عشان الـ @ متتقلبش
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'البريد الإلكتروني',
                labelStyle: const TextStyle(color: Colors.white54),
                prefixIcon:
                    const Icon(Icons.email_outlined, color: Colors.white38),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.08),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.white24),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: gold),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: gold,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              final email = emailCtrl.text.trim();
              if (email.isEmpty ||
                  !RegExp(r"^[^@\s]+@[^@\s]+\.[^@\s]+$").hasMatch(email)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('يرجى إدخال بريد إلكتروني صحيح'),
                    backgroundColor: Colors.red,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                return;
              }
              Navigator.pop(ctx);
              final auth = context.read<AuthProvider>();
              final ok = await auth.sendPasswordReset(email);
              if (!context.mounted) return;
              if (ok) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        'تم إرسال رابط الاستعادة إلى $email. تحقق من بريدك.'),
                    backgroundColor: Colors.green,
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 5),
                  ),
                );
              } else if (auth.failure != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(auth.failure!.message),
                    backgroundColor: Colors.red,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                auth.clearFailure();
              }
            },
            child: const Text('إرسال'),
          ),
        ],
      ),
    );
  }

  // ── Email sign-in ─────────────────────────────────────────────────────
  Future<void> _signInWithEmail() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    setState(() => _isLoading = true);

    final auth = context.read<AuthProvider>();
    final ok = await auth.signInWithEmail(email, password);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (ok) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const AppShell()),
        (route) => false,
      );
    } else if (auth.failure != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.failure!.message),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      auth.clearFailure();
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

  // ── Input field helper ────────────────────────────────────────────────
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

  // ── Phone tab ─────────────────────────────────────────────────────────
  Widget _buildPhoneTab() {
    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Column(
        children: [
          const SizedBox(height: 20),
          const Text(
            'تسجيل الدخول بالهاتف',
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.bold,
              fontFamily: 'arial',
            ),
          ),
          const SizedBox(height: 8),
          // ارتفاع ثابت (سطرين) — يضمن إن حقل الهاتف يبدأ من نفس
          // النقطة العمودية لحقل البريد، بغض النظر عن عدد أسطر النص.
          const SizedBox(
            height: 40,
            child: Center(
              child: Text(
                'استخدم رقم هاتفك واستلم رمز تحقق آمن.',
                style: TextStyle(color: Colors.white60, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          const SizedBox(height: 28),
          // العلم ورقم الدولة على اليسار — LTR على الـ field فقط
          // الـ hint والأرقام تبقى LTR (الأرقام دايماً LTR)
          Directionality(
            textDirection: TextDirection.ltr,
            child: IntlPhoneField(
              controller: _phoneController,
              initialCountryCode: defaultPhoneCountryCode(context),
              showCountryFlag: true,
              languageCode: 'ar',
              invalidNumberMessage: 'رقم الهاتف غير صحيح',
              // ⚠ تمركز عمودي مضبوط — flagsButtonPadding متطابق مع
              // الـ contentPadding أسفل + isDense=true يلغي الـ default
              // padding اللي بيدفع النص لفوق
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
              dropdownTextStyle: const TextStyle(
                  color: Colors.white, fontSize: 16),
              style: const TextStyle(color: Colors.white, fontSize: 16),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.10),
                hintText: 'رقم الهاتف',
                hintStyle: const TextStyle(color: Colors.white38),
                // نفس الـ contentPadding بتاع حقول البريد/كلمة المرور →
                // ارتفاع موحَّد، مع textAlignVertical.center لتمركز الرقم
                // عمودياً بمحاذاة العلم ومفتاح الدولة.
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
                  _isPhoneValid = isValidPhoneNumber(phone);
                });
              },
              onCountryChanged: (country) {
                setState(() {
                  final nationalNumber =
                      _phoneController.text.replaceAll(RegExp(r'\s+'), '');
                  _completePhoneNumber =
                      '+${country.fullCountryCode}$nationalNumber';
                  _isPhoneValid =
                      isValidPhoneForCountry(country, nationalNumber);
                });
              },
            ),
          ),
          const SizedBox(height: 28),
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
              onPressed:
                  (_isPhoneValid && !_isPhoneSending) ? _sendOTP : null,
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
                      'إرسال الرمز',
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'arial'),
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
    );
  }

  // ── Email tab ─────────────────────────────────────────────────────────
  Widget _buildEmailTab() {
    // Suffix icon for email field
    Widget? emailSuffix;
    if (_emailController.text.isNotEmpty) {
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
        key: _formKey,
        child: Column(
          children: [
            const SizedBox(height: 20),
            const Text(
              'تسجيل الدخول بالبريد',
              style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.bold,
                fontFamily: 'arial',
              ),
            ),
            const SizedBox(height: 8),
            // ارتفاع ثابت (سطرين) — يضمن إن حقل البريد يبدأ من نفس
            // النقطة العمودية لحقل الهاتف، بغض النظر عن عدد أسطر النص.
            const SizedBox(
              height: 40,
              child: Center(
                child: Text(
                  'سجّل الدخول باستخدام البريد الإلكتروني وكلمة المرور.',
                  style: TextStyle(color: Colors.white60, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            const SizedBox(height: 28),
            // Email field
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: Colors.white),
              onChanged: _onEmailChanged,
              decoration: _fieldDecoration(
                label: 'البريد الإلكتروني',
                icon: Icons.email_outlined,
                suffix: emailSuffix,
                errorText: _emailError,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'البريد الإلكتروني مطلوب';
                }
                if (!RegExp(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")
                    .hasMatch(value.trim())) {
                  return 'يرجى إدخال بريد إلكتروني صحيح';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            // Password field
            TextFormField(
              controller: _passwordController,
              obscureText: _obscureText,
              textDirection: TextDirection.ltr, // الباسورد دايماً LTR عشان الرموز متتقلبش
              style: const TextStyle(color: Colors.white),
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
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'كلمة المرور مطلوبة';
                }
                if (value.length < 6) {
                  return 'يجب أن تتكون كلمة المرور من 6 أحرف على الأقل';
                }
                return null;
              },
            ),
            const SizedBox(height: 8),
            // Forgot password
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => _showForgotPasswordDialog(context),
                style: TextButton.styleFrom(foregroundColor: Colors.white54),
                child: const Text(
                  'هل نسيت كلمة المرور؟',
                  style: TextStyle(fontSize: 13),
                ),
              ),
            ),
            const SizedBox(height: 4),
            // Login button — مطابق 100% لزر "إرسال الرمز" في تاب الهاتف:
            // - رمادي شفاف لما الحقول غير صالحة
            // - أحمر themeColor لما الحقول صالحة + spinner أبيض
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      _isEmailLoginValid ? _themeColor : Colors.white24,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: (_isEmailLoginValid && !_isLoading)
                    ? _signInWithEmail
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
                        'تسجيل الدخول',
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
          // ── Background image ──
          Image.asset(
            'assets/backc.png',
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                Container(color: Colors.black),
          ),

          // ── Dark gradient overlay ──
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.50),
                  Colors.black.withValues(alpha: 0.75),
                ],
              ),
            ),
          ),

          // ── Content ──
          SafeArea(
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                constraints: const BoxConstraints(maxWidth: 640),
                child: Column(
                  children: [
                    const SizedBox(height: 8),

                    // ── App logo ──
                    ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Image.asset(
                        'assets/icon.png',
                        height: 80,
                        width: 80,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          height: 80,
                          width: 80,
                          color: const Color(0xFF570707),
                          child: const Icon(Icons.storefront,
                              color: Colors.white, size: 40),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // ── Title ──
                    const Text(
                      'أناقتك تبدأ من هنا',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'arimo',
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'سجّل الدخول عبر الهاتف أو البريد الإلكتروني.',
                      style: TextStyle(color: Colors.white60, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),

                    // ── Segmented control ──
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
                    const SizedBox(height: 16),

                    // ── PageView ──
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

                    // ── Sign up link ──
                    RichText(
                      text: TextSpan(
                        text: 'لا تمتلك حساباً؟ ',
                        style: const TextStyle(
                            fontSize: 15, color: Colors.white60),
                        children: [
                          TextSpan(
                            text: 'أنشئ حسابًا الآن',
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF9B0B19)),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) => const Signup()),
                                );
                              },
                          ),
                        ],
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
