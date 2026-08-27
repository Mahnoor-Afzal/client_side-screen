import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Necessary Imports
import 'Lawyer_dashboard.dart';
import 'signup_screen.dart';
import 'forgot_password.dart';
import 'rejected_lawyer_screen.dart';

class LawyerLoginScreen extends StatefulWidget {
  const LawyerLoginScreen({super.key});

  @override
  State<LawyerLoginScreen> createState() => _LawyerLoginScreenState();
}

class _LawyerLoginScreenState extends State<LawyerLoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isObscure = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Helper method to show error messages easily
  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color navyBlue = Color(0xFF101D3D);
    const Color goldColor = Color(0xFFC5A358);

    return Scaffold(
      backgroundColor: navyBlue,
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 100),

              // 1. App Logo
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white10, width: 2),
                ),
                child: Image.asset(
                  'assets/logo.png',
                  height: 100,
                  errorBuilder: (context, error, stackTrace) =>
                  const Icon(Icons.gavel_rounded, color: goldColor, size: 70),
                ),
              ),

              const SizedBox(height: 60),

              // 2. Email Field
              const Align(
                alignment: Alignment.centerLeft,
                child: Text("Email Address", style: TextStyle(color: Colors.white70)),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _emailController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: "Enter your email",
                  hintStyle: const TextStyle(color: Colors.white24, fontSize: 14),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  prefixIcon: const Icon(Icons.email_outlined, color: goldColor),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // 3. Password Field
              const Align(
                alignment: Alignment.centerLeft,
                child: Text("Password", style: TextStyle(color: Colors.white70)),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _passwordController,
                obscureText: _isObscure,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: "Enter your password",
                  hintStyle: const TextStyle(color: Colors.white24, fontSize: 14),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  prefixIcon: const Icon(Icons.lock_outline, color: goldColor),
                  suffixIcon: IconButton(
                    icon: Icon(_isObscure ? Icons.visibility_off : Icons.visibility, color: Colors.white38),
                    onPressed: () => setState(() => _isObscure = !_isObscure),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),

              const SizedBox(height: 40),

              // 4. LOGIN Button
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isLoading
                      ? null
                      : () async {
                    final email = _emailController.text.trim();
                    final password = _passwordController.text.trim();

                    if (email.isEmpty || password.isEmpty) {
                      _showErrorSnackBar("Email and password are required.");
                      return;
                    }

                    setState(() => _isLoading = true);

                    try {
                      // 1. Firebase Authentication Sign-in
                      UserCredential userCredential = await FirebaseAuth.instance
                          .signInWithEmailAndPassword(email: email, password: password);

                      String uid = userCredential.user!.uid;

                      // 2. Check in 'verified_lawyers' collection
                      DocumentSnapshot lawyerDoc = await FirebaseFirestore.instance
                          .collection('verified_lawyers')
                          .doc(uid)
                          .get();

                      if (!lawyerDoc.exists) {
                        // Secondary check using email if doc ID doesn't match
                        var emailQuery = await FirebaseFirestore.instance
                            .collection('verified_lawyers')
                            .where('email', isEqualTo: email)
                            .limit(1)
                            .get();

                        if (emailQuery.docs.isNotEmpty) {
                          lawyerDoc = emailQuery.docs.first;
                        }
                      }

                      // If lawyer data not found in verified_lawyers, check in 'lawyers' collection (could be pending or rejected)
                      if (!lawyerDoc.exists) {
                        lawyerDoc = await FirebaseFirestore.instance
                            .collection('lawyers')
                            .doc(uid)
                            .get();

                        if (!lawyerDoc.exists) {
                          var emailQuery = await FirebaseFirestore.instance
                              .collection('lawyers')
                              .where('email', isEqualTo: email)
                              .limit(1)
                              .get();

                          if (emailQuery.docs.isNotEmpty) {
                            lawyerDoc = emailQuery.docs.first;
                          }
                        }
                      }

                      // If lawyer data not found anywhere
                      if (!lawyerDoc.exists) {
                        await FirebaseAuth.instance.signOut();
                        _showErrorSnackBar("No registered lawyer account found. Please sign up first.");
                        return;
                      }

                      // 3. Admin Verification Status Check
                      var data = lawyerDoc.data() as Map<String, dynamic>?;

                      String status = (data?['status'] ?? data?['verificationStatus'] ?? '').toString().toLowerCase();
                      bool isRejected = status == 'rejected' || data?['isRejected'] == true;

                      // SCENARIO A: Rejected
                      if (isRejected) {
                        String reason = data?['rejectionReason'] ?? data?['reason'] ?? 'No specific reason provided by admin.';
                        await FirebaseAuth.instance.signOut();

                        if (mounted) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => RejectedLawyerScreen(rejectionReason: reason),
                            ),
                          );
                        }
                        return;
                      }

                      bool isApproved = data?['isApproved'] == true ||
                          status == 'approved' ||
                          status == 'active' ||
                          (data?['isVerified'] ?? false) == true;

                      // SCENARIO B: Pending Approval
                      if (!isApproved) {
                        await FirebaseAuth.instance.signOut();
                        _showErrorSnackBar("Your account is pending admin approval. Please wait for verification.");
                        return;
                      }

                      // SCENARIO C: Successful Login & Navigation for Verified Lawyers
                      if (mounted) {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (context) => const LawyerDashboard()),
                        );
                      }
                    } on FirebaseAuthException catch (e) {
                      String message = "Login Failed";
                      if (e.code == 'user-not-found' || e.code == 'invalid-credential') {
                        message = "Incorrect email or password, or account doesn't exist.";
                      } else if (e.code == 'wrong-password') {
                        message = "Incorrect password entered.";
                      } else if (e.code == 'invalid-email') {
                        message = "Email format is invalid.";
                      } else {
                        message = e.message ?? "Login Failed";
                      }
                      _showErrorSnackBar(message);
                    } catch (e) {
                      _showErrorSnackBar("An unexpected error occurred: $e");
                    } finally {
                      if (mounted) setState(() => _isLoading = false);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: goldColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: navyBlue)
                      : const Text(
                    "LOGIN",
                    style: TextStyle(color: navyBlue, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),

              const SizedBox(height: 10),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ForgotPasswordScreen()),
                  );
                },
                child: const Text(
                  "Forgot Password?",
                  style: TextStyle(color: Colors.white54, fontSize: 14),
                ),
              ),

              const SizedBox(height: 40),

              // 5. SIGN UP Link
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Don't have an account? ", style: TextStyle(color: Colors.white54)),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const SignUpScreen()),
                      );
                    },
                    child: const Text(
                      "Sign Up",
                      style: TextStyle(color: goldColor, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}