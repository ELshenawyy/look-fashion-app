import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:my_fashion_app/firebase/auth_service.dart';
import 'package:my_fashion_app/firebase/otp_screen.dart';
import 'package:my_fashion_app/firebase/signup.dart';
import 'package:my_fashion_app/main.dart';
import 'package:my_fashion_app/screens/app_shell.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _obscureText = true;
  bool _isPhoneValid = false;
  String _completePhoneNumber = '';

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _sendOTP() {
    if (!(kIsWeb ||
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'تسجيل الدخول عبر الهاتف متاح فقط على أندرويد وiOS والويب.'),
        ),
      );
      return;
    }

    final phoneNumber = _completePhoneNumber.replaceAll(RegExp(r'\s+'), '');
    if (phoneNumber.isEmpty || !_isPhoneValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('يرجى إدخال رقم هاتف صحيح مع مفتاح الدولة.')),
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
          SnackBar(content: Text('حدث خطأ: ${e.message}')),
        );
      },
    );
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
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'البريد الإلكتروني',
                labelStyle: const TextStyle(color: Colors.white54),
                prefixIcon:
                    const Icon(Icons.email_outlined, color: Colors.white38),
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

  Future<void> _signInWithEmail() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
    try {
      await AuthService.signIn(email, password);
      if (!mounted) return;
      Navigator.of(context).pop();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const AppShell()),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      String errorMessage = 'فشل تسجيل الدخول';
      if (e.code == 'user-not-found') {
        errorMessage = 'لا يوجد حساب مرتبط بهذا البريد الإلكتروني.';
      } else if (e.code == 'wrong-password') {
        errorMessage = 'كلمة المرور غير صحيحة.';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'صيغة البريد الإلكتروني غير صحيحة.';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('خطأ غير متوقع: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
     const themeColor = Color(0xFF9B0B19);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/backc.png'),
              fit: BoxFit.cover,
            ),
          ),
          child: SafeArea(
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                constraints: const BoxConstraints(maxWidth: 640),
                child: Column(
                  children: [
                    const Text(
                      'مرحبًا بعودتك',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 34,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'arimo',
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'سجّل الدخول عبر الهاتف أو البريد الإلكتروني لمتابعة التسوق.',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        fontFamily: 'arial',
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(35),
                      ),
                      child: TabBar(
                        indicatorPadding: const EdgeInsets.all(4),
                        indicator: BoxDecoration(
                          color: themeColor,
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: themeColor.withAlpha((0.3 * 255).round()),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        labelColor: Colors.white,
                        unselectedLabelColor: Colors.white70,
                        labelStyle: const TextStyle(
                            fontWeight: FontWeight.bold, fontFamily: 'arial'),
                        tabs: const [
                          Tab(text: 'دخول الهاتف'),
                          Tab(text: 'دخول البريد'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Expanded(
                      child: TabBarView(
                        children: [
                          SingleChildScrollView(
                            physics: const ClampingScrollPhysics(),
                            child: Column(
                              children: [
                                const SizedBox(height: 20),
                                const Text(
                                  'تسجيل الدخول بالهاتف',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 30,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'arial',
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'استخدم رقم هاتفك واستلم رمز تحقق آمن.',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 15,
                                    fontFamily: 'arial',
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 30),
                                IntlPhoneField(
                                  controller: _phoneController,
                                  initialCountryCode: 'SD',
                                  showCountryFlag: true,
                                  dropdownIcon: const Icon(Icons.arrow_drop_down,
                                      color: Colors.white),
                                  style: const TextStyle(color: Colors.white),
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: Colors.white24,
                                    hintText: 'رقم الهاتف',
                                    hintStyle: const TextStyle(color: Colors.white54),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(25),
                                      borderSide:
                                          const BorderSide(color: Colors.white24),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(25),
                                      borderSide:
                                          const BorderSide(color: Colors.white24),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(25),
                                      borderSide: const BorderSide(color: themeColor),
                                    ),
                                  ),
                                  keyboardType: TextInputType.phone,
                                  onChanged: (phone) {
                                    setState(() {
                                      _completePhoneNumber = phone
                                          .completeNumber
                                          .replaceAll(RegExp(r'\s+'), '');
                                      _isPhoneValid = phone.number.isNotEmpty &&
                                          _completePhoneNumber.startsWith('+');
                                    });
                                  },
                                  onCountryChanged: (country) {
                                    setState(() {
                                      final cleaned = _completePhoneNumber
                                          .replaceAll(RegExp(r'\s+'), '');
                                      _completePhoneNumber = cleaned;
                                      _isPhoneValid = cleaned.startsWith('+');
                                    });
                                  },
                                ),
                                const SizedBox(height: 30),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _isPhoneValid
                                        ? themeColor
                                        : Colors.white24,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(30)),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16, horizontal: 110),
                                  ),
                                  onPressed: _isPhoneValid ? _sendOTP : null,
                                  child: const Text(
                                    'إرسال الرمز',
                                    style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'arial'),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                const Text(
                                  'سنرسل رمز تحقق يستخدم مرة واحدة إلى هاتفك.',
                                  style: TextStyle(
                                      color: Colors.white54, fontSize: 14),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 24),
                              ],
                            ),
                          ),
                          SingleChildScrollView(
                            physics: const ClampingScrollPhysics(),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                children: [
                                  const SizedBox(height: 20),
                                  const Text(
                                    'تسجيل الدخول بالبريد الإلكتروني',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 30,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'arial',
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'سجّل الدخول باستخدام البريد الإلكتروني وكلمة المرور.',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 15,
                                      fontFamily: 'arial',
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 30),
                                  TextFormField(
                                    controller: _emailController,
                                    keyboardType: TextInputType.emailAddress,
                                    decoration: InputDecoration(
                                      prefixIcon: const Icon(Icons.email,
                                          color: Colors.white),
                                      labelText: 'البريد الإلكتروني',
                                      labelStyle:
                                          const TextStyle(color: Colors.white70),
                                      filled: true,
                                      fillColor: Colors.white24,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(25),
                                        borderSide:
                                            const BorderSide(color: Colors.white24),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(25),
                                        borderSide:
                                            const BorderSide(color: Colors.white24),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(25),
                                        borderSide:
                                            const BorderSide(color: themeColor),
                                      ),
                                    ),
                                    style: const TextStyle(color: Colors.white),
                                    validator: (value) {
                                      if (value == null ||
                                          value.trim().isEmpty) {
                                        return 'البريد الإلكتروني مطلوب';
                                      }
                                      if (!RegExp(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")
                                          .hasMatch(value.trim())) {
                                        return 'يرجى إدخال بريد إلكتروني صحيح';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 20),
                                  TextFormField(
                                    controller: _passwordController,
                                    obscureText: _obscureText,
                                    decoration: InputDecoration(
                                      prefixIcon:
                                          const Icon(Icons.lock, color: Colors.white),
                                      labelText: 'كلمة المرور',
                                      labelStyle:
                                          const TextStyle(color: Colors.white70),
                                      filled: true,
                                      fillColor: Colors.white24,
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                          _obscureText
                                              ? Icons.visibility_off
                                              : Icons.visibility,
                                          color: Colors.white70,
                                        ),
                                        onPressed: () {
                                          setState(() {
                                            _obscureText = !_obscureText;
                                          });
                                        },
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(25),
                                        borderSide:
                                            const BorderSide(color: Colors.white24),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(25),
                                        borderSide:
                                            const BorderSide(color: Colors.white24),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(25),
                                        borderSide:
                                            const BorderSide(color: themeColor),
                                      ),
                                    ),
                                    style: const TextStyle(color: Colors.white),
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
                                  const SizedBox(height: 16),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                      onPressed: () =>
                                          _showForgotPasswordDialog(context),
                                      child: const Text(
                                        'هل نسيت كلمة المرور؟',
                                        style: TextStyle(color: Colors.white),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: themeColor,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(30)),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 16, horizontal: 110),
                                    ),
                                    onPressed: _signInWithEmail,
                                    child: const Text(
                                      'تسجيل الدخول',
                                      style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          fontFamily: 'arial'),
                                    ),
                                  ),
                                  const SizedBox(height: 18),
                                  const Divider(color: Colors.white24, thickness: 1),
                                  const SizedBox(height: 18),
                                  const Text(
                                    'Or continue with',
                                    style: TextStyle(
                                        color: Colors.white70,
                                        fontFamily: 'arial'),
                                  ),
                                  const SizedBox(height: 18),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      _socialButton(
                                          'assets/google.png', 'Google'),
                                      const SizedBox(width: 16),
                                      _socialButton(
                                          'assets/apple.png', 'Apple'),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    RichText(
                      text: TextSpan(
                        text: 'Not a member? ',
                        style: const TextStyle(fontSize: 16, color: Colors.white),
                        children: [
                          TextSpan(
                            text: 'أنشئ حسابًا الآن',
                            style: const TextStyle(
                                fontSize: 16,
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
                    const SizedBox(height: 18),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: themeColor,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25)),
                        padding:
                            const EdgeInsets.symmetric(vertical: 16, horizontal: 50),
                      ),
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (context) => const MainScreen()),
                        );
                      },
                      child: const Text(
                        'Go to Home',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'arial'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _socialButton(String asset, String label) {
    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تسجيل الدخول عبر $label'),
            backgroundColor: const Color.fromARGB(255, 104, 99, 99),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: Colors.white, width: 2),
        ),
        padding: const EdgeInsets.all(10),
        child: Image.asset(asset, height: 50, width: 50),
      ),
    );
  }
}
