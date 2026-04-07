import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:my_fashion_app/screens/app_shell.dart';
import 'package:device_preview/device_preview.dart';
import 'package:my_fashion_app/firebase/login.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Configure Firestore for development (disable App Check enforcement)
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
  );

  print('✅ Firebase initialized successfully');
  print('📱 Firestore configured for development (App Check not enforced)');
  print('🔗 Project ID: ${FirebaseFirestore.instance.app.options.projectId}');

  runApp(
    DevicePreview(
      enabled: true,
      builder: (context) => MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  static const Color _gold = Color(0xFFD4AF37);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      useInheritedMediaQuery: true,
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
      home: MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  _MainScreen createState() => _MainScreen();
}

class _MainScreen extends State<MainScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Offset> _buttonOffsetAnimation;
  late Animation<Offset> _textOffsetAnimation;
  bool _isTextAnimated = false;

  @override
  void initState() {
    super.initState();

    _animationController =
        AnimationController(vsync: this, duration: Duration(seconds: 1));

    _buttonOffsetAnimation =
        Tween<Offset>(begin: Offset(0, 1), end: Offset.zero).animate(
            CurvedAnimation(parent: _animationController, curve: Curves.ease));

    _textOffsetAnimation = Tween<Offset>(begin: Offset(0, 1), end: Offset.zero)
        .animate(
            CurvedAnimation(parent: _animationController, curve: Curves.ease));

    _animationController.addListener(() {
      if (_animationController.status == AnimationStatus.completed) {
        setState(() {
          _isTextAnimated = true;
        });
      }
    });

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
      return AppShell();
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
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
                child: Padding(
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
              SizedBox(height: 50),
              SlideTransition(
                position: _textOffsetAnimation,
                child: Text(
                  'ابدأ الآن في استكشاف أحدث الماركات وصيحات الأزياء والتسوق بسهولة.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _isTextAnimated
                        ? Color.fromARGB(255, 255, 255, 255)
                        : Color.fromARGB(255, 255, 255, 255),
                    fontSize: 20,
                    fontFamily: 'arial',
                  ),
                ),
              ),
              SizedBox(height: 30),
              SlideTransition(
                position: _buttonOffsetAnimation,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => AppShell()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.black,
                    backgroundColor: Color.fromARGB(255, 255, 255, 255),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(50.0),
                      side: BorderSide(color: Color.fromARGB(255, 0, 0, 0)),
                    ),
                    padding:
                        EdgeInsets.symmetric(vertical: 16.0, horizontal: 32.0),
                    textStyle: TextStyle(fontSize: 20.0),
                    minimumSize: Size(300.0, 60.0),
                  ),
                  child: Text(
                    'ابدأ الآن',
                    style: TextStyle(
                        color: Color.fromARGB(255, 0, 0, 0),
                        fontWeight: FontWeight.normal,
                        fontSize: 22,
                        fontFamily: 'arial'),
                  ),
                ),
              ),
              SizedBox(height: 20),
              SlideTransition(
                position: _buttonOffsetAnimation,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => LoginPage()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Color.fromARGB(255, 255, 255, 255),
                    backgroundColor: Color.fromARGB(0, 255, 255, 255),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(50.0),
                      side:
                          BorderSide(color: Color.fromARGB(255, 255, 255, 255)),
                    ),
                    padding:
                        EdgeInsets.symmetric(vertical: 16.0, horizontal: 32.0),
                    textStyle: TextStyle(fontSize: 20.0),
                    minimumSize: Size(300.0, 60.0),
                  ),
                  child: Text(
                    'تسجيل الدخول',
                    style: TextStyle(
                        color: Color.fromARGB(255, 255, 255, 255),
                        fontWeight: FontWeight.normal,
                        fontSize: 22,
                        fontFamily: 'arial'),
                  ),
                ),
              ),
              SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
