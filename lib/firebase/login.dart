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
  @override
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
        SnackBar(
          content: Text(
              'تسجيل الدخول عبر الهاتف متاح فقط على أندرويد وiOS والويب.'),
        ),
      );
      return;
    }

    final phoneNumber = _completePhoneNumber.replaceAll(RegExp(r'\s+'), '');
    if (phoneNumber.isEmpty || !_isPhoneValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
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

  Future<void> _signInWithEmail() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(child: CircularProgressIndicator()),
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
    final themeColor = Color(0xFF9B0B19);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/backc.png'),
              fit: BoxFit.cover,
            ),
          ),
          child: SafeArea(
            child: Center(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                constraints: BoxConstraints(maxWidth: 640),
                child: Column(
                  children: [
                    Text(
                      'مرحبًا بعودتك',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 34,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'arimo',
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'سجّل الدخول عبر الهاتف أو البريد الإلكتروني لمتابعة التسوق.',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        fontFamily: 'arial',
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 24),
                    Container(
                      padding: EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(35),
                      ),
                      child: TabBar(
                        indicatorPadding: EdgeInsets.all(4),
                        indicator: BoxDecoration(
                          color: themeColor,
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: themeColor.withAlpha((0.3 * 255).round()),
                              blurRadius: 12,
                              offset: Offset(0, 6),
                            ),
                          ],
                        ),
                        labelColor: Colors.white,
                        unselectedLabelColor: Colors.white70,
                        labelStyle: TextStyle(
                            fontWeight: FontWeight.bold, fontFamily: 'arial'),
                        tabs: [
                          Tab(text: 'دخول الهاتف'),
                          Tab(text: 'دخول البريد'),
                        ],
                      ),
                    ),
                    SizedBox(height: 20),
                    Expanded(
                      child: TabBarView(
                        children: [
                          SingleChildScrollView(
                            physics: ClampingScrollPhysics(),
                            child: Column(
                              children: [
                                SizedBox(height: 20),
                                Text(
                                  'تسجيل الدخول بالهاتف',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 30,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'arial',
                                  ),
                                ),
                                SizedBox(height: 12),
                                Text(
                                  'استخدم رقم هاتفك واستلم رمز تحقق آمن.',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 15,
                                    fontFamily: 'arial',
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                SizedBox(height: 30),
                                IntlPhoneField(
                                  controller: _phoneController,
                                  initialCountryCode: 'SD',
                                  showCountryFlag: true,
                                  dropdownIcon: Icon(Icons.arrow_drop_down,
                                      color: Colors.white),
                                  style: TextStyle(color: Colors.white),
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: Colors.white24,
                                    hintText: 'رقم الهاتف',
                                    hintStyle: TextStyle(color: Colors.white54),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(25),
                                      borderSide:
                                          BorderSide(color: Colors.white24),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(25),
                                      borderSide:
                                          BorderSide(color: Colors.white24),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(25),
                                      borderSide: BorderSide(color: themeColor),
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
                                SizedBox(height: 30),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _isPhoneValid
                                        ? themeColor
                                        : Colors.white24,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(30)),
                                    padding: EdgeInsets.symmetric(
                                        vertical: 16, horizontal: 110),
                                  ),
                                  onPressed: _isPhoneValid ? _sendOTP : null,
                                  child: Text(
                                    'إرسال الرمز',
                                    style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'arial'),
                                  ),
                                ),
                                SizedBox(height: 14),
                                Text(
                                  'سنرسل رمز تحقق يستخدم مرة واحدة إلى هاتفك.',
                                  style: TextStyle(
                                      color: Colors.white54, fontSize: 14),
                                  textAlign: TextAlign.center,
                                ),
                                SizedBox(height: 24),
                              ],
                            ),
                          ),
                          SingleChildScrollView(
                            physics: ClampingScrollPhysics(),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                children: [
                                  SizedBox(height: 20),
                                  Text(
                                    'تسجيل الدخول بالبريد الإلكتروني',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 30,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'arial',
                                    ),
                                  ),
                                  SizedBox(height: 12),
                                  Text(
                                    'سجّل الدخول باستخدام البريد الإلكتروني وكلمة المرور.',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 15,
                                      fontFamily: 'arial',
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  SizedBox(height: 30),
                                  TextFormField(
                                    controller: _emailController,
                                    keyboardType: TextInputType.emailAddress,
                                    decoration: InputDecoration(
                                      prefixIcon: Icon(Icons.email,
                                          color: Colors.white),
                                      labelText: 'البريد الإلكتروني',
                                      labelStyle:
                                          TextStyle(color: Colors.white70),
                                      filled: true,
                                      fillColor: Colors.white24,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(25),
                                        borderSide:
                                            BorderSide(color: Colors.white24),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(25),
                                        borderSide:
                                            BorderSide(color: Colors.white24),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(25),
                                        borderSide:
                                            BorderSide(color: themeColor),
                                      ),
                                    ),
                                    style: TextStyle(color: Colors.white),
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
                                  SizedBox(height: 20),
                                  TextFormField(
                                    controller: _passwordController,
                                    obscureText: _obscureText,
                                    decoration: InputDecoration(
                                      prefixIcon:
                                          Icon(Icons.lock, color: Colors.white),
                                      labelText: 'كلمة المرور',
                                      labelStyle:
                                          TextStyle(color: Colors.white70),
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
                                            BorderSide(color: Colors.white24),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(25),
                                        borderSide:
                                            BorderSide(color: Colors.white24),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(25),
                                        borderSide:
                                            BorderSide(color: themeColor),
                                      ),
                                    ),
                                    style: TextStyle(color: Colors.white),
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
                                  SizedBox(height: 16),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                      onPressed: () {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text('نسيت كلمة المرور'),
                                            backgroundColor:
                                                Color.fromARGB(255, 94, 255, 0),
                                          ),
                                        );
                                      },
                                      child: Text(
                                        'هل نسيت كلمة المرور؟',
                                        style: TextStyle(color: Colors.white),
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: themeColor,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(30)),
                                      padding: EdgeInsets.symmetric(
                                          vertical: 16, horizontal: 110),
                                    ),
                                    onPressed: _signInWithEmail,
                                    child: Text(
                                      'تسجيل الدخول',
                                      style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          fontFamily: 'arial'),
                                    ),
                                  ),
                                  SizedBox(height: 18),
                                  Divider(color: Colors.white24, thickness: 1),
                                  SizedBox(height: 18),
                                  Text(
                                    'Or continue with',
                                    style: TextStyle(
                                        color: Colors.white70,
                                        fontFamily: 'arial'),
                                  ),
                                  SizedBox(height: 18),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      _socialButton(
                                          'assets/google.png', 'Google'),
                                      SizedBox(width: 16),
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
                    SizedBox(height: 20),
                    RichText(
                      text: TextSpan(
                        text: 'Not a member? ',
                        style: TextStyle(fontSize: 16, color: Colors.white),
                        children: [
                          TextSpan(
                            text: 'أنشئ حسابًا الآن',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF9B0B19)),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) => Signup()),
                                );
                              },
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 18),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: themeColor,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25)),
                        padding:
                            EdgeInsets.symmetric(vertical: 16, horizontal: 50),
                      ),
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (context) => MainScreen()),
                        );
                      },
                      child: Text(
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
            backgroundColor: Color.fromARGB(255, 104, 99, 99),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: Colors.white, width: 2),
        ),
        padding: EdgeInsets.all(10),
        child: Image.asset(asset, height: 50, width: 50),
      ),
    );
  }
}
