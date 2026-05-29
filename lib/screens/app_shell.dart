import 'package:flutter/material.dart';
import 'package:iconly/iconly.dart';
import 'package:provider/provider.dart';
import 'package:my_fashion_app/features/auth/domain/entities/user_entity.dart';
import 'package:my_fashion_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:my_fashion_app/firebase/login.dart';
import 'package:my_fashion_app/screens/add_product_screen.dart';
import 'package:my_fashion_app/screens/admin_coupons_screen.dart';
import 'package:my_fashion_app/screens/admin_dashboard.dart';
import 'package:my_fashion_app/screens/categories_screen.dart';
import 'package:my_fashion_app/screens/email_verification_screen.dart';
import 'package:my_fashion_app/screens/favorites_screen.dart';
import 'package:my_fashion_app/screens/profile_screen.dart';
import 'package:my_fashion_app/screens/product_list_screen.dart';
import 'package:my_fashion_app/screens/cart.dart';
import 'package:my_fashion_app/screens/staff_management_screen.dart';
import 'package:my_fashion_app/features/cart/presentation/providers/cart_provider.dart';

/// AppShell — يعتمد كلياً على AuthProvider من Clean Architecture.
/// لا استدعاءات Firebase مباشرة.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  static const Color _gold = Color(0xFFD4AF37);
  static const Color _navBg = Color(0xFF0A0A0A); // أسود عميق للـ nav
  static const Color _inactive = Color(0xFF6B6B6B);

  int _selectedIndex = 0;
  bool _revokedHandled = false;
  String? _lastUid; // لاكتشاف تبديل الحساب

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  /// Tab item للـ BottomAppBar — أيقونة bold/light + label + لون نشط ذهبي.
  Widget _buildNavItem({
    required int index,
    required IconData iconActive,
    required IconData iconInactive,
    required String label,
  }) {
    final isActive = _selectedIndex == index;
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _onItemTapped(index),
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  transitionBuilder: (child, anim) =>
                      ScaleTransition(scale: anim, child: child),
                  child: Icon(
                    isActive ? iconActive : iconInactive,
                    key: ValueKey('${index}_$isActive'),
                    color: isActive ? _gold : _inactive,
                    size: 22,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    color: isActive ? _gold : _inactive,
                    fontSize: 10,
                    fontWeight:
                        isActive ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleRevocation(BuildContext context) async {
    if (_revokedHandled) return;
    _revokedHandled = true;
    await context.read<AuthProvider>().signOut();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (_) => false,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم إلغاء صلاحياتك من قِبل المدير.'),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        // ── حالة التحميل الأولي ─────────────────────────────────────────
        if (auth.status == AuthStatus.unknown) {
          return const Scaffold(
            backgroundColor: Colors.black,
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFFD4AF37)),
            ),
          );
        }

        // ── غير مسجَّل ───────────────────────────────────────────────────
        if (auth.status == AuthStatus.unauthenticated) {
          return const LoginPage();
        }

        // ── ملغى ────────────────────────────────────────────────────────
        if (auth.status == AuthStatus.revoked) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _handleRevocation(context);
          });
          return const Scaffold(
            backgroundColor: Colors.black,
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFFD4AF37)),
            ),
          );
        }

        // ── authenticated ───────────────────────────────────────────────
        final UserEntity user = auth.user!;
        final isAdminLevel = user.isAdmin;
        final isSuperAdmin = user.isSuperAdmin;

        // ── Email Verification Gate ────────────────────────────────────
        // المستخدمون المسجلون بالبريد لازم يفعّلوا قبل دخول التطبيق.
        // مستخدمو الهاتف (OTP) معفيون — لا يوجد لديهم بريد لتفعيله.
        final email = user.email ?? '';
        final hasPhone = (user.phone ?? '').isNotEmpty;
        // gate يُفعَّل فقط لمن لديه email + لم يُفعَّل + ليس مستخدم هاتف بحت
        if (email.isNotEmpty && !user.emailVerified && !hasPhone) {
          return const EmailVerificationScreen();
        }

        // ⚠️ تبديل حساب: صفّر التاب الحالي + reset state الشاشات.
        // KeyedSubtree(key: ValueKey(user.uid)) يجبر Flutter على
        // إنشاء State جديد لكل شاشة → لا تسرّب من الحساب القديم.
        if (_lastUid != null && _lastUid != user.uid) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _selectedIndex = 0);
          });
        }
        _lastUid = user.uid;

        final pages = <Widget>[
          const ProductListScreen(),
          const CategoriesScreen(),
          const CartPage(),
          FavoritesScreen(onBrowseProducts: () => _onItemTapped(0)),
          const ProfileScreen(),
        ];

        return Scaffold(
          backgroundColor: Colors.black,
          // ── body مع overlay للـ admin FABs ────────────────────────────
          body: Stack(
            children: [
              KeyedSubtree(
                key: ValueKey('shell_${user.uid}'),
                child: pages[_selectedIndex],
              ),
              // Admin FABs — يطفون فوق المحتوى وفوق الـ BottomAppBar
              if (isAdminLevel)
                Positioned(
                  right: 16,
                  bottom: 80, // فوق الـ nav bar (الـ nav ~56 + هامش)
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isSuperAdmin) ...[
                        FloatingActionButton.small(
                          backgroundColor: Colors.deepPurple,
                          heroTag: 'staff',
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  const StaffManagementScreen(),
                            ),
                          ),
                          tooltip: 'إدارة الموظفين',
                          child: const Icon(Icons.manage_accounts),
                        ),
                        const SizedBox(height: 8),
                      ],
                      FloatingActionButton.small(
                        backgroundColor: Colors.blue,
                        heroTag: 'dashboard',
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AdminDashboard(
                                isSuperAdmin: isSuperAdmin),
                          ),
                        ),
                        tooltip: 'لوحة الإدارة',
                        child: const Icon(Icons.dashboard),
                      ),
                      const SizedBox(height: 8),
                      FloatingActionButton.small(
                        backgroundColor: const Color(0xFFD4AF37),
                        heroTag: 'coupons',
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AdminCouponsScreen(),
                          ),
                        ),
                        tooltip: 'الكوبونات',
                        child: const Icon(Icons.local_offer,
                            color: Colors.black),
                      ),
                      const SizedBox(height: 8),
                      FloatingActionButton.small(
                        backgroundColor: const Color(0xFF800000),
                        heroTag: 'add',
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AddProductScreen(),
                          ),
                        ),
                        tooltip: 'إضافة منتج',
                        child: const Icon(Icons.add),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          // ── Cart FAB — وسط الـ nav (notched) ─────────────────────────
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerDocked,
          floatingActionButton: Consumer<CartProvider>(
            builder: (context, cart, _) => Container(
              height: 52,
              width: 52,
              margin: const EdgeInsets.only(top: 6),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_gold, Color(0xFFB8941F)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: _gold.withValues(alpha: 0.4),
                    blurRadius: 10,
                    spreadRadius: 0,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => _onItemTapped(2),
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      const Icon(
                        IconlyBold.bag,
                        color: Colors.black,
                        size: 24,
                      ),
                      if (cart.itemCount > 0)
                        Positioned(
                          right: 4,
                          top: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.red.shade600,
                              borderRadius: BorderRadius.circular(8),
                              border:
                                  Border.all(color: _gold, width: 1),
                            ),
                            constraints: const BoxConstraints(
                                minWidth: 16, minHeight: 16),
                            child: Text(
                              '${cart.itemCount}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // ── Bottom Nav — BottomAppBar مع notch ───────────────────────
          bottomNavigationBar: BottomAppBar(
            color: _navBg,
            shape: const CircularNotchedRectangle(),
            notchMargin: 6,
            elevation: 10,
            padding: EdgeInsets.zero,
            child: SizedBox(
              height: 56,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavItem(
                    index: 0,
                    iconActive: IconlyBold.home,
                    iconInactive: IconlyLight.home,
                    label: 'الرئيسية',
                  ),
                  _buildNavItem(
                    index: 1,
                    iconActive: IconlyBold.category,
                    iconInactive: IconlyLight.category,
                    label: 'الأقسام',
                  ),
                  const SizedBox(width: 48), // فراغ الـ notch
                  _buildNavItem(
                    index: 3,
                    iconActive: IconlyBold.heart,
                    iconInactive: IconlyLight.heart,
                    label: 'المفضلة',
                  ),
                  _buildNavItem(
                    index: 4,
                    iconActive: IconlyBold.profile,
                    iconInactive: IconlyLight.profile,
                    label: 'الملف الشخصي',
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
