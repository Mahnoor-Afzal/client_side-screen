import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Aapki side-bar files ke mutabiq exact imports
import 'splash_screen.dart';
import 'lawyer_login_screen.dart';
import 'Lawyer_dashboard.dart';
import 'signup_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Smart Legal Assistance',
      theme: ThemeData(
        primaryColor: const Color(0xFF0D47A1),
        useMaterial3: true,
      ),
      // Auto-login Check
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          if (snapshot.hasData) {
            return LawyerDashboard();
          }
          return const FinalSplashScreen();
        },
      ),
      // Routes for Navigation
      routes: {
        '/login': (context) => const LawyerLoginScreen(),
        '/signup': (context) => const SignUpScreen(), // 'S' capital karke dekhen
        '/dashboard': (context) => LawyerDashboard(),
      },
    );
  }
}