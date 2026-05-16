import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'lawyer_profile_screen.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;

  final RegExp _passwordRegex = RegExp(r'^(?=.*[A-Z])(?=.*[!@#$&*])(?=.*[0-9]).{8,}$');

  void _handleSignUp() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        // Check if user already exists in Firestore to prevent overwriting 'isVerified'
        DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('lawyers').doc(userCredential.user!.uid).get();

        if (!userDoc.exists) {
          await FirebaseFirestore.instance.collection('lawyers').doc(userCredential.user!.uid).set({
            'fullName': _nameController.text.trim(),
            'email': _emailController.text.trim(),
            'isVerified': false, // Default for new users
            'role': 'lawyer',
            'registrationStatus': 'incomplete',
            'createdAt': FieldValue.serverTimestamp(),
          });
        }

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const LawyerProfileScreen()),
          );
        }
      } on FirebaseAuthException catch (e) {
        String msg = e.code == 'email-already-in-use' ? "This email is already registered." : (e.message ?? "Error");
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.redAccent));
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color navyBlue = Color(0xFF101D3D);
    const Color goldColor = Color(0xFFC5A358);

    return Scaffold(
      backgroundColor: navyBlue,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text("Create Account", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 20),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                const SizedBox(height: 20),
                const Text(
                  "Join as a Lawyer",
                  style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 40),
                
                _buildTextField("Full Name", _nameController, Icons.person_outline, goldColor, 
                    (val) => (val == null || val.isEmpty) ? 'Name Required' : null),
                
                const SizedBox(height: 20),
                _buildTextField("Email Address", _emailController, Icons.email_outlined, goldColor, 
                    (val) => (val == null || !val.contains('@')) ? 'Invalid Email' : null),

                const SizedBox(height: 20),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  validator: (val) {
                    if (val == null || val.isEmpty) return 'Password Required';
                    if (!_passwordRegex.hasMatch(val)) return 'Include Upper, Number & Special Char';
                    return null;
                  },
                  decoration: InputDecoration(
                    labelText: "Password",
                    labelStyle: const TextStyle(color: Colors.white54, fontSize: 12),
                    prefixIcon: const Icon(Icons.lock_outline, color: goldColor, size: 20),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: Colors.white38, size: 18),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),

                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleSignUp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: goldColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isLoading 
                      ? const CircularProgressIndicator(color: navyBlue)
                      : const Text("CREATE ACCOUNT", style: TextStyle(color: navyBlue, fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, IconData icon, Color gold, String? Function(String?) validator) {
    return TextFormField(
      controller: controller,
      validator: validator,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54, fontSize: 12),
        prefixIcon: Icon(icon, color: gold, size: 20),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
      ),
    );
  }
}
