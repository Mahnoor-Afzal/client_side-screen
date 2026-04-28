import 'package:flutter/material.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Controllers for editing
  final TextEditingController _nameController = TextEditingController(text: "Mahnoor");
  final TextEditingController _phoneController = TextEditingController(text: "+92 300 1234567");
  final TextEditingController _idController = TextEditingController(text: "42101-1234567-1");
  final TextEditingController _locationController = TextEditingController(text: "Islamabad, Pakistan");

  static const Color backgroundNavy = Color(0xFF0A0E1A);
  static const Color cardNavy = Color(0xFF151B29);
  static const Color accentGold = Color(0xFFD4AF37);
  static const Color textGrey = Color(0xFFB0B0B0);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundNavy,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text("MY PROFILE", style: TextStyle(color: Colors.white, fontSize: 16, letterSpacing: 1.5)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: accentGold),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(25),
        child: Column(
          children: [
            // --- Profile Picture Section ---
            Center(
              child: Stack(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: accentGold, shape: BoxShape.circle),
                    child: const CircleAvatar(
                      radius: 60,
                      backgroundColor: cardNavy,
                      child: Icon(Icons.person, size: 60, color: Colors.white),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(color: accentGold, shape: BoxShape.circle),
                      child: const Icon(Icons.edit, color: backgroundNavy, size: 20),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),

            // --- Input Fields ---
            _buildProfileField("Full Name", _nameController, Icons.person_outline),
            const SizedBox(height: 20),
            _buildProfileField("Phone Number", _phoneController, Icons.phone_outlined),
            const SizedBox(height: 20),
            _buildProfileField("ID Number (CNIC/Passport)", _idController, Icons.badge_outlined),
            const SizedBox(height: 20),
            _buildProfileField("Location", _locationController, Icons.location_on_outlined),

            const SizedBox(height: 50),

            // --- Action Buttons ---
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: () {
                  // Save logic yahan aayegi
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Profile Updated Successfully!")),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentGold,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                child: const Text("SAVE CHANGES", style: TextStyle(color: backgroundNavy, fontWeight: FontWeight.bold)),
              ),
            ),

            const SizedBox(height: 20),

            // Logout Option
            TextButton.icon(
              onPressed: () {
                // Logout logic
                Navigator.popUntil(context, (route) => route.isFirst);
              },
              icon: const Icon(Icons.logout, color: Colors.redAccent),
              label: const Text("Logout", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  // Custom Editable Field Helper
  Widget _buildProfileField(String label, TextEditingController controller, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: textGrey, fontSize: 13)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: accentGold, size: 22),
            filled: true,
            fillColor: cardNavy,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: const BorderSide(color: accentGold, width: 1),
            ),
          ),
        ),
      ],
    );
  }
}