import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';

import 'splash_screen.dart';
import 'lawyer_login_screen.dart';
import 'Lawyer_dashboard.dart';
import 'signup_screen.dart';
import 'login_selection_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyCjcM8IdGw327-i7b96mKvRUKuXBMEM9bU",
        authDomain: "smart-legal-assistant-app.firebaseapp.com",
        projectId: "smart-legal-assistant-app",
        storageBucket: "smart-legal-assistant-app.firebasestorage.app",
        messagingSenderId: "636284975962",
        appId: "1:636284975962:web:047b2a453ebd18d7c75163",
        measurementId: "G-38HTMVEZ14",
      ),
    );
  } else {
    await Firebase.initializeApp();
  }

  // Firestore Offline Persistence Setting
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

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
      home: const AuthWrapper(),
      routes: {
        '/login_selection': (context) => const LoginSelectionScreen(),
        '/login': (context) => const LawyerLoginScreen(),
        '/signup': (context) => const SignUpScreen(),
        '/dashboard': (context) => const LawyerDashboard(),
      },
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _timerDone = false;

  @override
  void initState() {
    super.initState();
    // Splash Screen Timer: 3 seconds
    Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _timerDone = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Jab tak 3 second poore nahi hote, Splash Screen dikhao
    if (!_timerDone) return const FinalSplashScreen();

    // 3 seconds baad Auth State check karein
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.active) {
          final user = snapshot.data;
          if (user != null) {
            // Lawyer logged in hai, seedha Dashboard
            return const LawyerDashboard();
          } else {
            // Logged in nahi hai, Role Selection dikhao
            return const LoginSelectionScreen();
          }
        }
        // Fallback during transition
        return const FinalSplashScreen();
      },
    );
  }
}