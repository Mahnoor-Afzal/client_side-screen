import 'package:flutter/material.dart';
import 'login_selection_screen.dart';
import 'dart:async';

class FinalSplashScreen extends StatefulWidget {
  const FinalSplashScreen({super.key});

  @override
  State<FinalSplashScreen> createState() => _FinalSplashScreenState();
}

class _FinalSplashScreenState extends State<FinalSplashScreen> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(seconds: 6), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => LoginSelectionScreen()),
      );
    });
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Wahi dark navy background
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // --- LOGO SECTION ---
            Container(
              height: 120,
              width: 120,
              decoration: BoxDecoration(
                color: Colors.white, // Logo k niche white circle
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Center(
                // Jab aapke paas image ho, toh Icon ki jagah niche wali line use karein:
                // child: Image.asset('assets/your_logo.png', width: 70),
                child: Icon(
                  Icons.gavel_rounded, // Professional Legal Icon
                  size: 60,
                  color: Color(0xFF0F172A), // Dark color for contrast
                ),
              ),
            ),
            const SizedBox(height: 30),

            // --- APP NAME ---
            const Text(
              "SMART LEGAL ASSISTANT",
              style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 10),

            // --- OPTIONAL TAGLINE ---
            const Text(
              "Your Digital Legal Partner",
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontStyle: FontStyle.italic,
              ),
            ),

            const SizedBox(height: 60),

            // --- LOADING INDICATOR ---
            const CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.amber), // Gold color
            ),
          ],
        ),
      ),
    );
  }
}