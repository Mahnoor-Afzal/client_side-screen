import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'client_dashboard.dart';
import 'client_signup.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // Check if the user is blocked in either collection
      DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).get();
      
      if (!userDoc.exists) {
        userDoc = await FirebaseFirestore.instance.collection('verified_lawyers').doc(userCredential.user!.uid).get();
      }

      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;
        bool isBlocked = data['isBlocked'] == true || data['status'] == 'Blocked' || data['status'] == 'blocked';
        
        if (isBlocked) {
          String reason = data['blockReason'] ?? "Your account has been suspended by the administrator.";
          await FirebaseAuth.instance.signOut();
          if (!mounted) return;
          _showBlockedDialog(reason);
          return;
        }
      }

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const DashboardScreen()),
      );
    } on FirebaseAuthException catch (e) {
      String message = "";
      if (e.code == 'user-not-found') {
        message = "No user found for that email.";
      } else if (e.code == 'wrong-password') {
        message = "Wrong password provided.";
      } else if (e.code == 'invalid-credential') {
        message = "Invalid email or password. Please try again.";
      } else {
        message = e.message ?? "An error occurred during login.";
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showBlockedDialog(String reason) {
    showDialog(
      context: context,
      barrierDismissible: true, // Backup: user can click outside to close
      builder: (BuildContext dialogContext) => AlertDialog(
        backgroundColor: fieldNavy,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.block, color: Colors.redAccent),
            SizedBox(width: 10),
            Text("Account Blocked", style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Your account has been suspended by the admin.",
              style: TextStyle(color: textGrey, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 15),
            const Text("Reason:", style: TextStyle(color: accentGold, fontSize: 14)),
            const SizedBox(height: 5),
            Text(
              reason,
              style: const TextStyle(color: Colors.white70, fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(dialogContext, rootNavigator: true).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentGold,
                  foregroundColor: backgroundNavy,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text(
                  "OK", 
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static const Color backgroundNavy = Color(0xFF0A0E1A);
  static const Color fieldNavy = Color(0xFF151B29);
  static const Color accentGold = Color(0xFFD4AF37);
  static const Color textGrey = Color(0xFFB0B0B0);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundNavy,
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 60),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 50),
                const Text(
                  "Welcome Back",
                  style: TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                const Text(
                  "Login to your legal assistant account",
                  style: TextStyle(color: textGrey, fontSize: 16),
                ),
                const SizedBox(height: 50),

                _buildCustomField(
                  controller: _emailController,
                  label: "Email Address",
                  icon: Icons.email_outlined,
                  hint: "ali@gmail.com",
                  validator: (val) => (val == null || !val.contains('@')) ? "Enter a valid email" : null,
                ),
                const SizedBox(height: 25),

                _buildCustomField(
                  controller: _passwordController,
                  label: "Password",
                  icon: Icons.lock_outline,
                  isPassword: true,
                  obscureText: _obscurePassword,
                  hint: "Enter your password",
                  onToggleVisibility: () => setState(() => _obscurePassword = !_obscurePassword),
                  validator: (val) => (val == null || val.isEmpty) ? "Enter your password" : null,
                ),

                const SizedBox(height: 15),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {}, // TODO: Forgot Password
                    child: const Text("Forgot Password?", style: TextStyle(color: accentGold)),
                  ),
                ),

                const SizedBox(height: 30),

                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentGold,
                      foregroundColor: backgroundNavy,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: backgroundNavy)
                        : const Text("LOGIN", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),

                const SizedBox(height: 30),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Don't have an account? ", style: TextStyle(color: Colors.white)),
                    GestureDetector(
                      onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const ClientSignupScreen())),
                      child: const Text("Sign Up", style: TextStyle(color: accentGold, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    bool obscureText = false,
    VoidCallback? onToggleVisibility,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: textGrey, fontSize: 14)),
        const SizedBox(height: 10),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          validator: validator,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.2)),
            prefixIcon: Icon(icon, color: accentGold, size: 22),
            suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(obscureText ? Icons.visibility_off : Icons.visibility, color: textGrey),
                    onPressed: onToggleVisibility,
                  )
                : null,
            filled: true,
            fillColor: fieldNavy,
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: accentGold)),
          ),
        ),
      ],
    );
  }
}
