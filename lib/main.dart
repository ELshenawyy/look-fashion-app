import 'dart:async';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:my_fashion_app/screens/splash_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:my_fashion_app/features/cart/data/datasources/local_cart_datasource.dart';
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
import 'package:my_fashion_app/core/services/notification_service.dart';
import 'package:my_fashion_app/screens/notifications_screen.dart' as notif_screen;
import 'package:my_fashion_app/features/orders/presentation/providers/orders_provider.dart';
import 'package:my_fashion_app/features/products/presentation/providers/categories_provider.dart';
import 'package:my_fashion_app/features/products/presentation/providers/products_provider.dart';
import 'package:my_fashion_app/features/home/presentation/providers/home_ui_provider.dart';
import 'package:my_fashion_app/features/coupons/presentation/providers/coupons_provider.dart';
import 'firebase_options.dart';

// ─── FCM background message handler (must be top-level) ─────────────────────
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint('[FCM Background] ${message.notification?.title}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Edge-to-Edge UI (متطلب Google Play على Android 15+/API 35+) ─────────
  // يسمح لمحتوى Flutter بالرسم خلف الـ status bar والـ navigation bar.
  // مع خلفية التطبيق السوداء بالكامل، لازم أيقونات النظام تكون فاتحة
  // (light) حتى تبقى مرئية فوق المحتوى، والشاشات المعرَّضة (بدون
  // AppBar/SliverAppBar تلقائي) لازم تُغلَّف بـ SafeArea.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
      systemNavigationBarDividerColor: Colors.transparent,
    ),
  );

  // Register FCM background handler before runApp
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // ─── Global error handlers — registered unconditionally so crashes are
  // captured even if Firebase.initializeApp fails below. Falls back to
  // debugPrint if Crashlytics is unavailable (e.g. offline cold-start).
  //
  // ⚠ هاتان الـ handlers + runApp في نفس Zone (الـ root) = لا Zone
  // mismatch. لا نحتاج `runZonedGuarded` (كان يسبب الـ crash السابق).
  FlutterError.onError = (FlutterErrorDetails details) {
    try {
      FirebaseCrashlytics.instance.recordFlutterFatalError(details);
    } catch (_) {
      debugPrint('[FlutterError] ${details.exceptionAsString()}');
    }
  };
  // يلتقط كل الـ async errors (Future, Stream uncaught) — البديل الحديث
  // عن runZonedGuarded الموصى به من فريق Flutter.
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    try {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    } catch (_) {
      debugPrint('[PlatformError] $error');
    }
    return true; // الـ true تعني "تم التعامل معه، لا تكسر التطبيق"
  };

  // ─── Step-by-step init مع error screen لتشخيص الكراش ─────────────────
  String? initError;

  try {
    // Step 1: Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e, st) {
    initError = 'STEP 1 - Firebase.initializeApp:\n$e\n\n$st';
  }

  if (initError == null) {
    try {
      // App Check — debug mode uses debug provider (prints token to console),
      // release mode uses Play Integrity (works automatically on Play Store).
      await FirebaseAppCheck.instance.activate(
        androidProvider: kDebugMode
            ? AndroidProvider.debug
            : AndroidProvider.playIntegrity,
      );
    } catch (e, st) {
      initError = 'STEP 2 - FirebaseAppCheck.activate:\n$e\n\n$st';
    }
  }

  if (initError == null) {
    try {
      // Step 3: Firestore settings
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
      );
    } catch (e, st) {
      initError = 'STEP 3 - Firestore settings:\n$e\n\n$st';
    }
  }

  if (initError == null) {
    try {
      // Step 4: Dependency Injection
      await di.init();
    } catch (e, st) {
      initError = 'STEP 4 - DI init:\n$e\n\n$st';
    }
  }

  if (initError == null) {
    try {
      // Step 4b: Local notifications + FCM foreground handler
      await NotificationService.init();
    } catch (e) {
      debugPrint('NotificationService.init non-fatal: $e');
    }
  }

  if (initError == null) {
    try {
      // Step 5: Local Cart
      await di.sl<LocalCartDataSource>().init();
    } catch (e, st) {
      initError = 'STEP 5 - LocalCart init:\n$e\n\n$st';
    }
  }

  if (initError == null) {
    try {
      // Step 6: Notifications resolver
      notif_screen.registerUnreadCountResolver(
        (uid, isAdmin) => di
            .sl<NotificationsProvider>()
            .watchUnreadCount(userId: uid, isAdmin: isAdmin),
      );
    } catch (e, st) {
      initError = 'STEP 6 - Notifications resolver:\n$e\n\n$st';
    }
  }

  // لو في خطأ → أعرضه على الشاشة بدل ما يحصل crash صامت
  if (initError != null) {
    runApp(_ErrorApp(error: initError));
    return;
  }

  // ⚠️ مهم: `runApp` يجب أن يُستدعى في **نفس Zone** الذي يستدعي
  // `WidgetsFlutterBinding.ensureInitialized` (الـ root Zone هنا).
  // الـ Crashlytics بالفعل يلتقط async errors عبر
  // `PlatformDispatcher.instance.onError` المُسجَّل أعلاه — لا حاجة
  // لـ `runZonedGuarded` (كان يسبب Zone mismatch crash).
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
        // UI-only state (لا يحتاج DI لأنه transient لـ HomeScreen)
        ChangeNotifierProvider<HomeUIProvider>(
            create: (_) => HomeUIProvider()),
        // Coupons (admin CRUD + user apply في checkout)
        ChangeNotifierProvider<CouponsProvider>.value(
            value: di.sl<CouponsProvider>()),
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
      title: 'Talla-طلة',
      debugShowCheckedModeBanner: false,
      // ── إخفاء الكيبورد عند الضغط في أي مكان فاضي بأي شاشة ──
      // يلتف حول كل شاشة (home, push, dialog) → سلوك موحد عبر التطبيق
      builder: (context, child) {
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () {
            final focus = FocusManager.instance.primaryFocus;
            if (focus != null && focus.hasFocus) focus.unfocus();
          },
          child: child,
        );
      },
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

// ─── شاشة تعرض سبب الكراش بالضبط على الجهاز ────────────────────────────
class _ErrorApp extends StatelessWidget {
  final String error;
  const _ErrorApp({required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF1a0000),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '⚠️ Startup Error',
                  style: TextStyle(
                    color: Color(0xFFD4AF37),
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'خذ screenshot وابعته للمطوّر',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: SingleChildScrollView(
                    child: SelectableText(
                      error,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
