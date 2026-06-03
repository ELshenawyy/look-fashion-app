import 'package:flutter/material.dart';

/// مرجع الألوان المركزي لتطبيق تالا.
/// استخدم هذه الثوابت في كل شاشة بدلاً من تكرار Color(0xFF...).
abstract final class AppColors {
  /// الذهبي — اللون الرئيسي للنقاط التفاعلية والعناصر البارزة
  static const Color gold = Color(0xFFD4AF37);

  /// خلفية البطاقات الداكنة
  static const Color panel = Color(0xFF180808);

  /// أحمر داكن — حواف وزخارف ثانوية
  static const Color maroon = Color(0xFF5A1010);

  /// الخلفية السوداء الرئيسية للتطبيق
  static const Color background = Color(0xFF000000);

  /// أسود عميق للـ BottomNavigationBar
  static const Color navBackground = Color(0xFF0A0A0A);

  /// رمادي للعناصر غير النشطة
  static const Color inactive = Color(0xFF6B6B6B);

  /// أحمر الخطأ / التنبيه
  static const Color error = Color(0xFFE53935);

  /// أخضر النجاح
  static const Color success = Color(0xFF4CAF50);
}
