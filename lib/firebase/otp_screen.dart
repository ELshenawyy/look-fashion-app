import 'dart:async';

import 'package:flutter/material.dart';
import 'package:my_fashion_app/screens/product_list_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pinput/pinput.dart';

import 'auth_service.dart';

class OTPScreen extends StatefulWidget {
  final String verificationId;
  final String phoneNumber;

  const OTPScreen({
    Key? key,
    required this.verificationId,
    required this.phoneNumber,
  }) : super(key: key);

  @override
  _OTPScreenState createState() => _OTPScreenState();
}

class _OTPScreenState extends State<OTPScreen> {
  final _otpController = TextEditingController();
  final FocusNode _pinFocusNode = FocusNode();
  late String _verificationId;
  Timer? _countdownTimer;
  int _remainingSeconds = 60;
  bool _isResendAvailable = false;
  bool _isSending = false;

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
    _countdownTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_remainingSeconds <= 1) {
        timer.cancel();
        setState(() {
          _remainingSeconds = 0;
          _isResendAvailable = true;
        });
        return;
      }
      setState(() {
        _remainingSeconds -= 1;
      });
    });
  }

  Future<void> _resendCode() async {
    if (!_isResendAvailable || _isSending) return;
    setState(() {
      _isSending = true;
    });
    AuthService.verifyPhoneNumber(
      widget.phoneNumber,
      (String newVerificationId) {
        if (!mounted) return;
        setState(() {
          _verificationId = newVerificationId;
          _isSending = false;
          _isResendAvailable = false;
        });
        _startCountdown();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('A new code has been sent.')),
        );
      },
      (FirebaseAuthException e) {
        if (!mounted) return;
        setState(() {
          _isSending = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Resend failed: ${e.message}')),
        );
      },
    );
  }

  Future<void> _verifyOTP() async {
    final smsCode = _otpController.text.trim();
    if (smsCode.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter a valid 6-digit OTP')),
      );
      return;
    }
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(child: CircularProgressIndicator()),
    );
    try {
      await AuthService.signInWithPhone(_verificationId, smsCode);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Login successful!')),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => ProductListScreen()),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.message}')),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unexpected error: $e')),
      );
    }
  }

  String get _timerText {
    final minutes = (_remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_remainingSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = Color(0xFF9B0B19);
    final defaultPinTheme = PinTheme(
      width: 60,
      height: 60,
      textStyle: TextStyle(
        fontSize: 22,
        color: Colors.white,
        fontWeight: FontWeight.w700,
        fontFamily: 'arial',
      ),
      decoration: BoxDecoration(
        color: Colors.white24,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white54),
      ),
    );
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/backc.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 28),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha((0.42 * 255).round()),
                  borderRadius: BorderRadius.circular(34),
                  border: Border.all(color: Colors.white24),
                ),
                child: Column(
                  children: [
                    Text(
                      'Verification Code',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'arimo',
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Enter the 6-digit code sent to ${widget.phoneNumber}',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        fontFamily: 'arial',
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 28),
                    Pinput(
                      length: 6,
                      controller: _otpController,
                      focusNode: _pinFocusNode,
                      defaultPinTheme: defaultPinTheme,
                      focusedPinTheme: defaultPinTheme.copyWith(
                        decoration: defaultPinTheme.decoration!.copyWith(
                          color: Colors.white30,
                          border: Border.all(color: themeColor, width: 2),
                        ),
                      ),
                      submittedPinTheme: defaultPinTheme.copyWith(
                        decoration: defaultPinTheme.decoration!.copyWith(
                          color: Colors.white30,
                        ),
                      ),
                      pinAnimationType: PinAnimationType.scale,
                      keyboardType: TextInputType.number,
                    ),
                    SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Resend available in ',
                          style: TextStyle(color: Colors.white70, fontFamily: 'arial'),
                        ),
                        Text(
                          _timerText,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'arial',
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 18),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isResendAvailable ? themeColor : Colors.white24,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        padding: EdgeInsets.symmetric(vertical: 14, horizontal: 48),
                      ),
                      onPressed: _isResendAvailable && !_isSending ? _resendCode : null,
                      child: _isSending
                          ? SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              'Resend',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'arial'),
                            ),
                    ),
                    SizedBox(height: 24),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: themeColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        padding: EdgeInsets.symmetric(vertical: 16, horizontal: 90),
                      ),
                      onPressed: _verifyOTP,
                      child: Text(
                        'Verify OTP',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'arial'),
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
