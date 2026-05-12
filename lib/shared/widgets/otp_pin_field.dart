import 'package:flutter/material.dart';
import 'package:pinput/pinput.dart';

/// Wrapper موحد لـ Pinput v4 لعزل الـ API عن الكود.
/// أي ترقية مستقبلية لـ pinput تتم في هذا الملف فقط.
class OtpPinField extends StatelessWidget {
  const OtpPinField({
    super.key,
    required this.controller,
    this.focusNode,
    this.length = 6,
    this.themeColor = const Color(0xFF9B0B19),
    this.onCompleted,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final int length;
  final Color themeColor;
  final ValueChanged<String>? onCompleted;

  @override
  Widget build(BuildContext context) {
    final defaultTheme = PinTheme(
      width: 60,
      height: 60,
      textStyle: const TextStyle(
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

    return Pinput(
      length: length,
      controller: controller,
      focusNode: focusNode,
      defaultPinTheme: defaultTheme,
      focusedPinTheme: defaultTheme.copyWith(
        decoration: defaultTheme.decoration!.copyWith(
          color: Colors.white30,
          border: Border.all(color: themeColor, width: 2),
        ),
      ),
      submittedPinTheme: defaultTheme.copyWith(
        decoration: defaultTheme.decoration!.copyWith(
          color: Colors.white30,
        ),
      ),
      pinAnimationType: PinAnimationType.scale,
      keyboardType: TextInputType.number,
      onCompleted: onCompleted,
    );
  }
}
