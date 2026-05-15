import 'package:flutter/material.dart';
import 'auth_service.dart';
import 'admin_dashboard.dart';

class AdminLogin extends StatefulWidget {
  const AdminLogin({super.key});

  @override
  State<AdminLogin> createState() => _AdminLoginState();
}

class _AdminLoginState extends State<AdminLogin> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isPasswordVisible = false;

  final AuthService _auth = AuthService();

  Future<void> _handleLogin() async {
    String email = _emailController.text.trim();
    String password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showMsg("Please enter email and password");
      return;
    }

    String? result = await _auth.loginAdmin(email, password);

    if (result == "success") {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const AdminDashboard()),
      );
    } else {
      _showMsg(result ?? "Login Failed", isError: true);
    }
  }

  // Temporary function to create admin collection
  Future<void> _handleCreateAdmin() async {
    String email = _emailController.text.trim();
    String password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showMsg("Enter email/pass above to create admin");
      return;
    }

    String result = await _auth.setupAdminCollection(email, password);
    _showMsg(result);
  }

  void _showMsg(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color navyColor = Color(0xFF111827);
    const Color goldColor = Color(0xFFC5A35D);
    const Color fieldColor = Color(0xFF1F2937);

    return Scaffold(
      backgroundColor: navyColor,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: goldColor, width: 2),
                ),
                child: const Icon(Icons.gavel, size: 50, color: goldColor),
              ),
              const SizedBox(height: 20),
              const Text(
                "Admin Login",
                style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 50),
              _customInput("Email Address", Icons.email_outlined, _emailController, fieldColor, goldColor),
              const SizedBox(height: 25),
              _customPasswordInput("Password", _passwordController, fieldColor, goldColor),
              const SizedBox(height: 50),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: goldColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: _handleLogin,
                  child: const Text("LOGIN", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 20),
              // TEMPORARY BUTTON TO CREATE COLLECTION
              TextButton(
                onPressed: _handleCreateAdmin,
                child: const Text("First time? Click here to create Admin Collection", 
                  style: TextStyle(color: Colors.white54, fontSize: 12)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _customInput(String label, IconData icon, TextEditingController controller, Color bg, Color accent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 14)),
        const SizedBox(height: 10),
        TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: accent, size: 20),
            filled: true,
            fillColor: bg,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }

  Widget _customPasswordInput(String label, TextEditingController controller, Color bg, Color accent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 14)),
        const SizedBox(height: 10),
        TextField(
          controller: controller,
          obscureText: !_isPasswordVisible,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            prefixIcon: Icon(Icons.lock_outline, color: accent, size: 20),
            suffixIcon: IconButton(
              icon: Icon(_isPasswordVisible ? Icons.visibility : Icons.visibility_off, color: Colors.white24, size: 20),
              onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
            ),
            filled: true,
            fillColor: bg,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }
}
