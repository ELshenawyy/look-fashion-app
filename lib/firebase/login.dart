import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:my_fashion_app/firebase/auth_service.dart';
import 'package:my_fashion_app/firebase/otp_screen.dart';
import 'package:my_fashion_app/firebase/signup.dart';
import 'package:my_fashion_app/screens/app_shell.dart';

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
  String _completePhoneNumber = '';

  // ── Real-time email validation ────────────────────────────────────────
  String? _emailError;

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
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  // ── OTP ───────────────────────────────────────────────────────────────
  void _sendOTP() {
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
    AuthService.verifyPhoneNumber(
      phoneNumber,
      (String verificationId) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OTPScreen(
              verificationId: verificationId,
              phoneNumber: _completePhoneNumber,
            ),
          ),
        );
      },
      (FirebaseAuthException e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ: ${e.message}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
    );
  }

  // ── Forgot Password ───────────────────────────────────────────────────
  Future<void> _showForgotPasswordDialog(BuildContext context) async {
    const panel = Color(0xFF180808);
    const gold = Color(0xFFD4AF37);
    final emailCtrl =
        TextEditingController(text: _emailController.text.trim());

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: panel,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
            child:
                const Text('إلغاء', style: TextStyle(color: Colors.white54)),
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
              try {
                await FirebaseAuth.instance
                    .sendPasswordResetEmail(email: email);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        'تم إرسال رابط الاستعادة إلى $email. تحقق من بريدك.'),
                    backgroundColor: Colors.green,
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 5),
                  ),
                );
              } on FirebaseAuthException catch (e) {
                if (!context.mounted) return;
                final msg = e.code == 'user-not-found'
                    ? 'لا يوجد حساب بهذا البريد الإلكتروني.'
                    : 'حدث خطأ: ${e.message}';
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(msg),
                    backgroundColor: Colors.red,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
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
    try {
      await AuthService.signIn(email, password);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const AppShell()),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      String errorMessage = 'فشل تسجيل الدخول';
      if (e.code == 'user-not-found') {
        errorMessage = 'لا يوجد حساب مرتبط بهذا البريد الإلكتروني.';
      } else if (e.code == 'wrong-password') {
        errorMessage = 'كلمة المرور غير صحيحة.';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'صيغة البريد الإلكتروني غير صحيحة.';
      } else if (e.code == 'invalid-credential') {
        errorMessage = 'البريد الإلكتروني أو كلمة المرور غير صحيحة.';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ غير متوقع: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
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
                  size: 16,
                  color: active ? Colors.white : Colors.white38),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: active ? Colors.white : Colors.white38,
                  fontWeight:
                      active ? FontWeight.w700 : FontWeight.normal,
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
          const Text(
            'استخدم رقم هاتفك واستلم رمز تحقق آمن.',
            style: TextStyle(color: Colors.white60, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          // Phone field
          IntlPhoneField(
            controller: _phoneController,
            initialCountryCode: 'SD',
            showCountryFlag: true,
            dropdownIcon:
                const Icon(Icons.arrow_drop_down, color: Colors.white70),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.10),
              hintText: 'رقم الهاتف',
              hintStyle: const TextStyle(color: Colors.white38),
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
                borderSide:
                    const BorderSide(color: _themeColor, width: 1.5),
              ),
            ),
            keyboardType: TextInputType.phone,
            onChanged: (phone) {
              setState(() {
                _completePhoneNumber = phone.completeNumber
                    .replaceAll(RegExp(r'\s+'), '');
                _isPhoneValid = phone.number.isNotEmpty &&
                    _completePhoneNumber.startsWith('+');
              });
            },
            onCountryChanged: (_) {
              setState(() {
                final cleaned =
                    _completePhoneNumber.replaceAll(RegExp(r'\s+'), '');
                _completePhoneNumber = cleaned;
                _isPhoneValid = cleaned.startsWith('+');
              });
            },
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    _isPhoneValid ? _themeColor : Colors.white24,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: _isPhoneValid ? _sendOTP : null,
              child: const Text(
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
            const Text(
              'سجّل الدخول باستخدام البريد الإلكتروني وكلمة المرور.',
              style: TextStyle(color: Colors.white60, fontSize: 14),
              textAlign: TextAlign.center,
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
                  onPressed: () =>
                      setState(() => _obscureText = !_obscureText),
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
                style: TextButton.styleFrom(
                    foregroundColor: Colors.white54),
                child: const Text(
                  'هل نسيت كلمة المرور؟',
                  style: TextStyle(fontSize: 13),
                ),
              ),
            ),
            const SizedBox(height: 4),
            // Login button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _themeColor,
                  disabledBackgroundColor:
                      _themeColor.withValues(alpha: 0.6),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: _isLoading ? null : _signInWithEmail,
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
                            fontFamily: 'arial'),
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
          Image.asset('assets/backc.png', fit: BoxFit.cover),

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
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 16),
                constraints: const BoxConstraints(maxWidth: 640),
                child: Column(
                  children: [
                    const SizedBox(height: 8),

                    // ── App logo ──
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.asset('assets/icon.png',
                          height: 62, width: 62),
                    ),
                    const SizedBox(height: 14),

                    // ── Title ──
                    const Text(
                      'مرحبًا بعودتك',
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
                        onPageChanged: (i) =>
                            setState(() => _tabIndex = i),
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
                                      builder: (context) =>
                                          const Signup()),
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
