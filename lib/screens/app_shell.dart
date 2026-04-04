import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:my_fashion_app/screens/add_product_screen.dart';
import 'package:my_fashion_app/screens/product_list_screen.dart';
import 'package:my_fashion_app/screens/products.dart';
import 'package:my_fashion_app/screens/cart.dart';
import 'package:my_fashion_app/screens/about.dart';

class AppShell extends StatefulWidget {
  const AppShell({Key? key}) : super(key: key);

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;
  bool _isAdmin = false;

  static final List<Widget> _pages = <Widget>[
    ProductListScreen(),
    Productss(),
    CartPage(),
    About(),
  ];

  @override
  void initState() {
    super.initState();
    _loadCurrentUserRole();
  }

  Future<void> _loadCurrentUserRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists) {
        final role = doc.data()?['role']?.toString().toLowerCase();
        if (role == 'admin') {
          if (mounted) {
            setState(() {
              _isAdmin = true;
            });
          }
          return;
        }
      }
    } catch (_) {
      // Ignore errors and keep admin state false.
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Widget _buildBarItem(IconData icon, String label, int index) {
    final bool selected = _selectedIndex == index;
    final color = selected ? const Color(0xFFFFE600) : Colors.white70;

    return MaterialButton(
      minWidth: 60,
      onPressed: () => _onItemTapped(index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: color),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      floatingActionButton: _isAdmin
          ? FloatingActionButton(
              backgroundColor: const Color(0xFF800000),
              child: const Icon(Icons.add),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddProductScreen()),
                );
              },
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        color: Colors.black,
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        child: SizedBox(
          height: 64,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _buildBarItem(Icons.home, 'Home', 0),
                  _buildBarItem(Icons.shopping_bag, 'Products', 1),
                ],
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _buildBarItem(Icons.shopping_cart, 'Cart', 2),
                  _buildBarItem(Icons.info, 'About', 3),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
