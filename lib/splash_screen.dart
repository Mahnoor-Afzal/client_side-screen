import 'package:flutter/material.dart';

class FinalSplashScreen extends StatelessWidget {
  const FinalSplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF0F172A), // Dark navy background
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // --- LOGO SECTION ---
            Icon(
              Icons.gavel_rounded,
              size: 80,
              color: Colors.amber,
            ),
            SizedBox(height: 30),

            // --- APP NAME ---
            Text(
              "SMART LEGAL ASSISTANT",
              style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            SizedBox(height: 10),

            Text(
              "Your Digital Legal Partner",
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontStyle: FontStyle.italic,
              ),
            ),

            SizedBox(height: 60),

            // --- LOADING INDICATOR ---
            CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
            ),
          ],
        ),
      ),
    );
  }
}
