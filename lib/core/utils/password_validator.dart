import 'package:flutter/material.dart';

/// متطلبات كلمة المرور القوية (موحَّدة في كل التطبيق).
///
/// كلمة سر مقبولة لازم تحقّق كل المتطلبات الـ 4:
///   1. أكثر من 8 خانات (≥ 9 على الأقل)
///   2. على الأقل حرف واحد (a-z أو A-Z)
///   3. على الأقل رقم واحد (0-9)
///   4. على الأقل رمز خاص (!@#\$%^&* إلخ)
class PasswordRequirement {
  final String label;
  final bool Function(String) check;
  const PasswordRequirement(this.label, this.check);
}

class PasswordValidator {
  /// قائمة المتطلبات الأربعة (مرتبة حسب الأهمية).
  static final List<PasswordRequirement> requirements = [
    PasswordRequirement(
      'أكثر من 8 خانات',
      (p) => p.length > 8,
    ),
    PasswordRequirement(
      'حرف واحد على الأقل (a-z, A-Z)',
      (p) => RegExp(r'[a-zA-Z]').hasMatch(p),
    ),
    PasswordRequirement(
      'رقم واحد على الأقل (0-9)',
      (p) => RegExp(r'[0-9]').hasMatch(p),
    ),
    PasswordRequirement(
      r'رمز خاص واحد على الأقل (!@#$%^&*)',
      (p) => RegExp(r'[!@#$%^&*(),.?":{}|<>_\-+=\[\]\\\/`~]').hasMatch(p),
    ),
  ];

  /// `true` لو كلمة المرور تحقّق كل المتطلبات.
  static bool isStrong(String password) {
    if (password.isEmpty) return false;
    for (final r in requirements) {
      if (!r.check(password)) return false;
    }
    return true;
  }

  /// رسالة خطأ مناسبة للـ form validator (`null` لو صحيحة).
  static String? validate(String? password) {
    if (password == null || password.isEmpty) {
      return 'يرجى إدخال كلمة المرور';
    }
    for (final r in requirements) {
      if (!r.check(password)) return 'كلمة المرور لا تستوفي الشروط';
    }
    return null;
  }

  /// نسبة القوة (0.0 → 1.0) للـ progress bar.
  static double strength(String password) {
    if (password.isEmpty) return 0.0;
    int passed = 0;
    for (final r in requirements) {
      if (r.check(password)) passed++;
    }
    return passed / requirements.length;
  }
}

/// Widget يعرض checklist للمتطلبات الأربعة — يضيء أخضر لما يتحقّق كل شرط.
///
/// ```dart
/// PasswordRequirementsChecklist(password: _password)
/// ```
class PasswordRequirementsChecklist extends StatelessWidget {
  final String password;
  final Color activeColor;
  final Color inactiveColor;

  const PasswordRequirementsChecklist({
    super.key,
    required this.password,
    this.activeColor = const Color(0xFF4CAF50),
    this.inactiveColor = Colors.white54,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: PasswordValidator.requirements.map((req) {
          final passed = password.isNotEmpty && req.check(password);
          final color = passed ? activeColor : inactiveColor;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Icon(
                  passed
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  size: 16,
                  color: color,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    req.label,
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      height: 1.4,
                      decoration:
                          passed ? TextDecoration.lineThrough : null,
                      decorationColor: color.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
