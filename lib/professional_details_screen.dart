
import 'package:flutter/material.dart';
import 'home_screen.dart'; // Final submit ke baad yahan jayega

class ProfessionalDetailsScreen extends StatefulWidget {
  const ProfessionalDetailsScreen({super.key});

  @override
  State<ProfessionalDetailsScreen> createState() => _ProfessionalDetailsScreenState();
}

class _ProfessionalDetailsScreenState extends State<ProfessionalDetailsScreen> {
  // Aapke exact colors
  final Color navyBlue = const Color(0xFF101D3D);
  final Color goldColor = const Color(0xFFC5A358);

  String? selectedOrg;
  final List<String> disciplines = [
    "Property Law", "Family Law", "Criminal Law",
    "Tax Law", "Corporate Law", "Immigration Law"
  ];
  List<String> selectedDisciplines = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: navyBlue,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Professional Details",
              style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 30),

            // --- Organization Dropdown ---
            const Text("Organization Name", style: TextStyle(color: Colors.white70)),
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
                  hint: const Text("Select Organization", style: TextStyle(color: Colors.white24)),
                  value: selectedOrg,
                  items: ["Private Practice", "Law Firm", "Government"].map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value, style: const TextStyle(color: Colors.white)),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => selectedOrg = val),
                ),
              ),
            ),

            const SizedBox(height: 25),
            const Text("Location Covered", style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text("Pakistan", style: TextStyle(color: Colors.white)),
            ),

            const SizedBox(height: 25),
            const Text("Preferred Discipline (Select 3)",
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)),
            const SizedBox(height: 10),

            // --- Disciplines Grid ---
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 2.5,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: disciplines.length,
              itemBuilder: (context, index) {
                bool isSelected = selectedDisciplines.contains(disciplines[index]);
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        selectedDisciplines.remove(disciplines[index]);
                      } else if (selectedDisciplines.length < 3) {
                        selectedDisciplines.add(disciplines[index]);
                      }
                    });
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isSelected ? goldColor : Colors.transparent),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      disciplines[index],
                      style: TextStyle(color: isSelected ? goldColor : Colors.white70, fontSize: 12),
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 25),
            const Text("Description *", style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 8),
            TextField(
              maxLines: 4,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                hintText: "Briefly describe your legal experience...",
                hintStyle: const TextStyle(color: Colors.white24),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),

            const SizedBox(height: 40),

            // --- Final Submit Button ---
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: goldColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  // Saara data backend par save karne ke baad:
                  Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => const HomeScreen())
                  );
                },
                child: Text(
                  "COMPLETE SETUP",
                  style: TextStyle(color: navyBlue, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }
}