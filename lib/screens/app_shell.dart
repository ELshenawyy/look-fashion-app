import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:my_fashion_app/firebase/login.dart';
import 'package:my_fashion_app/screens/add_product_screen.dart';
import 'package:my_fashion_app/screens/admin_dashboard.dart';
import 'package:my_fashion_app/screens/categories_screen.dart';
import 'package:my_fashion_app/screens/favorites_screen.dart';
import 'package:my_fashion_app/screens/profile_screen.dart';
import 'package:my_fashion_app/screens/product_list_screen.dart';
import 'package:my_fashion_app/screens/cart.dart';
import 'package:my_fashion_app/services/cart_provider.dart';

class AppShell extends StatefulWidget {
  const AppShell({Key? key}) : super(key: key);

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;
  bool _isSigningOut = false;

  static const List<String> _titles = <String>[
    'الرئيسية',
    'التصنيفات',
    'السلة',
    'المفضلة',
    'الملف الشخصي',
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<void> _signOut() async {
    if (_isSigningOut) return;

    setState(() {
      _isSigningOut = true;
      _selectedIndex = 0;
    });

    try {
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => LoginPage()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isSigningOut = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل تسجيل الخروج: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    // If no user is logged in, return a login screen or splash
    if (user == null) {
      print('DEBUG: No user logged in');
      return LoginPage();
    }

    print('DEBUG: Current User UID: ${user.uid}');

    // Real-time StreamBuilder to listen to user role changes
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        print(
            'DEBUG: StreamBuilder state - connectionState: ${snapshot.connectionState}');

        bool isAdmin = false;
        dynamic rawRole;

        if (snapshot.hasData) {
          final userData = snapshot.data?.data();
          rawRole = userData?['role'];
          isAdmin = !_isSigningOut &&
              rawRole is String &&
              rawRole.toLowerCase() == 'admin';

          print('DEBUG: Firestore data received: $userData');
          print(
              'DEBUG: Raw role value: $rawRole (type: ${rawRole.runtimeType})');
          print(
              'TERMINAL LOG: UID: ${user.uid} | IsAdmin: $isAdmin | RawRole: $rawRole');
        } else if (snapshot.hasError) {
          print('DEBUG: Error fetching user role: ${snapshot.error}');
          print(
              'TERMINAL LOG: UID: ${user.uid} | IsAdmin: false | RawRole: null');
        } else if (snapshot.connectionState == ConnectionState.waiting) {
          print('DEBUG: Waiting for Firestore data...');
        }

        final pages = <Widget>[
          const ProductListScreen(),
          const CategoriesScreen(),
          const CartPage(),
          const FavoritesScreen(),
          const ProfileScreen(),
        ];

        return Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            elevation: 0,
            title: Text(
              _titles[_selectedIndex],
              style: const TextStyle(color: Colors.white),
            ),
            actions: [
              if (isAdmin)
                IconButton(
                  icon: const Icon(Icons.dashboard, color: Colors.blue),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AdminDashboard(),
                      ),
                    );
                  },
                  tooltip: 'لوحة الإدارة',
                ),
              IconButton(
                icon: const Icon(Icons.logout, color: Colors.white),
                onPressed: _isSigningOut ? null : _signOut,
                tooltip: 'تسجيل الخروج',
              ),
            ],
          ),
          body: pages[_selectedIndex],
          floatingActionButton: isAdmin
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    FloatingActionButton.small(
                      backgroundColor: Colors.blue,
                      heroTag: 'dashboard',
                      child: const Icon(Icons.dashboard),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AdminDashboard(),
                          ),
                        );
                      },
                      tooltip: 'لوحة الإدارة',
                    ),
                    const SizedBox(height: 12),
                    FloatingActionButton(
                      backgroundColor: const Color(0xFF800000),
                      heroTag: 'add',
                      child: const Icon(Icons.add),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AddProductScreen(),
                          ),
                        );
                      },
                      tooltip: 'إضافة منتج',
                    ),
                  ],
                )
              : null,
          floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
          bottomNavigationBar: Consumer<Cart>(
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
