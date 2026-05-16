import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'login_screen.dart';
import 'client_dashboard.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

void main() async {
  // 1. Flutter engine setup
  WidgetsFlutterBinding.ensureInitialized();
  
  print("APP_LOG: Flutter Initialized");

  try {
    // 2. Firebase initialize
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print("APP_LOG: Firebase Initialized Success");

    // 3. Messaging setup
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  } catch (e) {
    print("APP_LOG: Firebase Init Error: $e");
  }

  runApp(const LegalAssistantApp());
}

class LegalAssistantApp extends StatelessWidget {
  const LegalAssistantApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Smart Legal Assistant',
      theme: ThemeData(
        primaryColor: const Color(0xFF001F3F),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF001F3F)),
        useMaterial3: true,
      ),
      // Auth check with error handling
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              backgroundColor: Colors.white,
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Color(0xFF001F3F)),
                    SizedBox(height: 10),
                    Text("Loading Security...", style: TextStyle(color: Color(0xFF001F3F))),
                  ],
                ),
              ),
            );
          }
          
          if (snapshot.hasError) {
            return Scaffold(
              body: Center(child: Text("Connection Error: ${snapshot.error}")),
            );
          }

          if (snapshot.hasData && snapshot.data != null) {
            return const DashboardScreen();
          }

          return const LoginScreen();
        },
      ),
    );
  }
}
