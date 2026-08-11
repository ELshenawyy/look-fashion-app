import 'package:flutter/material.dart';
import 'package:iconly/iconly.dart';
import 'package:provider/provider.dart';

import 'package:my_fashion_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:my_fashion_app/firebase/login.dart';

/// شاشة gate — تظهر للمستخدم اللي سجّل بإيميل ولم يفعّل بعد.
/// لا يقدر يتقدّم للتطبيق حتى يضغط رابط التفعيل من بريده.
class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  static const Color _gold = Color(0xFFD4AF37);
  static const Color _bg = Color(0xFF000000);

  bool _checking = false;

  Future<void> _checkVerified() async {
    if (_checking) return;
    setState(() => _checking = true);
    final verified =
        await context.read<AuthProvider>().refreshCurrentUser();
    if (!mounted) return;
    setState(() => _checking = false);
    if (!verified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'البريد لم يُفعَّل بعد. افتح بريدك واضغط الرابط ثم حاول مجدداً.'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    // لو verified: الـ AppShell سيلتقط التغيير تلقائياً ويعرض الـ home
  }

  Future<void> _resend() async {
    final auth = context.read<AuthProvider>();
    final ok = await auth.resendVerificationEmail();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok
            ? 'تم إرسال رابط التفعيل مجدداً ✓'
            : 'فشل إرسال الرابط — حاول بعد قليل'),
        backgroundColor: ok ? Colors.green : Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _signOutAndGoLogin() async {
    final auth = context.read<AuthProvider>();
    await auth.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        final email = auth.user?.email ?? 'بريدك الإلكتروني';
        final cooldown = auth.verificationCooldownSec;
        return Scaffold(
          backgroundColor: _bg,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                children: [
                  const Spacer(),
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: _gold.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                      border:
                          Border.all(color: _gold.withValues(alpha: 0.4)),
                    ),
                    child: const Icon(IconlyBold.message,
                        color: _gold, size: 44),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'تحقّق من بريدك الإلكتروني',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 14),
                  RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        height: 1.7,
                      ),
                      children: [
                        const TextSpan(
                            text: 'أرسلنا رابط التفعيل إلى\n'),
                        TextSpan(
                          text: email,
                          style: const TextStyle(
                            color: _gold,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const TextSpan(
                            text:
                                '\nافتح بريدك واضغط الرابط لتفعيل حسابك.'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'تحقّق من Spam لو لم يصل خلال دقيقة',
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  const Spacer(),

                  // زر "تحقّقت بالفعل"
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _checking ? null : _checkVerified,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _gold,
                        foregroundColor: Colors.black,
                        disabledBackgroundColor:
                            _gold.withValues(alpha: 0.4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: _checking
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                color: Colors.black,
                                strokeWidth: 2.5,
                              ),
                            )
                          : const Text(
                              'تحقّقت بالفعل',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // زر "إعادة الإرسال" مع cooldown
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton(
                      onPressed: cooldown > 0 ? null : _resend,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: cooldown > 0
                              ? Colors.white24
                              : _gold.withValues(alpha: 0.6),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        cooldown > 0
                            ? 'إعادة الإرسال ($cooldown ث)'
                            : 'إعادة إرسال الرابط',
                        style: TextStyle(
                          color: cooldown > 0
                              ? Colors.white38
                              : _gold,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    '💡 في حال عدم وصول الرسالة إلى البريد الوارد، يرجى مراجعة '
                    'مجلد الرسائل غير المرغوب فيها (Spam / Junk Mail).',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                  const SizedBox(height: 16),

                  // زر تسجيل الخروج
                  TextButton(
                    onPressed: _signOutAndGoLogin,
                    child: const Text(
                      'تسجيل الخروج واستخدام حساب آخر',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
