import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class About extends StatelessWidget {
  const About({super.key});

  static const Color _gold = Color(0xFFD4AF37);
  static const Color _maroon = Color(0xFF570707);

  // ── معلومات التواصل — عدّلها من هنا ─────────────────────────────────
  static const String _supportEmail = 'support@MyFashionApp.com';
  static const String _supportPhone = '+249912345678'; // +249 = السودان

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: _maroon,
        elevation: 0,
        title: const Text('من نحن', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: _gold),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 30),
            // Logo
            ClipRRect(
              borderRadius: BorderRadius.circular(100),
              child: Image.asset(
                'assets/icon.png',
                height: 120,
                width: 120,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: _maroon,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: const Icon(Icons.storefront, color: _gold, size: 56),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'متجر طلّة',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: _gold,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'الإصدار 1.0.0',
              style: TextStyle(fontSize: 14, color: Colors.white54),
            ),
            const SizedBox(height: 30),

            // About card
            const _Card(
              title: 'عن التطبيق',
              child: Text(
                'تطبيق طلّة هو وجهتك المثالية لعشاق الموضة. '
                'يمكنك استعراض أحدث الصيحات، واكتشاف منتجات مميزة، '
                'وبناء إطلالتك الخاصة بسهولة. سواء كنت تهتم بالأزياء '
                'يوميًا أو تبحث عن قطع مميزة لمناسباتك، ستجد هنا ما '
                'يساعدك على الظهور بأفضل صورة.',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.white70,
                  height: 1.7,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),

            // Contact card
            _Card(
              title: 'تواصل معنا',
              child: Column(
                children: [
                  // Email — قابل للنقر
                  _ContactRow(
                    icon: Icons.email_outlined,
                    label: _supportEmail,
                    onTap: () => _launchUrl('mailto:$_supportEmail'),
                  ),
                  const SizedBox(height: 12),
                  // Phone — قابل للنقر
                  _ContactRow(
                    icon: Icons.phone_outlined,
                    label: _supportPhone,
                    onTap: () => _launchUrl('tel:$_supportPhone'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}

// ── Reusable Card ─────────────────────────────────────────────────────────
class _Card extends StatelessWidget {
  final String title;
  final Widget child;

  const _Card({required this.title, required this.child});

  static const Color _panel = Color(0xFF180808);
  static const Color _gold = Color(0xFFD4AF37);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: _gold,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

// ── Contact Row ───────────────────────────────────────────────────────────
class _ContactRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ContactRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFFD4AF37), size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  color: Colors.white70,
                  decoration: TextDecoration.underline,
                  decorationColor: Color(0xFFD4AF37),
                ),
              ),
            ),
            const Icon(Icons.open_in_new, color: Colors.white24, size: 16),
          ],
        ),
      ),
    );
  }
}
