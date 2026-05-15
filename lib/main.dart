import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'admin_login.dart';
import 'admin_dashboard.dart';
import 'user_management.dart';
import 'verify_lawyers.dart';
import 'verified_lawyers.dart';
import 'monitor_cases.dart';
import 'manage_complaints.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Smart Legal Assistant',
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFFC7A15E),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const AdminLogin(),
        '/dashboard': (context) => const AdminDashboard(),
        '/user_management': (context) => UserManagement(),
        '/verify_lawyers': (context) => VerifyLawyers(),
        '/verified_lawyers': (context) => const VerifiedLawyers(),
        '/monitor_cases': (context) => const MonitorCases(),
        '/manage_complaints': (context) => const ManageComplaints(),
      },
    );
  }
}
