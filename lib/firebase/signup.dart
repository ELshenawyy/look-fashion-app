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
  // ignore: library_private_types_in_public_api
  _SignupState createState() => _SignupState();
}

class _SignupState extends State<Signup> {
  final _formKey = GlobalKey<FormState>();
  String _name = '';
  String _email = '';
  String _password = '';
  String _confirmPassword = '';
  bool _obscureText = true;
  bool _obscureTextt = true;

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

    if (_name.trim().isEmpty || _email.trim().isEmpty || _password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('الاسم والبريد الإلكتروني وكلمة المرور مطلوبة'),
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
        'role': 'user', // كل مستخدم جديد يبدأ كـ user عادي
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
      debugPrint('Sign Up FirebaseAuthException: ${e.code} - ${e.message}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ: ${e.message ?? e.code}'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      debugPrint('Sign Up Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ غير متوقع: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
                    const SizedBox(
                      child: Text(
                        'إنشاء حساب',
                        style: TextStyle(
                            color: Color.fromARGB(255, 255, 255, 255),
                            fontWeight: FontWeight.bold,
                            fontFamily: 'times new roman',
                            fontSize: 30),
                      ),
                    ),
                    const SizedBox(height: 40.0),
                    TextFormField(
                      decoration: InputDecoration(
                        prefixIcon: const Icon(
                          Icons.person,
                          color: Colors.white,
                        ),
                        labelText: 'الاسم الكامل',
                        labelStyle: const TextStyle(
                          color: Colors.white,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25.0),
                          borderSide: const BorderSide(
                            color: Colors.white,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25.0),
                          borderSide: const BorderSide(
                            color: Colors.white,
                          ),
                        ),
                      ),
                      style: const TextStyle(
                        color: Colors.white,
                      ),
                      onChanged: (value) {
                        setState(() {
                          _name = value;
                        });
                      },
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'يرجى إدخال الاسم';
                        }
                        return null;
                      },
                      cursorColor: Colors.white,
                    ),
                    const SizedBox(height: 16.0),
                    TextFormField(
                      decoration: InputDecoration(
                        prefixIcon: const Icon(
                          Icons.email,
                          color: Colors.white,
                        ),
                        labelText: 'البريد الإلكتروني',
                        labelStyle: const TextStyle(
                          color: Colors.white,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25.0),
                          borderSide: const BorderSide(
                            color: Colors.white,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25.0),
                          borderSide: const BorderSide(
                            color: Colors.white,
                          ),
                        ),
                      ),
                      style: const TextStyle(
                        color: Colors.white,
                      ),
                      onChanged: (value) {
                        setState(() {
                          _email = value;
                        });
                      },
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'يرجى إدخال البريد الإلكتروني';
                        }
                        if (!RegExp(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")
                            .hasMatch(value.trim())) {
                          return 'يرجى إدخال بريد إلكتروني صحيح';
                        }
                        return null;
                      },
                      cursorColor: Colors.white,
                    ),
                    const SizedBox(height: 16.0),
                    TextFormField(
                      decoration: InputDecoration(
                        labelText: 'كلمة المرور',
                        labelStyle: const TextStyle(
                          color: Colors.white,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25.0),
                          borderSide: const BorderSide(
                            color: Colors.white,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25.0),
                          borderSide: const BorderSide(
                            color: Colors.white,
                          ),
                        ),
                        prefixIcon: const Icon(
                          Icons.lock,
                          color: Colors.white,
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureText
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: Colors.white,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscureText = !_obscureText;
                            });
                          },
                        ),
                      ),
                      obscureText: _obscureText,
                      style: const TextStyle(
                        color: Color.fromARGB(255, 255, 255, 255),
                      ),
                      cursorColor: const Color.fromARGB(255, 255, 255, 255),
                      onChanged: (value) {
                        setState(() {
                          _password = value;
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'يرجى إدخال كلمة المرور';
                        }
                        if (value.length < 6) {
                          return 'يجب أن تتكون كلمة المرور من 6 أحرف على الأقل';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16.0),
                    TextFormField(
                      decoration: InputDecoration(
                        labelText: 'تأكيد كلمة المرور',
                        labelStyle: const TextStyle(
                          color: Colors.white,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25.0),
                          borderSide: const BorderSide(
                            color: Colors.white,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25.0),
                          borderSide: const BorderSide(
                            color: Colors.white,
                          ),
                        ),
                        prefixIcon: const Icon(
                          Icons.lock,
                          color: Colors.white,
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureTextt
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: Colors.white,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscureTextt = !_obscureTextt;
                            });
                          },
                        ),
                      ),
                      obscureText: _obscureTextt,
                      style: const TextStyle(
                        color: Color.fromARGB(255, 255, 255, 255),
                      ),
                      cursorColor: const Color.fromARGB(255, 255, 255, 255),
                      onChanged: (value) {
                        setState(() {
                          _confirmPassword = value;
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'يرجى تأكيد كلمة المرور';
                        }
                        if (value != _password) {
                          return 'كلمتا المرور غير متطابقتين';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 40.0),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromARGB(255, 87, 7, 7),
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
                            fontFamily: 'Arimo'),
                      ),
                    ),
                    const SizedBox(height: 30),
                    Center(
                      child: RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          text: 'لديك حساب بالفعل؟ ',
                          style: const TextStyle(
                            color: Color.fromARGB(255, 255, 255, 255),
                            fontSize: 16.0,
                          ),
                          children: <TextSpan>[
                            TextSpan(
                              text: ' Log in',
                              style: const TextStyle(
                                fontSize: 20.0,
                                fontWeight: FontWeight.bold,
                                color: Color.fromARGB(255, 87, 7, 7),
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
}
