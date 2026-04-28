import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:my_fashion_app/screens/account_info_screen.dart';
import 'package:my_fashion_app/screens/admin_orders_screen.dart';
import 'package:my_fashion_app/screens/orders_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const Color _gold = Color(0xFFD4AF37);

  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _checkAdmin();
  }

  Future<void> _checkAdmin() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final role = doc.data()?['role'] as String? ?? '';
    if (mounted) {
      setState(() => _isAdmin = role.toLowerCase() == 'admin');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final displayName = user?.displayName?.isNotEmpty == true
        ? user!.displayName!
        : (user?.email?.split('@').first ?? 'مستخدم');
    final email = user?.email ?? '';

    return Container(
      color: Colors.black,
      child: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 12),
            // Avatar
            Center(
              child: Stack(
                children: [
                  Container(
                    width: 92,
                    height: 92,
                    decoration: BoxDecoration(
                      color: const Color(0xFF121212),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _isAdmin
                            ? _gold.withValues(alpha: 0.6)
                            : Colors.white12,
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      _isAdmin
                          ? Icons.admin_panel_settings_outlined
                          : Icons.person_outline,
                      color: _gold,
                      size: 44,
                    ),
                  ),
                  if (_isAdmin)
                    Positioned(
                      bottom: 2,
                      right: 2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _gold,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'أدمن',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              displayName,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (email.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                email,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white54, fontSize: 14),
              ),
            ],
            const SizedBox(height: 28),

            // Account Info — for everyone
            _ProfileTile(
              icon: Icons.person,
              title: 'معلومات الحساب',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AccountInfoScreen()),
              ),
            ),
            const SizedBox(height: 12),

            // Admin: show orders management; User: show their own orders
            _ProfileTile(
              icon: _isAdmin
                  ? Icons.receipt_long_outlined
                  : Icons.local_shipping_outlined,
              title: _isAdmin ? 'إدارة الطلبات' : 'الطلبات والتتبع',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => _isAdmin
                      ? const AdminOrdersScreen()
                      : const OrdersScreen(),
                ),
              ),
            ),

            // Support — only for regular users, not admin
            if (!_isAdmin) ...[
              const SizedBox(height: 12),
              _ProfileTile(
                icon: Icons.support_agent_outlined,
                title: 'الدعم',
                onTap: () => _showSupportDialog(context),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showSupportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF180808),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'الدعم والمساعدة',
          style: TextStyle(
              color: Color(0xFFD4AF37), fontWeight: FontWeight.w700),
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SupportItem(
                icon: Icons.email_outlined,
                text: 'support@myfashionapp.com'),
            SizedBox(height: 12),
            _SupportItem(icon: Icons.phone_outlined, text: '+20 120 050 7628'),
            SizedBox(height: 12),
            _SupportItem(
                icon: Icons.access_time,
                text: 'السبت – الخميس: 9 ص – 9 م'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق',
                style: TextStyle(color: Color(0xFFD4AF37))),
          ),
        ],
      ),
    );
  }
}

class _SupportItem extends StatelessWidget {
  final IconData icon;
  final String text;

  const _SupportItem({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFFD4AF37), size: 20),
        const SizedBox(width: 10),
        Expanded(
          child:
              Text(text, style: const TextStyle(color: Colors.white70)),
        ),
      ],
    );
  }
}

class _ProfileTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _ProfileTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white10),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Icon(icon, color: const Color.fromARGB(255, 255, 230, 0)),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.white54),
      ),
    );
  }
}
