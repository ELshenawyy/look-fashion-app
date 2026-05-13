import 'package:flutter/material.dart';

/// Utility موحَّد لتحويل ألوان المنتجات بين تخزين Firestore والعرض في UI.
///
/// التخزين الجديد: hex string بصيغة `#FFRRGGBB` أو `#RRGGBB` أو `0xFFRRGGBB`.
/// التخزين القديم (backward compat): أسماء إنجليزية مثل `Red`, `Maroon`...
class ColorUtils {
  ColorUtils._();

  /// تحويل أي تخزين (hex جديد أو اسم قديم) إلى Color.
  /// إذا فشل التحويل → يرجع رمادي افتراضي.
  static Color parse(String code) {
    final s = code.trim();
    if (s.isEmpty) return _fallback;

    // ── محاولة قراءة hex ──
    try {
      String hex = s;
      if (hex.startsWith('#')) hex = hex.substring(1);
      if (hex.startsWith('0x') || hex.startsWith('0X')) {
        hex = hex.substring(2);
      }
      // 6 hex chars → نضيف FF كـ alpha
      if (hex.length == 6) hex = 'FF$hex';
      if (hex.length == 8 && _isHex(hex)) {
        return Color(int.parse(hex, radix: 16));
      }
    } catch (_) {
      // تجاهل وجرب الاسم
    }

    // ── أسماء قديمة (backward compat) ──
    return _legacyNames[s.toLowerCase()] ?? _fallback;
  }

  /// تحويل Color → hex بصيغة `#FFRRGGBB`
  static String toHex(Color color) {
    // ignore: deprecated_member_use
    final value = color.value;
    return '#${value.toRadixString(16).padLeft(8, '0').toUpperCase()}';
  }

  /// اسم اللون بالعربية للعرض في UI.
  /// 1) اسم إنجليزي قديم → ترجمة مباشرة من _arabicByName
  /// 2) hex مطابق تماماً لأحد ألوان الـ palette → اسمه العربي
  /// 3) hex مخصّص → ابحث عن أقرب لون مسمَّى ورجّع اسمه العربي
  static String displayLabel(String code) {
    final s = code.trim();
    if (s.isEmpty || s == 'افتراضي') return s;
    final lower = s.toLowerCase();
    if (_arabicByName.containsKey(lower)) return _arabicByName[lower]!;
    return _nearestArabicName(parse(s));
  }

  static String _nearestArabicName(Color target) {
    String? bestName;
    double bestDist = double.infinity;
    // ignore: deprecated_member_use
    final tr = target.red;
    // ignore: deprecated_member_use
    final tg = target.green;
    // ignore: deprecated_member_use
    final tb = target.blue;

    _arabicByName.forEach((engName, arName) {
      final c = _legacyNames[engName];
      if (c == null) return;
      // ignore: deprecated_member_use
      final dr = c.red - tr;
      // ignore: deprecated_member_use
      final dg = c.green - tg;
      // ignore: deprecated_member_use
      final db = c.blue - tb;
      final dist = (dr * dr + dg * dg + db * db).toDouble();
      if (dist < bestDist) {
        bestDist = dist;
        bestName = arName;
      }
    });
    return bestName ?? 'لون مخصّص';
  }

  /// خريطة الترجمة من الاسم الإنجليزي → العربي.
  /// تُستخدم للأسماء القديمة في Firestore + للبحث عن أقرب لون.
  static const Map<String, String> _arabicByName = {
    'black': 'أسود',
    'white': 'أبيض',
    'grey': 'رمادي',
    'gray': 'رمادي',
    'silver': 'فضي',
    'charcoal': 'فحمي',
    'red': 'أحمر',
    'maroon': 'عنابي',
    'burgundy': 'خمري',
    'pink': 'وردي',
    'rose': 'وردي فاتح',
    'coral': 'مرجاني',
    'salmon': 'سلموني',
    'blue': 'أزرق',
    'navy': 'كحلي',
    'skyblue': 'سماوي',
    'turquoise': 'تركوازي',
    'teal': 'أخضر مزرق',
    'green': 'أخضر',
    'olive': 'زيتي',
    'mint': 'نعناعي',
    'emeraldgreen': 'زمردي',
    'forestgreen': 'أخضر غامق',
    'brown': 'بني',
    'beige': 'بيج',
    'tan': 'تان',
    'khaki': 'كاكي',
    'camel': 'جملي',
    'chocolate': 'شوكولاتي',
    'yellow': 'أصفر',
    'mustard': 'خردلي',
    'orange': 'برتقالي',
    'peach': 'خوخي',
    'purple': 'بنفسجي',
    'lavender': 'لافندر',
    'magenta': 'فوشيا',
    'gold': 'ذهبي',
    'rosegold': 'ذهبي وردي',
    'bronze': 'برونزي',
    'cream': 'كريمي',
    'ivory': 'عاجي',
  };

  static bool _isHex(String s) =>
      RegExp(r'^[0-9a-fA-F]+$').hasMatch(s);

  static const Color _fallback = Color(0xFF616161);

  /// خريطة الأسماء القديمة → Color (لقراءة بيانات Firestore القديمة).
  static const Map<String, Color> _legacyNames = {
    'black': Colors.black,
    'white': Colors.white,
    'grey': Color(0xFF8E8E8E),
    'gray': Color(0xFF8E8E8E),
    'silver': Color(0xFFC0C0C0),
    'charcoal': Color(0xFF36454F),
    'red': Color(0xFFC62828),
    'maroon': Color(0xFF800000),
    'burgundy': Color(0xFF880E4F),
    'pink': Color(0xFFE91E8C),
    'rose': Color(0xFFFF66B2),
    'coral': Color(0xFFFF7F50),
    'salmon': Color(0xFFFA8072),
    'blue': Color(0xFF0D47A1),
    'navy': Color(0xFF1A237E),
    'skyblue': Color(0xFF87CEEB),
    'turquoise': Color(0xFF00897B),
    'teal': Color(0xFF008080),
    'green': Color(0xFF2E7D32),
    'olive': Color(0xFF808000),
    'mint': Color(0xFF98FF98),
    'emeraldgreen': Color(0xFF50C878),
    'forestgreen': Color(0xFF228B22),
    'brown': Color(0xFF5D4037),
    'beige': Color(0xFFF5F0DC),
    'tan': Color(0xFFD2B48C),
    'khaki': Color(0xFFBDB76B),
    'camel': Color(0xFFC19A6B),
    'chocolate': Color(0xFF7B3F00),
    'yellow': Color(0xFFF9A825),
    'mustard': Color(0xFFFFDB58),
    'orange': Color(0xFFE65100),
    'peach': Color(0xFFFFE5B4),
    'purple': Color(0xFF6A1B9A),
    'lavender': Color(0xFFE6E6FA),
    'magenta': Color(0xFFFF00FF),
    'gold': Color(0xFFD4AF37),
    'rosegold': Color(0xFFB76E79),
    'bronze': Color(0xFFCD7F32),
    'cream': Color(0xFFFFFDD0),
    'ivory': Color(0xFFFFFFF0),
  };
}
