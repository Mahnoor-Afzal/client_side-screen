import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:async';
import 'firebase_options.dart';
import 'client_login_screen.dart';
import 'client_dashboard.dart';
import 'splash_screen.dart';
import 'lawyer_login_screen.dart';
import 'Lawyer_dashboard.dart';
import 'signup_screen.dart';
import 'login_selection_screen.dart';
import 'lawyer_pending_screen.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

const AndroidNotificationChannel channel = AndroidNotificationChannel(
  'high_importance_channel',
  'High Importance Notifications',
  description: 'This channel is used for important notifications.',
  importance: Importance.max,
);

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  if (message.data.isNotEmpty && message.notification == null) {
     // Handle data message if needed
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

    // Messaging setup
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Create Channel for local notifications
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

    // Firestore Persistence Settings
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

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
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
      home: const AuthWrapper(),
      routes: {
        '/login_selection': (context) => const LoginSelectionScreen(),
        '/client_login': (context) => const LoginScreen(),
        '/lawyer_login': (context) => const LawyerLoginScreen(),
        '/lawyer_signup': (context) => const SignUpScreen(),
        '/client_dashboard': (context) => const DashboardScreen(),
        '/lawyer_dashboard': (context) => const LawyerDashboard(),
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
    // Show splash screen until timer finishes
    if (!_timerDone) return const FinalSplashScreen();

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.active) {
          final user = snapshot.data;
          if (user == null) {
            return const LoginSelectionScreen();
          }
          
          // Determine user role and navigate to appropriate dashboard
          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
            builder: (context, clientSnapshot) {
              if (clientSnapshot.connectionState == ConnectionState.waiting) {
                return const FinalSplashScreen();
              }
              
              if (clientSnapshot.hasData && clientSnapshot.data!.exists) {
                return const DashboardScreen();
              }
              
              // If not a client, check if it's a lawyer
              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection('verified_lawyers').doc(user.uid).get(),
                builder: (context, lawyerSnapshot) {
                  if (lawyerSnapshot.connectionState == ConnectionState.waiting) {
                    return const FinalSplashScreen();
                  }
                  
                  if (lawyerSnapshot.hasData && lawyerSnapshot.data!.exists) {
                    return const LawyerDashboard();
                  }

                  // Check pending/rejected lawyers in 'lawyers' collection
                  return FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance.collection('lawyers').doc(user.uid).get(),
                    builder: (context, pendingSnapshot) {
                      if (pendingSnapshot.connectionState == ConnectionState.waiting) {
                        return const FinalSplashScreen();
                      }
                      if (pendingSnapshot.hasData && pendingSnapshot.data!.exists) {
                        var lawyerData = pendingSnapshot.data!.data() as Map<String, dynamic>? ?? {};
                        String paymentStatus = lawyerData['paymentStatus'] ?? 'Unpaid';
                        bool isApproved = lawyerData['isApproved'] == true;

                        // Agar payment submitted hai aur admin ne approve nahi kiya to pending screen dikhayein
                        if (paymentStatus == 'Submitted' && !isApproved) {
                          return const LawyerPendingScreen();
                        }

                        return const LawyerDashboard();
                      }
                      
                      // Fallback: If auth exists but no record in Firestore, go to selection
                      return const LoginSelectionScreen();
                    },
                  );
                },
              );
            },
          );
        }
        return const FinalSplashScreen();
      },
    );
  }
}
