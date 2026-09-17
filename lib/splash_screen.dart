import 'package:flutter/material.dart';

class FinalSplashScreen extends StatelessWidget {
  const FinalSplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Get screen dimensions for responsiveness
    final size = MediaQuery.of(context).size;
    final width = size.width;
    final height = size.height;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Dark navy background
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // --- LOGO SECTION ---
                Icon(
                  Icons.gavel_rounded,
                  size: width * 0.25, // Logo size relative to screen width
                  color: Colors.amber,
                ),
                SizedBox(height: height * 0.04),

                // --- APP NAME ---
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    "SMART LEGAL ASSISTANT",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: width * 0.065, // Responsive font size
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                SizedBox(height: height * 0.015),

                Text(
                  "Your Digital Legal Partner",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: width * 0.035, // Responsive font size
                    fontStyle: FontStyle.italic,
                  ),
                ),

                SizedBox(height: height * 0.08),

                // --- LOADING INDICATOR ---
                const CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
