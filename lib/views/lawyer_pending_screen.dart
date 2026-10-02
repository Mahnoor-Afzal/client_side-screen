import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_selection_screen.dart';

class LawyerPendingScreen extends StatelessWidget {
  const LawyerPendingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const Color navyBlue = Color(0xFF101D3D);
    const Color goldColor = Color(0xFFC5A358);

    return Scaffold(
      backgroundColor: navyBlue,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Pending / Verification Icon
              Container(
                height: 120,
                width: 120,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  shape: BoxShape.circle,
                  border: Border.all(color: goldColor, width: 2),
                ),
                child: const Center(
                  child: Icon(
                    Icons.hourglass_empty_rounded,
                    size: 60,
                    color: goldColor,
                  ),
                ),
              ),
              const SizedBox(height: 40),

              // Title
              const Text(
                "Verification Pending",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 15),

              // Description
              Text(
                "Your payment proof and license documents have been successfully submitted.\n\nAdmin is reviewing your application. You will be able to access your dashboard as soon as you are verified.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 50),

              // Refresh Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: goldColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    // Simple hack to trigger AuthWrapper to check status again
                    FirebaseAuth.instance.currentUser?.reload();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Checking status...")),
                    );
                  },
                  icon: const Icon(Icons.refresh, color: navyBlue),
                  label: const Text(
                    "CHECK STATUS AGAIN",
                    style: TextStyle(color: navyBlue, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Logout Button
              TextButton.icon(
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                  if (context.mounted) {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (context) => const LoginSelectionScreen()),
                      (route) => false,
                    );
                  }
                },
                icon: const Icon(Icons.logout, color: Colors.redAccent),
                label: const Text(
                  "Sign Out / Login as other",
                  style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
