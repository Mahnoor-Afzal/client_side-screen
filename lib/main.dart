import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
      debugShowCheckedModeBanner: false, // Debug banner removed
      title: 'Smart Legal Assistance',
      theme: ThemeData(
        primaryColor: const Color(0xFF0D47A1),
        useMaterial3: true,
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          if (snapshot.hasData) {
            return const LawyerDashboard();
          }
          return const FinalSplashScreen();
        },
      ),
      routes: {
        '/login': (context) => const LawyerLoginScreen(),
        '/signup': (context) => const SignUpScreen(),
        '/dashboard': (context) => const LawyerDashboard(),
      },
    );
  }
}
