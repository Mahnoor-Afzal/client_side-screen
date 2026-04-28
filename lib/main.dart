import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'client_signup.dart';

void main() async {
  // Firebase ko initialize kiya
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const LegalAssistantApp());
}

class LegalAssistantApp extends StatelessWidget {
  const LegalAssistantApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Colors for the entire app theme
    const Color navyBlue = Color(0xFF001F3F);
    const Color gold = Color(0xFFD4AF37);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Smart Legal Assistant',

      // Global Theme Settings
      theme: ThemeData(
        primaryColor: navyBlue,
        colorScheme: ColorScheme.fromSeed(
          seedColor: navyBlue,
          primary: navyBlue,
          secondary: gold,
        ),
        useMaterial3: true,
      ),

      // App starts from the Signup Screen
      home: const ClientSignupScreen(),
    );
  }
}