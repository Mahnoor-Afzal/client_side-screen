import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Login function
  Future<String?> loginAdmin(String email, String password) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      // Check if user exists in 'admins' collection
      DocumentSnapshot adminDoc = await _db
          .collection('admins')
          .doc(userCredential.user!.uid)
          .get();

      if (adminDoc.exists) {
        return "success";
      } else {
        await _auth.signOut();
        return "Access Denied: You are not an Admin.";
      }
    } on FirebaseAuthException catch (e) {
      return e.message;
    } catch (e) {
      return "Error: $e";
    }
  }

  // Collection banane ka function
  Future<String> setupAdminCollection(String email, String password) async {
    try {
      // 1. Pehle Admin account create karein Auth mein
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      // 2. Phir Firestore mein 'admins' collection mein entry karein
      await _db.collection('admins').doc(userCredential.user!.uid).set({
        'name': 'System Admin',
        'email': email.trim(),
        'role': 'admin',
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
      });

      return "Admin created successfully in Firestore!";
    } catch (e) {
      return "Error creating admin: $e";
    }
  }
}
