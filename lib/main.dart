<<<<<<< HEAD
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'firebase_options.dart';
import 'client_login_screen.dart';
import 'client_dashboard.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

const AndroidNotificationChannel channel = AndroidNotificationChannel(
  'high_importance_channel', // id
  'High Importance Notifications', // title
  description: 'This channel is used for important notifications.', // description
  importance: Importance.max,
);

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  // Background mein notification manually show karne ki zaroorat nahi agar payload mein 'notification' object hai, 
  // lekin data-only messages ke liye ye zaroori hai.
  if (message.data.isNotEmpty && message.notification == null) {
     // Handle data message
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

    // Messaging setup
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Create Channel
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // Request permissions for Android 13+
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    // Set foreground notification options
    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // Initialize Local Notifications
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );
    
    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Notification click handled in Dashboard
      },
    );

    // Persistence Settings
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );

  } catch (e) {
    debugPrint("Firebase Init Error: $e");
  }

  runApp(const LegalAssistantApp());
}

class LegalAssistantApp extends StatelessWidget {
  const LegalAssistantApp({super.key});
=======
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
>>>>>>> origin/lawyer-side-branch

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
<<<<<<< HEAD
      title: 'Smart Legal Assistant',
      theme: ThemeData(
        primaryColor: const Color(0xFF001F3F),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF001F3F),
          primary: const Color(0xFF001F3F),
          secondary: const Color(0xFFD4AF37),
        ),
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
=======
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
>>>>>>> origin/lawyer-side-branch
