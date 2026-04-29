import 'package:flutter/material.dart';
import 'package:flutter/material.dart';
import 'lawyer_login_screen.dart'; // Is line ko add karein (file ka sahi naam likhein)
class LoginSelectionScreen extends StatelessWidget {
  const LoginSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Consistent Dark Navy background used in the Splash Screen
    const Color primaryDark = Color(0xFF0F172A);

    return Scaffold(
      backgroundColor: primaryDark,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // --- 1. PREMIUM CIRCULAR LOGO (Same as Splash Screen) ---
              Container(
                height: 100,
                width: 100,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.gavel_rounded, // Professional Legal Icon
                    size: 50,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              const SizedBox(height: 40),

              // --- 2. MAIN HEADING ---
              const Text(
                "Sign up or Login as",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 15),

              // --- 3. SUB-TEXT ---
              Text(
                "Select your role to continue. The process will differ based on your selection.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 50),

              // --- 4. LAWYER BUTTON ---
              _buildRoleButton(
                context: context,
                label: "Lawyer", // Ye button ka text hai
                icon: Icons.gavel_rounded,
                onTap: () {
                  // ---- YAHAN PATH DENA HAI ----
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) =>  LawyerLoginScreen()),
                  );
                  // ----------------------------
                },
              ),

              const SizedBox(height: 20),

              // Visual Divider with "OR"
              Row(
                children: [
                  const Expanded(child: Divider(color: Colors.white24)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 15),
                    child: Text(
                      "OR",
                      style: TextStyle(color: Colors.white.withOpacity(0.4)),
                    ),
                  ),
                  const Expanded(child: Divider(color: Colors.white24)),
                ],
              ),

              const SizedBox(height: 20),

              // --- 5. CLIENT BUTTON ---
              _buildRoleButton(
                context: context,
                label: "Client",
                icon: Icons.person_search_rounded,
                onTap: () {
                  // Navigation for Client Login will go here
                  print("Client selection clicked");
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Custom Reusable Button Widget
  Widget _buildRoleButton({
    required BuildContext context,
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1E293B), // Navy blue button color
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
            side: const BorderSide(color: Colors.white10),
          ),
        ),
        onPressed: onTap,
        icon: Icon(icon, size: 22, color: Colors.amber), // Gold icon color for premium look
        label: Text(
          label,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}