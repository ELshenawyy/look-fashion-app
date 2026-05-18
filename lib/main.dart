import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:my_fashion_app/screens/splash_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:my_fashion_app/features/cart/presentation/providers/cart_provider.dart'
    as cart_p;
import 'package:my_fashion_app/features/profile/presentation/providers/profile_provider.dart'
    as profile_p;
import 'package:my_fashion_app/core/di/injection_container.dart' as di;
import 'package:my_fashion_app/features/auth/presentation/providers/auth_provider.dart'
    as auth_p;
import 'package:my_fashion_app/features/favorites/presentation/providers/favorites_provider.dart';
import 'package:my_fashion_app/features/addresses/presentation/providers/addresses_provider.dart';
import 'package:my_fashion_app/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:my_fashion_app/screens/notifications_screen.dart' as notif_screen;
import 'package:my_fashion_app/features/orders/presentation/providers/orders_provider.dart';
import 'package:my_fashion_app/features/products/presentation/providers/categories_provider.dart';
import 'package:my_fashion_app/features/products/presentation/providers/products_provider.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Configure Firestore persistence
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
  );

  // ─── Initialize Dependency Injection (Clean Architecture) ─────────────
  await di.init();

  // ─── ربط NotificationsScreen.getUnreadCount بـ DI ─────────────────────
  notif_screen.registerUnreadCountResolver(
    (uid, isAdmin) => di
        .sl<NotificationsProvider>()
        .watchUnreadCount(userId: uid, isAdmin: isAdmin),
  );

  if (kDebugMode) {
    debugPrint('✅ Firebase + DI initialized successfully');
  }

  runApp(
    MultiProvider(
      providers: [
        // Clean Architecture providers (يُحقَنون من DI)
        ChangeNotifierProvider<profile_p.ProfileProvider>.value(
            value: di.sl<profile_p.ProfileProvider>()),
        ChangeNotifierProvider<auth_p.AuthProvider>.value(
            value: di.sl<auth_p.AuthProvider>()),
        ChangeNotifierProvider<cart_p.CartProvider>.value(
            value: di.sl<cart_p.CartProvider>()),
        // ⚠️ نستخدم .value لأن كل هذه أصبحت singletons في DI.
        // مع .value، نفس الـ instance تُحقن في كل مكان — يضمن أن
        // reset() المستدعى من signOut يصل للـ instance المرتبط بالشاشات.
        ChangeNotifierProvider<FavoritesProvider>.value(
            value: di.sl<FavoritesProvider>()),
        ChangeNotifierProvider<ProductsProvider>.value(
            value: di.sl<ProductsProvider>()),
        ChangeNotifierProvider<CategoriesProvider>.value(
            value: di.sl<CategoriesProvider>()),
        ChangeNotifierProvider<AddressesProvider>.value(
            value: di.sl<AddressesProvider>()),
        ChangeNotifierProvider<OrdersProvider>.value(
            value: di.sl<OrdersProvider>()),
        ChangeNotifierProvider<NotificationsProvider>.value(
            value: di.sl<NotificationsProvider>()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  static const Color _gold = Color(0xFFD4AF37);

  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      locale: const Locale('ar'),
      supportedLocales: const [
        Locale('ar'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      title: 'تطبيق الأزياء',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.black,
        snackBarTheme: const SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          elevation: 0,
          centerTitle: true,
          foregroundColor: _gold,
          iconTheme: IconThemeData(color: _gold),
          titleTextStyle: TextStyle(
            color: _gold,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      home: const SplashScreen(),
    );
  }
}

