import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'blocked_screen.dart';

class AuthWrapper extends StatelessWidget {
  final Widget dashboard;
  final Widget loginScreen;

  const AuthWrapper({
    super.key,
    required this.dashboard,
    required this.loginScreen,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final user = authSnapshot.data;

        if (user == null) {
          return loginScreen;
        }

        // Check if user is blocked in Firestore
        return FutureBuilder<DocumentSnapshot?>(
          future: _getUserDoc(user.uid),
          builder: (context, docSnapshot) {
            if (docSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }

            if (!docSnapshot.hasData || docSnapshot.data == null || !docSnapshot.data!.exists) {
              // User doc not found, maybe admin or deleted
              return dashboard;
            }

            final data = docSnapshot.data!.data() as Map<String, dynamic>;
            final bool isBlocked = data['isBlocked'] == true || data['status'] == 'Blocked';

            if (isBlocked) {
              return const BlockedScreen();
            }

            return dashboard;
          },
        );
      },
    );
  }

  Future<DocumentSnapshot?> _getUserDoc(String uid) async {
    // Check in 'users' collection (Clients)
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (userDoc.exists) return userDoc;

    // Check in 'verified_lawyers' collection
    final verifiedLawyerDoc = await FirebaseFirestore.instance.collection('verified_lawyers').doc(uid).get();
    if (verifiedLawyerDoc.exists) return verifiedLawyerDoc;

    // Check in 'lawyers' collection (Pending)
    final lawyerDoc = await FirebaseFirestore.instance.collection('lawyers').doc(uid).get();
    if (lawyerDoc.exists) return lawyerDoc;

    return null;
  }
}
