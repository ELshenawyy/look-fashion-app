import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:my_fashion_app/firebase/login.dart';
import 'package:my_fashion_app/providers/profile_provider.dart';
import 'package:my_fashion_app/screens/about.dart';
import 'package:my_fashion_app/screens/addresses_screen.dart';
import 'package:my_fashion_app/screens/admin_orders_screen.dart';
import 'package:my_fashion_app/screens/edit_profile_screen.dart';
import 'package:my_fashion_app/screens/orders_screen.dart';
import 'package:my_fashion_app/screens/privacy_policy_screen.dart';
import 'package:my_fashion_app/screens/staff_management_screen.dart';
import 'package:my_fashion_app/screens/terms_screen.dart';
import 'package:my_fashion_app/services/role_service.dart';
import 'package:my_fashion_app/widgets/app_sliver_bar.dart';
import 'package:my_fashion_app/widgets/user_avatar.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  static const Color _gold = Color(0xFFD4AF37);
  static const Color _panel = Color(0xFF180808);

  static const String _whatsappNumber = '00249968991500';
  static const String _supportEmail = 'mohamedaaltaayeb@gmail.com';

  // ── Launch URL helpers ────────────────────────────────────────────────
  static Future<void> _openWhatsApp() async {
    final uri = Uri.parse('https://wa.me/$_whatsappNumber');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  static Future<void> _openEmail() async {
    final uri = Uri.parse('mailto:$_supportEmail');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  // ── Pick & upload image ───────────────────────────────────────────────
  static Future<void> _pickAndUpload(
      BuildContext context, ImageSource source) async {
    Navigator.pop(context);
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      imageQuality: 75,
      maxWidth: 800,
    );
    if (picked == null || !context.mounted) return;

    final provider = context.read<ProfileProvider>();
    final success =
        await provider.uploadProfileImage(File(picked.path));

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(success
          ? 'تم تحديث صورة الملف الشخصي'
          : (provider.errorMessage ?? 'فشل رفع الصورة')),
      backgroundColor: success ? Colors.green : Colors.red,
      behavior: SnackBarBehavior.floating,
    ));
  }

  void _showImageSourceSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2)),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined,
                    color: _gold),
                title: const Text('معرض الصور',
                    style: TextStyle(color: Colors.white)),
                onTap: () =>
                    _pickAndUpload(context, ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined,
                    color: _gold),
                title: const Text('الكاميرا',
                    style: TextStyle(color: Colors.white)),
                onTap: () =>
                    _pickAndUpload(context, ImageSource.camera),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Sign out ──────────────────────────────────────────────────────────
  Future<void> _confirmSignOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _panel,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Text('تسجيل الخروج',
            style: TextStyle(
                color: _gold, fontWeight: FontWeight.w700)),
        content: const Text(
          'هل أنت متأكد أنك تريد تسجيل الخروج؟',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء',
                style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('تسجيل الخروج',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      await FirebaseAuth.instance.signOut();
      if (!context.mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (_) => false,
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('فشل تسجيل الخروج: $e'),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const CustomScrollView(
        slivers: [
          AppSliverBar(title: 'الملف الشخصي'),
          SliverFillRemaining(
            child: Center(
              child: Text('يرجى تسجيل الدخول',
                  style: TextStyle(color: Colors.white54)),
            ),
          ),
        ],
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data();
        final role = data?['role'] as String? ?? AppRole.user;
        final isAdmin = AppRole.isAdminLevel(role);
        final isSuperAdmin = AppRole.isSuperAdmin(role);

        final displayName = data?['name'] as String? ??
            user.displayName ??
            user.email?.split('@').first ??
            'مستخدم';
        final email = user.email ?? '';

        return CustomScrollView(
          slivers: [
            const AppSliverBar(
              title: 'الملف الشخصي',
              actions: [NotificationBellAction()],
            ),
            SliverPadding(
              padding: const EdgeInsets.all(24),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  const SizedBox(height: 8),

                  // ── Avatar ───────────────────────────────────
                  Center(
                    child: Stack(
                      children: [
                        Consumer<ProfileProvider>(
                          builder: (_, provider, __) => provider.isUploadingImage
                              ? const CircleAvatar(
                                  radius: 52,
                                  backgroundColor: Color(0xFF121212),
                                  child: CircularProgressIndicator(
                                      color: _gold, strokeWidth: 2),
                                )
                              : const UserAvatarWidget(radius: 52),
                        ),
                        Positioned(
                          bottom: 2,
                          right: 2,
                          child: GestureDetector(
                            onTap: () => _showImageSourceSheet(context),
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: _gold,
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: Colors.black, width: 2),
                              ),
                              child: const Icon(Icons.camera_alt,
                                  color: Colors.black, size: 16),
                            ),
                          ),
                        ),
                        // Role badge
                        if (isAdmin)
                          Positioned(
                            top: 0,
                            left: 0,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isSuperAdmin
                                    ? _gold
                                    : Colors.blue,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                isSuperAdmin ? 'سوبر أدمن' : 'موظف',
                                style: const TextStyle(
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

                  // Name & email
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
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 14),
                    ),
                  ],
                  const SizedBox(height: 28),

                  // ── Account section ──────────────────────────
                  _sectionLabel('الحساب'),
                  const SizedBox(height: 8),

                  _ProfileTile(
                    icon: Icons.edit_outlined,
                    title: 'تعديل الملف الشخصي',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const EditProfileScreen()),
                    ),
                  ),

                  if (!isAdmin) ...[
                    const SizedBox(height: 10),
                    _ProfileTile(
                      icon: Icons.location_on_outlined,
                      title: 'عناوين الشحن',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const AddressesScreen()),
                      ),
                    ),
                  ],

                  const SizedBox(height: 10),
                  _ProfileTile(
                    icon: isAdmin
                        ? Icons.receipt_long_outlined
                        : Icons.local_shipping_outlined,
                    title:
                        isAdmin ? 'إدارة الطلبات' : 'الطلبات والتتبع',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => isAdmin
                            ? const AdminOrdersScreen()
                            : const OrdersScreen(),
                      ),
                    ),
                  ),

                  if (isSuperAdmin) ...[
                    const SizedBox(height: 10),
                    _ProfileTile(
                      icon: Icons.manage_accounts,
                      title: 'إدارة الموظفين',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                const StaffManagementScreen()),
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // ── Support section ──────────────────────────
                  if (!isAdmin) ...[
                    _sectionLabel('الدعم والمساعدة'),
                    const SizedBox(height: 8),

                    const _ProfileTile(
                      icon: Icons.chat_bubble_outline_rounded,
                      title: 'واتساب',
                      subtitle: '+$_whatsappNumber',
                      iconColor: Color(0xFF25D366),
                      onTap: _openWhatsApp,
                    ),
                    const SizedBox(height: 10),
                    const _ProfileTile(
                      icon: Icons.email_outlined,
                      title: 'البريد الإلكتروني',
                      subtitle: _supportEmail,
                      onTap: _openEmail,
                    ),

                    const SizedBox(height: 24),
                  ],

                  // ── Legal section ────────────────────────────
                  _sectionLabel('القانونية'),
                  const SizedBox(height: 8),

                  _ProfileTile(
                    icon: Icons.privacy_tip_outlined,
                    title: 'سياسة الخصوصية',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              const PrivacyPolicyScreen()),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _ProfileTile(
                    icon: Icons.description_outlined,
                    title: 'الشروط والأحكام',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const TermsScreen()),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _ProfileTile(
                    icon: Icons.info_outline_rounded,
                    title: 'من نحن',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const About()),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── Logout ───────────────────────────────────
                  _ProfileTile(
                    icon: Icons.logout,
                    title: 'تسجيل الخروج',
                    onTap: () => _confirmSignOut(context),
                    isDestructive: true,
                  ),
                  const SizedBox(height: 32),
                ]),
              ),
            ),
          ],
        );
      },
    );
  }

  static Widget _sectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white38,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

// ── Profile Tile ──────────────────────────────────────────────────────────
class _ProfileTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool isDestructive;
  final Color? iconColor;

  const _ProfileTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.isDestructive = false,
    this.iconColor,
  });

  static const Color _gold = Color(0xFFD4AF37);

  @override
  Widget build(BuildContext context) {
    final tileColor = isDestructive ? Colors.redAccent : (iconColor ?? _gold);
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDestructive
              ? Colors.red.withValues(alpha: 0.3)
              : Colors.white10,
        ),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Icon(icon, color: tileColor),
        title: Text(
          title,
          style: TextStyle(
            color: isDestructive ? Colors.redAccent : Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: subtitle != null
            ? Text(subtitle!,
                style:
                    const TextStyle(color: Colors.white38, fontSize: 12))
            : null,
        trailing: const Icon(Icons.chevron_right, color: Colors.white38),
      ),
    );
  }
}
