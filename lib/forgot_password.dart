import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Theme Colors
  final Color navyBlue = const Color(0xFF101D3D);
  final Color goldColor = const Color(0xFFC5A358);

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _resetPassword() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        await FirebaseAuth.instance.sendPasswordResetEmail(
          email: _emailController.text.trim(),
        );
        if (mounted) {
          _showSuccessDialog();
        }
      } on FirebaseAuthException catch (e) {
        String message = "An error occurred";
        if (e.code == 'user-not-found') {
          message = "No user found with this email.";
        } else if (e.code == 'invalid-email') {
          message = "The email address is badly formatted.";
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.redAccent),
        );
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: navyBlue,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text("Email Sent", style: TextStyle(color: goldColor, fontWeight: FontWeight.bold)),
        content: const Text(
          "A password reset link has been sent to your email. Please check your inbox.",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Go back to login
            },
            child: Text("OK", style: TextStyle(color: goldColor)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: navyBlue,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              // Icon
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.05),
                ),
                child: Icon(Icons.lock_reset_rounded, size: 80, color: goldColor),
              ),
              const SizedBox(height: 30),
              const Text(
                "Forgot Password?",
                style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 15),
              const Text(
                "Enter your registered email address below to receive password reset instructions.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 15),
              ),
              const SizedBox(height: 40),
              
              // Email Field
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: Colors.white),
                validator: (value) {
                  if (value == null || value.isEmpty) return "Email is required";
                  if (!value.contains('@')) return "Enter a valid email with @";
                  return null;
                },
                decoration: InputDecoration(
                  labelText: "Email Address",
                  labelStyle: const TextStyle(color: Colors.white54),
                  prefixIcon: Icon(Icons.email_outlined, color: goldColor),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: goldColor.withOpacity(0.5)),
                  ),
                ),
              ),
              const SizedBox(height: 50),

              // Reset Button
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _resetPassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: goldColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? CircularProgressIndicator(color: navyBlue)
                      : Text(
                          "SEND RESET LINK",
                          style: TextStyle(
                            color: navyBlue,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
