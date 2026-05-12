import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:my_fashion_app/screens/app_shell.dart';
import 'package:device_preview/device_preview.dart';
import 'package:my_fashion_app/firebase/login.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:my_fashion_app/features/cart/presentation/providers/cart_provider.dart'
    as cart_p;
import 'package:my_fashion_app/providers/profile_provider.dart';
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
        // Legacy providers (سيتم نقلها تباعاً للـ features/)
        ChangeNotifierProvider(create: (_) => ProfileProvider()),
        // Clean Architecture providers (يُحقَنون من DI)
        ChangeNotifierProvider<auth_p.AuthProvider>.value(
            value: di.sl<auth_p.AuthProvider>()),
        ChangeNotifierProvider<cart_p.CartProvider>.value(
            value: di.sl<cart_p.CartProvider>()),
        ChangeNotifierProvider(create: (_) => di.sl<FavoritesProvider>()),
        ChangeNotifierProvider(create: (_) => di.sl<ProductsProvider>()),
        ChangeNotifierProvider(create: (_) => di.sl<CategoriesProvider>()),
        ChangeNotifierProvider(create: (_) => di.sl<AddressesProvider>()),
        ChangeNotifierProvider<OrdersProvider>.value(
            value: di.sl<OrdersProvider>()),
        ChangeNotifierProvider<NotificationsProvider>.value(
            value: di.sl<NotificationsProvider>()),
      ],
      child: DevicePreview(
        enabled: false,
        builder: (context) => const MyApp(),
      ),
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
      builder: DevicePreview.appBuilder,
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
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _MainScreen createState() => _MainScreen();
}

class _MainScreen extends State<MainScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Offset> _buttonOffsetAnimation;
  late Animation<Offset> _textOffsetAnimation;

  @override
  void initState() {
    super.initState();

    _animationController =
        AnimationController(vsync: this, duration: const Duration(seconds: 1));

    _buttonOffsetAnimation =
        Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero).animate(
            CurvedAnimation(parent: _animationController, curve: Curves.ease));

    _textOffsetAnimation = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
        .animate(
            CurvedAnimation(parent: _animationController, curve: Curves.ease));

    _animationController.forward();
  }

  @override
  void dispose() {
    // Dispose the animation controller
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    // If user is logged in, go to AppShell (with admin check)
    if (user != null) {
      return const AppShell();
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/back.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              SlideTransition(
                position: _textOffsetAnimation,
                child: const Padding(
                  padding: EdgeInsets.only(left: 30.0),
                  child: Text(
                    'ماركات وإطلالات جديدة',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: Color.fromARGB(255, 255, 255, 255),
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'arimo',
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 50),
              SlideTransition(
                position: _textOffsetAnimation,
                child: const Text(
                  'ابدأ الآن في استكشاف أحدث الماركات وصيحات الأزياء والتسوق بسهولة.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color.fromARGB(255, 255, 255, 255),
                    fontSize: 20,
                    fontFamily: 'arial',
                  ),
                ),
              ),
              const SizedBox(height: 30),
              SlideTransition(
                position: _buttonOffsetAnimation,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const AppShell()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.black,
                    backgroundColor: const Color.fromARGB(255, 255, 255, 255),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(50.0),
                      side: const BorderSide(color: Color.fromARGB(255, 0, 0, 0)),
                    ),
                    padding:
                        const EdgeInsets.symmetric(vertical: 16.0, horizontal: 32.0),
                    textStyle: const TextStyle(fontSize: 20.0),
                    minimumSize: const Size(300.0, 60.0),
                  ),
                  child: const Text(
                    'ابدأ الآن',
                    style: TextStyle(
                        color: Color.fromARGB(255, 0, 0, 0),
                        fontWeight: FontWeight.normal,
                        fontSize: 22,
                        fontFamily: 'arial'),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SlideTransition(
                position: _buttonOffsetAnimation,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const LoginPage()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    foregroundColor: const Color.fromARGB(255, 255, 255, 255),
                    backgroundColor: const Color.fromARGB(0, 255, 255, 255),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(50.0),
                      side:
                          const BorderSide(color: Color.fromARGB(255, 255, 255, 255)),
                    ),
                    padding:
                        const EdgeInsets.symmetric(vertical: 16.0, horizontal: 32.0),
                    textStyle: const TextStyle(fontSize: 20.0),
                    minimumSize: const Size(300.0, 60.0),
                  ),
                  child: const Text(
                    'تسجيل الدخول',
                    style: TextStyle(
                        color: Color.fromARGB(255, 255, 255, 255),
                        fontWeight: FontWeight.normal,
                        fontSize: 22,
                        fontFamily: 'arial'),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
