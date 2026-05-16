import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'Lawyer_dashboard.dart';

class ProfessionalDetailsScreen extends StatefulWidget {
  const ProfessionalDetailsScreen({super.key});

  @override
  State<ProfessionalDetailsScreen> createState() => _ProfessionalDetailsScreenState();
}

class _ProfessionalDetailsScreenState extends State<ProfessionalDetailsScreen> {
  final Color navyBlue = const Color(0xFF101D3D);
  final Color goldColor = const Color(0xFFC5A358);

  String? selectedOrg;
  final _descriptionController = TextEditingController();
  final List<String> disciplines = [
    "Property Law", "Family Law", "Criminal Law",
    "Tax Law", "Corporate Law", "Immigration Law"
  ];
  List<String> selectedDisciplines = [];
  bool _isLoading = false;

  Future<void> _completeSetup() async {
    if (selectedDisciplines.isEmpty || _descriptionController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select at least 1 discipline and provide a description")));
      return;
    }

    setState(() => _isLoading = true);
    try {
      String uid = FirebaseAuth.instance.currentUser!.uid;
      
      // Get current lawyer data safely
      DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('lawyers').doc(uid).get();
      Map<String, dynamic>? userData = userDoc.data() as Map<String, dynamic>?;
      
      String fullName = userData?['fullName'] ?? "Lawyer";
      String email = userData?['email'] ?? "N/A";

      // Update lawyer profile
      await FirebaseFirestore.instance.collection('lawyers').doc(uid).update({
        'organization': selectedOrg,
        'specialization': selectedDisciplines,
        'description': _descriptionController.text.trim(),
        'registrationStatus': 'completed',
      });

      // Send detailed request to admin
      await FirebaseFirestore.instance.collection('admin_requests').doc(uid).set({
        'lawyerId': uid,
        'fullName': fullName,
        'email': email,
        'type': 'new_registration',
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Create a notification for admin
      await FirebaseFirestore.instance.collection('admin_notifications').add({
        'title': 'New Lawyer Registration',
        'body': '$fullName has requested verification.',
        'lawyerId': uid,
        'isRead': false,
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LawyerDashboard()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: navyBlue,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text("Professional Details", style: TextStyle(color: Colors.white)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
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
            const Text("Preferred Discipline (Select up to 3)",
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)),
            const SizedBox(height: 10),

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
              controller: _descriptionController,
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

            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: goldColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _isLoading ? null : _completeSetup,
                child: _isLoading 
                  ? const CircularProgressIndicator(color: Color(0xFF101D3D))
                  : const Text("COMPLETE SETUP", style: TextStyle(color: Color(0xFF101D3D), fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }
}
