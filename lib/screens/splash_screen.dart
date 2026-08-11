import 'package:flutter/material.dart';
import 'package:my_fashion_app/screens/app_shell.dart';

/// شاشة افتتاحية متحركة — تظهر بعد native splash، تعرض اسم "طلة"
/// بـ animation (ط ذهبي + لة أبيض) ثم تنتقل إلى MainScreen.
///
/// تسلسل الـ animation:
///   0.0 → 0.5  : fade-in + scale-up لكل حرف بـ stagger
///   0.5 → 1.0  : pulse خفيف + hold
///   1.0       : Navigator.pushReplacement → AppShell
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  static const Color _gold = Color(0xFFD4AF37);
  static const Color _black = Color(0xFF000000);
  static const Duration _animDuration = Duration(milliseconds: 1800);
  static const Duration _holdDuration = Duration(milliseconds: 700);

  late final AnimationController _controller;
  late final Animation<double> _scaleTa;        // ط
  late final Animation<double> _scaleLam;       // ل
  late final Animation<double> _scaleTaMarbouta;// ة
  late final Animation<double> _fadeSubtitle;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _animDuration);

    // كل حرف يدخل بـ stagger مختلف — يبدأ من 0 إلى 1 بحجم وتلاشي
    _scaleTa = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.00, 0.45, curve: Curves.elasticOut),
    );
    _scaleLam = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.15, 0.60, curve: Curves.elasticOut),
    );
    _scaleTaMarbouta = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.30, 0.75, curve: Curves.elasticOut),
    );
    _fadeSubtitle = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.65, 1.00, curve: Curves.easeOut),
    );

    _controller.forward().then((_) async {
      await Future.delayed(_holdDuration);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 500),
          pageBuilder: (_, animation, __) => FadeTransition(
            opacity: animation,
            child: const AppShell(),
          ),
        ),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _letter(String char, Color color, Animation<double> anim) {
    return AnimatedBuilder(
      animation: anim,
      builder: (_, __) => Opacity(
        opacity: anim.value.clamp(0.0, 1.0),
        child: Transform.scale(
          scale: 0.4 + (anim.value * 0.6), // 0.4 → 1.0
          child: Text(
            char,
            style: TextStyle(
              fontSize: 90,
              fontWeight: FontWeight.w900,
              color: color,
              fontFamily: 'arimo',
              height: 1.0,
              shadows: [
                Shadow(
                  color: color.withValues(alpha: 0.35),
                  blurRadius: 25,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _black,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ── اسم العلامة "طلة" ──
              // RTL: ط (يمين) ← ل ← ة (يسار)
              Row(
                mainAxisSize: MainAxisSize.min,
                textDirection: TextDirection.rtl,
                children: [
                  _letter('ط', _gold, _scaleTa),
                  _letter('ل', Colors.white, _scaleLam),
                  _letter('ة', Colors.white, _scaleTaMarbouta),
                ],
              ),
              const SizedBox(height: 14),

              // ── سطر فرعي بـ fade متأخر ──
              FadeTransition(
                opacity: _fadeSubtitle,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 6),
                  decoration: BoxDecoration(
                    border: Border.all(
                        color: _gold.withValues(alpha: 0.4), width: 1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'أناقتك تبدأ من هنا',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      letterSpacing: 1.5,
                      fontFamily: 'arial',
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),

              // ── Loader خفيف ──
              FadeTransition(
                opacity: _fadeSubtitle,
                child: const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    color: _gold,
                    strokeWidth: 2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
