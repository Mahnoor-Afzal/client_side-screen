import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

const Color navyBlue = Color(0xFF001F3F);
const Color gold = Color(0xFFD4AF37);
const Color lightGrey = Color(0xFFF5F5F5);

class ComplaintScreen extends StatefulWidget {
  const ComplaintScreen({super.key});

  @override
  State<ComplaintScreen> createState() => _ComplaintScreenState();
}

class _ComplaintScreenState extends State<ComplaintScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _complaintController = TextEditingController();
  String? _selectedCategory;
  String? _selectedLawyerId;
  String? _selectedLawyerName;
  bool _isLoading = false;
  List<Map<String, dynamic>> _lawyers = [];

  final List<String> _categories = [
    'Rude behaviour of lawyer',
    'Delayed response',
    'Incorrect information',
    'Lack of professionalism',
    'Other'
  ];

  @override
  void initState() {
    super.initState();
    _fetchLawyers();
  }

  Future<void> _fetchLawyers() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Fetch lawyers from both request collections to find who the client interacted with
      final suitRequests = await FirebaseFirestore.instance
          .collection('suit_a_file_request')
          .where('clientId', isEqualTo: user.uid)
          .get();

      final consultRequests = await FirebaseFirestore.instance
          .collection('consultation_request')
          .where('clientId', isEqualTo: user.uid)
          .get();

      Set<String> lawyerIds = {};
      List<Map<String, dynamic>> lawyerList = [];

      for (var doc in [...suitRequests.docs, ...consultRequests.docs]) {
        final data = doc.data();
        final lId = data['lawyerId'];
        final lName = data['lawyerName'];

        if (lId != null && lId != 'TBD' && !lawyerIds.contains(lId)) {
          lawyerIds.add(lId);
          lawyerList.add({
            'id': lId,
            'name': lName ?? "Unknown Lawyer",
          });
        }
      }

      // Also fetch all verified lawyers in case they want to complain about someone else
      if (lawyerList.isEmpty) {
        final allLawyers = await FirebaseFirestore.instance.collection('verified_lawyers').limit(20).get();
        for (var doc in allLawyers.docs) {
          if (!lawyerIds.contains(doc.id)) {
            lawyerList.add({
              'id': doc.id,
              'name': doc.data()['fullName'] ?? doc.data()['name'] ?? "Lawyer",
            });
          }
        }
      }

      if (mounted) {
        setState(() {
          _lawyers = lawyerList;
        });
      }
    } catch (e) {
      debugPrint("Error fetching lawyers: $e");
    }
  }

  Future<void> _submitComplaint() async {
    if (_selectedLawyerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a lawyer first")),
      );
      return;
    }
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
          'lawyerId': _selectedLawyerId,
          'lawyerName': _selectedLawyerName,
          'category': _selectedCategory,
          'description': _complaintController.text.trim(),
          'status': 'Open',
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
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Select Lawyer",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: navyBlue),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _selectedLawyerId,
                hint: const Text("Choose Lawyer"),
                isExpanded: true,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: lightGrey,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                items: _lawyers.map((lawyer) {
                  return DropdownMenuItem<String>(
                    value: lawyer['id'],
                    child: Text(lawyer['name']),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedLawyerId = val;
                    _selectedLawyerName = _lawyers.firstWhere((l) => l['id'] == val)['name'];
                  });
                },
                validator: (val) => val == null ? "Please select a lawyer" : null,
              ),
              const SizedBox(height: 25),
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
                TextFormField(
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
      ),
    );
  }
}
