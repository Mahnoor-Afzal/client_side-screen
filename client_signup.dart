import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class ClientSignUpScreen extends StatefulWidget {
  const ClientSignUpScreen({super.key});

  @override
  State<ClientSignUpScreen> createState() => _ClientSignUpScreenState();
}

class _ClientSignUpScreenState extends State<ClientSignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _passController = TextEditingController();
  final TextEditingController _confirmPassController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  File? _image;

  // Design Colors
  static const Color backgroundDark = Color(0xFF0A0E1A);
  static const Color accentGold = Color(0xFFD4AF37);
  static const Color fieldGrey = Color(0xFF1E232E);
  static const Color textGrey = Color(0xFFB0B0B0);

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
    }
  }

  @override
  void dispose() {
    _passController.dispose();
    _confirmPassController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundDark,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                const SizedBox(height: 40),
                const Text(
                  "Create Client Account",
                  style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                const Text(
                  "Fill in your details to get started",
                  style: TextStyle(color: textGrey, fontSize: 14),
                ),
                const SizedBox(height: 30),

                // Profile Image Selection
                GestureDetector(
                  onTap: _pickImage,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: fieldGrey,
                        backgroundImage: _image != null ? FileImage(_image!) : null,
                        child: _image == null
                            ? const Icon(Icons.person_add_alt_1, size: 40, color: textGrey)
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: CircleAvatar(
                          radius: 15,
                          backgroundColor: accentGold,
                          child: const Icon(Icons.edit, size: 14, color: backgroundDark),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),

                // Input Fields
                _customTextField(
                  hint: "Email Address",
                  icon: Icons.email_outlined,
                  validator: (v) => v!.contains('@') ? null : "Invalid email",
                ),
                const SizedBox(height: 15),
                _customTextField(
                  hint: "Contact Number",
                  icon: Icons.phone_android_outlined,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 15),
                _customTextField(
                  hint: "Password",
                  icon: Icons.lock_outline,
                  controller: _passController,
                  isPassword: true,
                  obscure: _obscurePassword,
                  toggle: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
                const SizedBox(height: 15),
                _customTextField(
                  hint: "Confirm Password",
                  icon: Icons.lock_reset_outlined,
                  controller: _confirmPassController,
                  isPassword: true,
                  obscure: _obscureConfirmPassword,
                  toggle: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                  validator: (v) => v == _passController.text ? null : "Passwords don't match",
                ),
                const SizedBox(height: 40),

                // Sign Up Button
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentGold,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        // Action
                      }
                    },
                    child: const Text("Sign Up", style: TextStyle(color: backgroundDark, fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),

                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Already have an account? ", style: TextStyle(color: textGrey)),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Login", style: TextStyle(color: accentGold, fontWeight: FontWeight.bold)),
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

  Widget _customTextField({
    required String hint,
    required IconData icon,
    bool isPassword = false,
    bool obscure = false,
    VoidCallback? toggle,
    TextEditingController? controller,
    String? Function(String?)? validator,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      validator: validator,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: textGrey, fontSize: 14),
        prefixIcon: Icon(icon, color: accentGold, size: 20),
        suffixIcon: isPassword
            ? IconButton(icon: Icon(obscure ? Icons.visibility_off : Icons.visibility, color: textGrey), onPressed: toggle)
            : null,
        filled: true,
        fillColor: fieldGrey,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: accentGold)),
      ),
    );
  }
}