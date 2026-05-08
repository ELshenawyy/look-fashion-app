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
  final _formKey = GlobalKey<FormState>();
  String _name = '';
  String _email = '';
  String _password = '';
  String _confirmPassword = '';
  bool _obscureText = true;
  bool _obscureConfirm = true; // كان: _obscureTextt (typo مُصلح)

  // ── Password strength ─────────────────────────────────────────────────
  /// يُعيد قيمة بين 0.0 و 1.0 تعبّر عن قوة كلمة المرور
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
        ),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

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

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'email': _email.trim(),
        'name': _name.trim(),
        'role': 'user',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إنشاء الحساب بنجاح.'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const AppShell()),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      final msg = _authErrorMessage(e.code);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ غير متوقع: $e'), backgroundColor: Colors.red),
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

  // ── Build ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final strength = _passwordStrength(_password);
    final strengthColor = _strengthColor(strength);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/backkk.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(16.0),
            constraints: BoxConstraints(
              maxWidth: 600.0,
              maxHeight: MediaQuery.of(context).size.height,
            ),
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    const Text(
                      'إنشاء حساب',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 30,
                      ),
                    ),
                    const SizedBox(height: 40.0),
                    // ── Name ──
                    _buildField(
                      label: 'الاسم الكامل',
                      icon: Icons.person,
                      onChanged: (v) => setState(() => _name = v),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'يرجى إدخال الاسم' : null,
                    ),
                    const SizedBox(height: 16.0),
                    // ── Email ──
                    _buildField(
                      label: 'البريد الإلكتروني',
                      icon: Icons.email,
                      keyboardType: TextInputType.emailAddress,
                      onChanged: (v) => setState(() => _email = v),
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
                    const SizedBox(height: 16.0),
                    // ── Password ──
                    _buildField(
                      label: 'كلمة المرور',
                      icon: Icons.lock,
                      obscure: _obscureText,
                      onToggleObscure: () =>
                          setState(() => _obscureText = !_obscureText),
                      onChanged: (v) => setState(() => _password = v),
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
                    // Password strength bar
                    if (_password.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: strength,
                                backgroundColor: Colors.white24,
                                color: strengthColor,
                                minHeight: 6,
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
                    const SizedBox(height: 16.0),
                    // ── Confirm Password ──
                    _buildField(
                      label: 'تأكيد كلمة المرور',
                      icon: Icons.lock,
                      obscure: _obscureConfirm,
                      onToggleObscure: () =>
                          setState(() => _obscureConfirm = !_obscureConfirm),
                      onChanged: (v) => setState(() => _confirmPassword = v),
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
                    const SizedBox(height: 40.0),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF570707),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20.0),
                        ),
                        padding: const EdgeInsets.symmetric(
                          vertical: 16.0,
                          horizontal: 120.0,
                        ),
                      ),
                      onPressed: _submitSignUp,
                      child: const Text(
                        'إنشاء حساب',
                        style: TextStyle(
                          fontSize: 18.0,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                    Center(
                      child: RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          text: 'لديك حساب بالفعل؟ ',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16.0,
                          ),
                          children: <TextSpan>[
                            TextSpan(
                              text: ' تسجيل الدخول',
                              style: const TextStyle(
                                fontSize: 18.0,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF570707),
                              ),
                              recognizer: TapGestureRecognizer()
                                ..onTap = () {
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) => const LoginPage()),
                                  );
                                },
                            ),
                          ],
                        ),
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

  // ── Helper: Reusable TextFormField ────────────────────────────────────
  Widget _buildField({
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscure = false,
    VoidCallback? onToggleObscure,
    required ValueChanged<String> onChanged,
    FormFieldValidator<String>? validator,
  }) {
    return TextFormField(
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white),
        prefixIcon: Icon(icon, color: Colors.white),
        suffixIcon: onToggleObscure != null
            ? IconButton(
                icon: Icon(
                  obscure ? Icons.visibility_off : Icons.visibility,
                  color: Colors.white,
                ),
                onPressed: onToggleObscure,
              )
            : null,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(25.0),
          borderSide: const BorderSide(color: Colors.white),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(25.0),
          borderSide: const BorderSide(color: Colors.white),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(25.0),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(25.0),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
      ),
      style: const TextStyle(color: Colors.white),
      cursorColor: Colors.white,
      keyboardType: keyboardType,
      obscureText: obscure,
      onChanged: onChanged,
      validator: validator,
    );
  }
}
