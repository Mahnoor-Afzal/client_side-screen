import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'professional_details_screen.dart';

class LawyerLicenseScreen extends StatefulWidget {
  const LawyerLicenseScreen({super.key});

  @override
  State<LawyerLicenseScreen> createState() => _LawyerLicenseScreenState();
}

class _LawyerLicenseScreenState extends State<LawyerLicenseScreen> {
  String? selectedLicenseType; // District, High, or Supreme
  String? selectedBarCouncil; // Dropdown value

  final List<String> barCouncils = [
    "Punjab Bar Council",
    "Sindh Bar Council",
    "KPK Bar Council",
    "Balochistan Bar Council",
    "Islamabad Bar Council"
  ];

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
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
           onPressed: () {
      Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ProfessionalDetailsScreen()),
      );
      }
        ),
      ),
      // 1. Scrollbar Add Kar Diya Gaya Hai
      body: Scrollbar(
        thumbVisibility: true,
        thickness: 6,
        radius: const Radius.circular(10),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "License Details",
                style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 30),

              _buildField("License ID"),
              const SizedBox(height: 20),

              _buildField("Organization Name"),
              const SizedBox(height: 20),

              // 2. Bar Council Affiliation Dropdown
              const Text("Bar Council Affiliation", style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    dropdownColor: navyBlue,
                    hint: const Text("Select Bar Council", style: TextStyle(color: Colors.white24)),
                    value: selectedBarCouncil,
                    items: barCouncils.map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value, style: const TextStyle(color: Colors.white)),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => selectedBarCouncil = val),
                  ),
                ),
              ),

              const SizedBox(height: 30),
              const Text("Upload License (Front & Back)", style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _uploadBox("Front Side")),
                  const SizedBox(width: 10),
                  Expanded(child: _uploadBox("Back Side")),
                ],
              ),

              const SizedBox(height: 30),

              // 3. License Type with Selection Circles (Radio Style)
              const Text("License Type", style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w500)),
              const SizedBox(height: 10),
              _buildLicenseOption("District court", goldColor),
              _buildLicenseOption("High court", goldColor),
              _buildLicenseOption("Supreme court", goldColor),

              const SizedBox(height: 40),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: goldColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => const ProfessionalDetailsScreen()),
                    );
                  },
                  child: const Text(
                    "SUBMIT SETUP",
                    style: TextStyle(color: navyBlue, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 50),
            ],
          ),
        ),
      ),
    );
  }

  // Reusable TextField
  Widget _buildField(String hint) => TextField(
    style: const TextStyle(color: Colors.white),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white24),
      filled: true,
      fillColor: Colors.white.withOpacity(0.05),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    ),
  );

  // Reusable Upload Box
  Widget _uploadBox(String text) => Container(
    height: 100,
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.05),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.white10),
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.add_a_photo_outlined, color: Color(0xFFC5A358), size: 30),
        const SizedBox(height: 5),
        Text(text, style: const TextStyle(color: Colors.white38, fontSize: 12)),
      ],
    ),
  );

  // 4. Custom License Option with Circle Tick
  Widget _buildLicenseOption(String title, Color gold) {
    bool isSelected = selectedLicenseType == title;
    return GestureDetector(
      onTap: () => setState(() => selectedLicenseType = title),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? gold : Colors.transparent),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 15)),
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: gold, width: 2),
                color: isSelected ? gold : Colors.transparent,
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 16, color: Color(0xFF101D3D))
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}