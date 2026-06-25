import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'screens/main_navigation_screen.dart';
import 'screens/login_screen.dart';
import 'services/auth_service.dart';
import 'services/language_service.dart';
import 'services/notification_service.dart';
import 'services/config_service.dart';

void main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    await initializeDateFormatting();
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);

    // Activăm App Check pentru a rezolva eroarea de identitate la verificarea telefonului (doar pe Android)
    if (!kIsWeb) {
      await FirebaseAppCheck.instance.activate(
        androidProvider:
            kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
      );
    }

    // Initializăm Configurația Globală (Prețuri, etc) - ne-blocant
    ConfigService().initialize().catchError((e) => debugPrint("Config error: $e"));

    // Initializăm Notificările - ne-blocant
    NotificationService().initialize().catchError((e) => debugPrint("FCM error: $e"));

    FlutterError.onError = (errorDetails) {
      if (!kIsWeb) {
        FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
      } else {
        FlutterError.presentError(errorDetails);
      }
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      if (!kIsWeb) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      } else if (kDebugMode) {
        print("Async Error: $error\n$stack");
      }
      return true;
    };

    if (kDebugMode) {
      print("Firebase Connected");
      if (!kIsWeb) {
        print("Crashlytics Connected");
      }
    }

    runApp(const MyApp());
  }, (error, stack) {
    if (!kIsWeb) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    } else if (kDebugMode) {
      print("ZonedGuarded Error: $error\n$stack");
    }
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LanguageService(),
      builder: (context, child) {
        return MaterialApp(
          title: 'Parkly',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
              colorScheme:
                  ColorScheme.fromSeed(seedColor: const Color(0xFF2563EB)),
              scaffoldBackgroundColor: const Color(0xFFF8F9FB),
              useMaterial3: true,
              appBarTheme: const AppBarTheme(
                backgroundColor: Colors.white,
                elevation: 0,
                iconTheme: IconThemeData(color: Colors.black),
              )),
          home: const AuthWrapper(),
        );
      },
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper>
    with SingleTickerProviderStateMixin {
  bool _isSplashVisible = true;
  Timer? _splashTimer;
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    // Afișăm branding-ul pentru 3 secunde
    _splashTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _isSplashVisible = false);
      }
    });
  }

  @override
  void dispose() {
    _splashTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isSplashVisible) {
      return Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFFFFFFF), Color(0xFFF0F4FF)],
            ),
          ),
          child: SafeArea(
            child: Stack(
              children: [
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ScaleTransition(
                        scale: _animation,
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF2563EB).withOpacity(0.15),
                                blurRadius: 30,
                                spreadRadius: 5,
                              )
                            ],
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              'lib/assets/logo.png',
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        "Parkly",
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF1E293B),
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 60),
                      const SizedBox(
                        width: 40,
                        height: 40,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        LanguageService().translate('loading_data'),
                        style: TextStyle(
                          color: Colors.blueGrey[400],
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 20.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "by",
                          style: TextStyle(
                            color: Colors.blueGrey[300],
                            fontSize: 10,
                            letterSpacing: 1,
                          ),
                        ),
                        const Text(
                          "HEXACORE",
                          style: TextStyle(
                            color: Color(0xFF1E293B),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final AuthService auth = AuthService();
    return StreamBuilder<User?>(
      stream: auth.userStatus,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          // Utilizatorul s-a logat
          final notifService = NotificationService();
          notifService.refreshInstanceToken();
          notifService.startFirestoreNotificationListener(); // Pornim ascultarea notificărilor Firestore
          notifService.startReportDecisionWatcher(); // Pornim watcher-ul după login

          return const MainNavigationScreen();
        } else {
          return const LoginScreen();
        }
      },
    );
  }
}
