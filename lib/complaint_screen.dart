import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ComplaintScreen extends StatefulWidget {
  const ComplaintScreen({super.key});

  @override
  State<ComplaintScreen> createState() => _ComplaintScreenState();
}

class _ComplaintScreenState extends State<ComplaintScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _complaintController = TextEditingController();
  String? _selectedCategory;
  bool _isLoading = false;

  final List<String> _categories = [
    'Rude behaviour of lawyer',
    'Delayed response',
    'Incorrect information',
    'Lack of professionalism',
    'Other'
  ];

  static const Color navyBlue = Color(0xFF001F3F);
  static const Color gold = Color(0xFFD4AF37);
  static const Color lightGrey = Color(0xFFF5F5F5);

  Future<void> _submitComplaint() async {
    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a category first")),
      );
      return;
    }

    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        final user = FirebaseAuth.instance.currentUser;
        String userName = "User";
        
        // Fetch current user name for admin's reference
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(user?.uid).get();
        if (userDoc.exists) {
          userName = userDoc.data()?['name'] ?? "User";
        }

        await FirebaseFirestore.instance.collection('complaints').add({
          'userId': user?.uid,
          'userName': userName,
          'userEmail': user?.email,
          'category': _selectedCategory,
          'description': _complaintController.text.trim(),
          'status': 'Open', // Admin can change this to 'In Progress' or 'Resolved'
          'priority': 'Normal',
          'submittedBy': 'client',
          'createdAt': FieldValue.serverTimestamp(),
        });

        if (!mounted) return;
        
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Success"),
            content: const Text("Your complaint has been submitted successfully."),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  Navigator.pop(context); // Go back
                },
                child: const Text("OK"),
              ),
            ],
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: navyBlue,
        elevation: 0,
        title: const Text("File a Complaint", style: TextStyle(color: gold, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: gold),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "What issue are you facing?",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: navyBlue),
            ),
            const SizedBox(height: 10),
            const Text(
              "Select a category that best describes your problem.",
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 25),

            // Categories List
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final category = _categories[index];
                final isSelected = _selectedCategory == category;
                return GestureDetector(
                  onTap: () => setState(() => _selectedCategory = category),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                    decoration: BoxDecoration(
                      color: isSelected ? navyBlue : lightGrey,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isSelected ? gold : Colors.transparent, width: 2),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isSelected ? Icons.check_circle : Icons.circle_outlined,
                          color: isSelected ? gold : Colors.grey,
                        ),
                        const SizedBox(width: 15),
                        Text(
                          category,
                          style: TextStyle(
                            color: isSelected ? Colors.white : navyBlue,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

            if (_selectedCategory != null) ...[
              const SizedBox(height: 25),
              const Text(
                "Describe your complaint",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: navyBlue),
              ),
              const SizedBox(height: 10),
              Form(
                key: _formKey,
                child: TextFormField(
                  controller: _complaintController,
                  maxLines: 5,
                  decoration: InputDecoration(
                    hintText: "Enter details here...",
                    filled: true,
                    fillColor: lightGrey,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: navyBlue)),
                  ),
                  validator: (val) => val == null || val.isEmpty ? "Please enter some details" : null,
                ),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitComplaint,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: gold,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: navyBlue)
                      : const Text(
                          "SUBMIT COMPLAINT",
                          style: TextStyle(color: navyBlue, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
