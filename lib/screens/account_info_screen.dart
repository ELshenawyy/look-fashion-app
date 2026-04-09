import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AccountInfoScreen extends StatelessWidget {
  const AccountInfoScreen({Key? key}) : super(key: key);

  static const Color _gold = Color(0xFFD4AF37);
  static const Color _panel = Color(0xFF180808);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('معلومات الحساب'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _gold),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                color: Color(0xFF121212),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person, color: _gold, size: 40),
            ),
          ),
          const SizedBox(height: 24),
          _InfoTile(
            icon: Icons.email_outlined,
            label: 'البريد الإلكتروني',
            value: user?.email ?? 'غير متاح',
          ),
          const SizedBox(height: 12),
          _InfoTile(
            icon: Icons.badge_outlined,
            label: 'المعرف (UID)',
            value: user?.uid ?? 'غير متاح',
          ),
          const SizedBox(height: 12),
          _InfoTile(
            icon: Icons.verified_user_outlined,
            label: 'حالة التحقق',
            value: (user?.emailVerified ?? false) ? 'تم التحقق' : 'لم يتم التحقق',
            valueColor: (user?.emailVerified ?? false) ? Colors.green : Colors.orange,
          ),
          const SizedBox(height: 12),
          _InfoTile(
            icon: Icons.phone_outlined,
            label: 'رقم الهاتف',
            value: user?.phoneNumber ?? 'غير مضاف',
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color valueColor;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor = Colors.white,
  });

  static const Color _gold = Color(0xFFD4AF37);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF180808),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Icon(icon, color: _gold, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(color: Colors.white54, fontSize: 12)),
                const SizedBox(height: 4),
                Text(value,
                    style: TextStyle(
                        color: valueColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
