import 'package:flutter/material.dart';
import 'lawyer_license_screen.dart';

class LawyerProfileScreen extends StatefulWidget {
  const LawyerProfileScreen({super.key});

  @override
  State<LawyerProfileScreen> createState() => _LawyerProfileScreenState();
}

class _LawyerProfileScreenState extends State<LawyerProfileScreen> {
  final _nameController = TextEditingController();
  final _cnicController = TextEditingController();
  final _phoneController = TextEditingController();
  final _areaController = TextEditingController();

  String? selectedProvince;
  String? selectedGender;

  @override
  Widget build(BuildContext context) {
    const Color navyBlue = Color(0xFF101D3D);
    const Color goldColor = Color(0xFFC5A358);

    return Scaffold(
      backgroundColor: navyBlue,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      // Scrollbar add kar diya gaya hai
      body: Scrollbar(
        thumbVisibility: true, // Humesha nazar aaye ga scroll karte hue
        thickness: 6,
        radius: const Radius.circular(10),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Profile Setup",
                  style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                const Text("Enter your personal information", style: TextStyle(color: Colors.white54)),

                const SizedBox(height: 30),

                Center(
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      shape: BoxShape.circle,
                      border: Border.all(color: goldColor, width: 2),
                    ),
                    child: const Icon(Icons.camera_alt_outlined, color: Colors.white38, size: 50),
                  ),
                ),

                const SizedBox(height: 40),

                _buildTextField("Full Name", _nameController, Icons.person_outline),
                const SizedBox(height: 20),
                _buildTextField("CNIC Number", _cnicController, Icons.credit_card),
                const SizedBox(height: 20),
                _buildTextField("Phone Number", _phoneController, Icons.phone_android_outlined, type: TextInputType.phone),
                const SizedBox(height: 20),

                _buildDropdownField("Province", selectedProvince, ["Punjab", "Sindh", "KPK", "Balochistan"], Icons.map_outlined, (value) {
                  setState(() => selectedProvince = value);
                }),
                const SizedBox(height: 20),

                _buildTextField("Area", _areaController, Icons.location_on_outlined),
                const SizedBox(height: 20),

                _buildDropdownField("Gender", selectedGender, ["Male", "Female", "Other"], Icons.transgender_outlined, (value) {
                  setState(() => selectedGender = value);
                }),

                const SizedBox(height: 50),

                // --- NEXT BUTTON TO LICENSE SCREEN ---
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const LawyerLicenseScreen()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: goldColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text(
                      "NEXT TO LICENSE →",
                      style: TextStyle(color: navyBlue, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 50), // End mein thodi jagah scroll ke liye
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, IconData icon, {TextInputType type = TextInputType.text}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: type,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: const Color(0xFFC5A358)),
            filled: true,
            fillColor: Colors.white.withOpacity(0.05),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField(String label, String? selectedValue, List<String> items, IconData icon, ValueChanged<String?> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              dropdownColor: const Color(0xFF101D3D),
              value: selectedValue,
              icon: const Icon(Icons.arrow_drop_down, color: Colors.white38),
              isExpanded: true,
              hint: const Text("Select", style: TextStyle(color: Colors.white38)),
              style: const TextStyle(color: Colors.white),
              items: items.map((String item) {
                return DropdownMenuItem<String>(
                  value: item,
                  child: Text(item),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}