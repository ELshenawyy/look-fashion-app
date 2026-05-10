import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_fashion_app/screens/app_shell.dart';

import 'auth_service.dart';
import 'login.dart';

class Signup extends StatefulWidget {
  const Signup({super.key});

  @override
  State<Signup> createState() => _SignupState();
}

class _SignupState extends State<Signup> {
  static const Color _themeColor = Color(0xFF570707);

  final _formKey = GlobalKey<FormState>();
  String _name = '';
  String _email = '';
  String _password = '';
  String _confirmPassword = '';
  bool _obscureText = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;

  // ── Real-time email validation ────────────────────────────────────────
  String? _emailError;

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
  double _passwordStrength(String pwd) {
    if (pwd.isEmpty) return 0.0;
    double score = 0.0;
    if (pwd.length >= 6) score += 0.25;
    if (pwd.length >= 10) score += 0.15;
    if (RegExp(r'[A-Z]').hasMatch(pwd)) score += 0.2;
    if (RegExp(r'[0-9]').hasMatch(pwd)) score += 0.2;
    if (RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(pwd)) score += 0.2;
    return score.clamp(0.0, 1.0);
  }

  Color _strengthColor(double strength) {
    if (strength < 0.35) return Colors.red;
    if (strength < 0.65) return Colors.orange;
    return Colors.green;
  }

  String _strengthLabel(double strength) {
    if (strength < 0.35) return 'ضعيفة';
    if (strength < 0.65) return 'متوسطة';
    return 'قوية';
  }

  // ── Submit ────────────────────────────────────────────────────────────
  Future<void> _submitSignUp() async {
    if (_formKey.currentState == null || !_formKey.currentState!.validate()) {
      return;
    }

    if (_password != _confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('كلمة المرور وتأكيدها غير متطابقين'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      UserCredential? userCredential =
          await AuthService.signUp(_email.trim(), _password);

      final user = userCredential?.user;
      if (user == null) {
        throw FirebaseAuthException(
          code: 'null-user',
          message: 'User creation returned null user object',
        );
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({
        'uid': user.uid,
        'email': _email.trim(),
        'name': _name.trim(),
        'role': 'user',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إنشاء الحساب بنجاح.'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const AppShell()),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      final msg = _authErrorMessage(e.code);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
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

  String _authErrorMessage(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'هذا البريد الإلكتروني مسجّل بالفعل. حاول تسجيل الدخول.';
      case 'weak-password':
        return 'كلمة المرور ضعيفة جداً. استخدم 6 أحرف على الأقل.';
      case 'invalid-email':
        return 'صيغة البريد الإلكتروني غير صحيحة.';
      default:
        return 'حدث خطأ. حاول مرة أخرى.';
    }
  }

  // ── Input decoration helper ───────────────────────────────────────────
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

  // ── Build ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final strength = _passwordStrength(_password);
    final strengthColor = _strengthColor(strength);

    // Email suffix icon
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

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Background ──
          Image.asset('assets/backkk.png', fit: BoxFit.cover),

          // ── Dark gradient overlay ──
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

          // ── Content ──
          SafeArea(
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 600),
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        // ── Logo ──
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.asset('assets/icon.png',
                              height: 58, width: 58),
                        ),
                        const SizedBox(height: 14),

                        // ── Title ──
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
                          'أنشئ حسابك وابدأ التسوق الآن.',
                          style: TextStyle(
                              color: Colors.white60, fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),

                        // ── Name ──
                        TextFormField(
                          style: const TextStyle(color: Colors.white),
                          cursorColor: Colors.white,
                          onChanged: (v) => setState(() => _name = v),
                          decoration: _fieldDecoration(
                            label: 'الاسم الكامل',
                            icon: Icons.person_outline_rounded,
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'يرجى إدخال الاسم'
                              : null,
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
                            if (!RegExp(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")
                                .hasMatch(v.trim())) {
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
                              onPressed: () => setState(
                                  () => _obscureText = !_obscureText),
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) {
                              return 'يرجى إدخال كلمة المرور';
                            }
                            if (v.length < 6) {
                              return 'يجب أن تتكون كلمة المرور من 6 أحرف على الأقل';
                            }
                            return null;
                          },
                        ),

                        // ── Password strength bar ──
                        if (_password.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 2),
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

                        // ── Confirm Password ──
                        TextFormField(
                          style: const TextStyle(color: Colors.white),
                          cursorColor: Colors.white,
                          obscureText: _obscureConfirm,
                          onChanged: (v) =>
                              setState(() => _confirmPassword = v),
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
                              onPressed: () => setState(
                                  () => _obscureConfirm = !_obscureConfirm),
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) {
                              return 'يرجى تأكيد كلمة المرور';
                            }
                            if (v != _password) {
                              return 'كلمتا المرور غير متطابقتين';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 32),

                        // ── Submit button ──
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _themeColor,
                              disabledBackgroundColor:
                                  _themeColor.withValues(alpha: 0.6),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            onPressed: _isLoading ? null : _submitSignUp,
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
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // ── Login link ──
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
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
