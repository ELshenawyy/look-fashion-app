import 'dart:async';

import 'package:flutter/material.dart';
import 'package:my_fashion_app/core/error/failures.dart';
import 'package:my_fashion_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:my_fashion_app/firebase/login.dart';
import 'package:my_fashion_app/screens/app_shell.dart';
import 'package:my_fashion_app/shared/widgets/otp_pin_field.dart';
import 'package:provider/provider.dart';

class OTPScreen extends StatefulWidget {
  final String verificationId;
  final String phoneNumber;

  /// إذا مُرَّر → flow التسجيل بالهاتف: عند نجاح OTP يُنشأ مستند users
  /// تلقائياً بهذا الاسم. إذا null → flow الدخول العادي.
  final String? pendingDisplayName;

  const OTPScreen({
    super.key,
    required this.verificationId,
    required this.phoneNumber,
    this.pendingDisplayName,
  });

  @override
  State<OTPScreen> createState() => _OTPScreenState();
}

class _OTPScreenState extends State<OTPScreen> {
  final _otpController = TextEditingController();
  final FocusNode _pinFocusNode = FocusNode();
  late String _verificationId;
  Timer? _countdownTimer;
  int _remainingSeconds = 60;
  bool _isResendAvailable = false;
  bool _isSending = false;
  bool _isVerifying = false;

  @override
  void initState() {
    super.initState();
    _verificationId = widget.verificationId;
    _startCountdown();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _pinFocusNode.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    setState(() {
      _remainingSeconds = 60;
      _isResendAvailable = false;
    });
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_remainingSeconds <= 1) {
        timer.cancel();
        setState(() {
          _remainingSeconds = 0;
          _isResendAvailable = true;
        });
        return;
      }
      setState(() => _remainingSeconds -= 1);
    });
  }

  Future<void> _resendCode() async {
    if (!_isResendAvailable || _isSending) return;
    setState(() => _isSending = true);

    final auth = context.read<AuthProvider>();
    // ⚠️ Security: flow التسجيل (pendingDisplayName != null) لازم يعيد نفس
    // فحص "هل الرقم مسجَّل مسبقاً" عند إعادة الإرسال أيضاً — وإلا يتخطى
    // المستخدم الفحص عبر زر "إعادة الإرسال" (ثغرة تداخل حسابات).
    final result = widget.pendingDisplayName != null
        ? await auth.sendOtpForSignUp(widget.phoneNumber)
        : await auth.sendOtp(widget.phoneNumber);

    if (!mounted) return;
    setState(() => _isSending = false);

    if (result != null) {
      setState(() {
        _verificationId = result.verificationId;
        _isResendAvailable = false;
      });
      _startCountdown();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إرسال رمز جديد.')),
      );
    } else if (auth.failure is PhoneAlreadyRegisteredFailure) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.failure!.message)),
      );
      auth.clearFailure();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (route) => false,
      );
    } else if (auth.failure != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر إعادة الإرسال: ${auth.failure!.message}')),
      );
      auth.clearFailure();
    }
  }

  Future<void> _verifyOTP() async {
    if (_isVerifying) return;
    final smsCode = _otpController.text.trim();
    if (smsCode.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('يرجى إدخال رمز تحقق صحيح مكوّن من 6 أرقام')),
      );
      return;
    }
    setState(() => _isVerifying = true);
    final auth = context.read<AuthProvider>();
    final ok = await auth.verifyOtp(
      verificationId: _verificationId,
      smsCode: smsCode,
      displayName: widget.pendingDisplayName,
    );
    if (!mounted) return;
    setState(() => _isVerifying = false);

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تسجيل الدخول بنجاح!')),
      );
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const AppShell()),
        (route) => false,
      );
    } else if (auth.failure is PhoneAlreadyRegisteredFailure) {
      // ⚠️ Security: يحدث نادراً في حالة TOCTOU (رقم سُجِّل من جهاز آخر بين
      // فحص isPhoneRegistered وتأكيد الرمز) — datasource رفض العملية وأنهى
      // الجلسة. نوجّه المستخدم لتسجيل الدخول بدل ترك رسالة خطأ عامة.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.failure!.message)),
      );
      auth.clearFailure();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (route) => false,
      );
    } else if (auth.failure != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.failure!.message)),
      );
      auth.clearFailure();
    }
  }

  String get _timerText {
    final minutes = (_remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_remainingSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    const themeColor = Color(0xFF9B0B19);
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ⚠ Image.asset مع errorBuilder بدل DecorationImage
          // (DecorationImage لا يدعم errorBuilder → crash لو فُقد الـ asset)
          Image.asset(
            'assets/backc.png',
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(color: Colors.black),
          ),
          SafeArea(
            child: Center(
            child: SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha((0.42 * 255).round()),
                  borderRadius: BorderRadius.circular(34),
                  border: Border.all(color: Colors.white24),
                ),
                child: Column(
                  children: [
                    const Text(
                      'رمز التحقق',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'arimo',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'أدخل رمز التحقق المكوّن من 6 أرقام المرسل إلى ${widget.phoneNumber}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        fontFamily: 'arial',
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 28),
                    OtpPinField(
                      controller: _otpController,
                      focusNode: _pinFocusNode,
                      themeColor: themeColor,
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'إعادة الإرسال بعد ',
                          style: TextStyle(
                              color: Colors.white70, fontFamily: 'arial'),
                        ),
                        Text(
                          _timerText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'arial',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isResendAvailable
                            ? themeColor
                            : Colors.white24,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30)),
                        padding: const EdgeInsets.symmetric(
                            vertical: 14, horizontal: 48),
                      ),
                      onPressed:
                          _isResendAvailable && !_isSending ? _resendCode : null,
                      child: _isSending
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'إعادة الإرسال',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'arial'),
                            ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: themeColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30)),
                        padding: const EdgeInsets.symmetric(
                            vertical: 16, horizontal: 90),
                      ),
                      onPressed: _isVerifying ? null : _verifyOTP,
                      child: _isVerifying
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'تأكيد الرمز',
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
          ), // SafeArea close
        ], // Stack children close
      ), // Stack close
    );
  }
}
