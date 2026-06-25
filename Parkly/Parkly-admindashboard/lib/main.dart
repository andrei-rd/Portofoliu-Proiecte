import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:parkly/admin/admin_layout.dart';
import 'package:parkly/admin/admin_service.dart';
import 'firebase_options.dart';

void main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AdminService()),
        ],
        child: const MyApp(),
      ),
    );
  } catch (e) {
    debugPrint("Eroare fatală la pornire: $e");
    runApp(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text(
                "Eroare la inițializarea aplicației:\n$e\n\nVerifică configurația Firebase și conexiunea la internet.",
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Parkly Admin',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2563EB)),
        useMaterial3: true,
      ),
      home: const AdminLayout(),
    );
  }
}
