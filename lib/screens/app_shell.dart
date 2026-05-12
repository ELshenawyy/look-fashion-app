import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:my_fashion_app/features/auth/domain/entities/user_entity.dart';
import 'package:my_fashion_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:my_fashion_app/firebase/login.dart';
import 'package:my_fashion_app/screens/add_product_screen.dart';
import 'package:my_fashion_app/screens/admin_dashboard.dart';
import 'package:my_fashion_app/screens/categories_screen.dart';
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
  int _selectedIndex = 0;
  bool _revokedHandled = false;

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
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

        final pages = <Widget>[
          const ProductListScreen(),
          const CategoriesScreen(),
          const CartPage(),
          FavoritesScreen(onBrowseProducts: () => _onItemTapped(0)),
          const ProfileScreen(),
        ];

        return Scaffold(
          backgroundColor: Colors.black,
          body: pages[_selectedIndex],
          floatingActionButton: isAdminLevel
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (isSuperAdmin) ...[
                      FloatingActionButton.small(
                        backgroundColor: Colors.deepPurple,
                        heroTag: 'staff',
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const StaffManagementScreen(),
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
                          builder: (_) =>
                              AdminDashboard(isSuperAdmin: isSuperAdmin),
                        ),
                      ),
                      tooltip: 'لوحة الإدارة',
                      child: const Icon(Icons.dashboard),
                    ),
                    const SizedBox(height: 8),
                    FloatingActionButton(
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
                )
              : null,
          floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
          bottomNavigationBar: Consumer<CartProvider>(
            builder: (context, cart, _) => BottomNavigationBar(
              currentIndex: _selectedIndex,
              onTap: _onItemTapped,
              type: BottomNavigationBarType.fixed,
              backgroundColor: Colors.black,
              selectedItemColor: const Color(0xFFFFE600),
              unselectedItemColor: Colors.white70,
              items: [
                const BottomNavigationBarItem(
                  icon: Icon(Icons.home),
                  label: 'الرئيسية',
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.grid_view_rounded),
                  label: 'التصنيفات',
                ),
                BottomNavigationBarItem(
                  icon: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Icon(Icons.shopping_cart),
                      if (cart.itemCount > 0)
                        Positioned(
                          right: -6,
                          top: -4,
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                              color: Color(0xFFD4AF37),
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '${cart.itemCount}',
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  label: 'السلة',
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.favorite_border),
                  label: 'المفضلة',
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.person_outline),
                  label: 'الملف الشخصي',
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
