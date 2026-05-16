import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'lawyer_list_screen.dart';

class CreateCaseScreen extends StatefulWidget {
  const CreateCaseScreen({super.key});

  @override
  State<CreateCaseScreen> createState() => _CreateCaseScreenState();
}

class _CreateCaseScreenState extends State<CreateCaseScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _descriptionController = TextEditingController();

  String? _selectedState;
  String? _selectedCaseType;
  String? _selectedCategory;

  final List<String> _states = [
    'Punjab', 'Sindh', 'KPK', 'Balochistan', 'Gilgit Baltistan', 'Azad Kashmir'
  ];

  final Map<String, List<String>> _caseCategories = {
    'Property / Land': ['Buy/Sell', 'Fraud', 'Inheritance'],
    'Family Issues': ['Children', 'Divorce / Khula', 'Legal Formalities'],
    'Cyber Crime': ['Online Fraud', 'Harassment'],
    'Others': ['Employer Issues', 'Tax Issues', 'Torture', 'Business / Industrial'],
  };

  static const Color navyBlue = Color(0xFF001F3F);
  static const Color accentGold = Color(0xFFD4AF37);
  static const Color lightGrey = Color(0xFFF5F5F5);

  bool _isLoading = false;
  bool _isSubmitted = false;

  // --- UPDATED NOTIFICATION FUNCTION ---
  Future<void> _notifyAllLawyers(String clientName, String caseType) async {
    // Aapki di hui Server Key yahan add kar di hai
    const String serverKey = 'AIzaSyDQP_4C2i-KvTJs7EeM_KyxShTP8NXTmqA';

    try {
      await http.post(
        Uri.parse('https://fcm.googleapis.com/fcm/send'),
        headers: <String, String>{
          'Content-Type': 'application/json',
          'Authorization': 'key=$serverKey',
        },
        body: jsonEncode({
          'notification': {
            'title': 'New Legal Case Posted!',
            'body': '$clientName has posted a new $caseType case.',
            'sound': 'default',
            'android_channel_id': 'high_importance_channel',
          },
          'priority': 'high',
          'to': '/topics/all_lawyers', // Topic based notification
        }),
      );
      debugPrint("Broadcasting notification to all lawyers...");
    } catch (e) {
      debugPrint("Notification failed: $e");
    }
  }

  Future<void> _submitCase() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        User? user = FirebaseAuth.instance.currentUser;
        String clientName = "A Client";

        if (user != null) {
          DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
          if (userDoc.exists) {
            clientName = userDoc['name'] ?? "A Client";
          }
        }

        // 1. Data Firestore mein save karna
        await FirebaseFirestore.instance.collection('suit_a_file_request').add({
          'clientName': clientName,
          'type': 'File a Suit',
          'caseCategory': _selectedCaseType,
          'subCategory': _selectedCategory,
          'state': _selectedState,
          'description': _descriptionController.text.trim(),
          'status': 'Pending',
          'createdAt': FieldValue.serverTimestamp(),
          'clientId': user?.uid,
          'lawyerId': null,
          'lawyerName': 'TBD',
        });

        // 2. Notification bhejna
        await _notifyAllLawyers(clientName, _selectedCaseType ?? "Legal");

        if (mounted) {
          setState(() {
            _isSubmitted = true;
          });
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Failed to submit case: $e")),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  // ... (Baqi UI ka code wahi rahega jo aapne diya tha) ...

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "CREATE NEW CASE",
          style: TextStyle(color: navyBlue, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.5),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: navyBlue),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isSubmitted ? _buildSuccessView() : _buildFormView(),
    );
  }

  Widget _buildFormView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(25),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Case Details", style: TextStyle(color: navyBlue, fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text("Please fill in the information below to register your case.", style: TextStyle(color: Colors.grey, fontSize: 14)),
            const SizedBox(height: 30),

            _buildLabel("Select State"),
            _buildDropdown(
              hint: "Select State",
              value: _selectedState,
              items: _states,
              onChanged: (val) => setState(() => _selectedState = val),
            ),
            const SizedBox(height: 20),

            _buildLabel("Select Case Type"),
            _buildDropdown(
              hint: "Select Case Type",
              value: _selectedCaseType,
              items: _caseCategories.keys.toList(),
              onChanged: (val) {
                setState(() {
                  _selectedCaseType = val;
                  _selectedCategory = null;
                });
              },
            ),
            const SizedBox(height: 20),

            if (_selectedCaseType != null) ...[
              _buildLabel("Select Case Category"),
              _buildDropdown(
                hint: "Select Category",
                value: _selectedCategory,
                items: _caseCategories[_selectedCaseType]!,
                onChanged: (val) => setState(() => _selectedCategory = val),
              ),
              const SizedBox(height: 20),
            ],

            _buildLabel("Description"),
            TextFormField(
              controller: _descriptionController,
              maxLines: 4,
              style: const TextStyle(color: Colors.black87),
              decoration: InputDecoration(
                hintText: "Explain your legal problem here...",
                hintStyle: const TextStyle(color: Colors.black26),
                filled: true,
                fillColor: lightGrey,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: navyBlue)),
              ),
              validator: (val) => val == null || val.isEmpty ? "Please enter description" : null,
            ),

            const SizedBox(height: 40),

            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitCase,
                style: ElevatedButton.styleFrom(
                  backgroundColor: navyBlue,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("SUBMIT CASE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.green, size: 100),
            const SizedBox(height: 20),
            const Text("Case Submitted!", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: navyBlue)),
            const SizedBox(height: 10),
            const Text("Your case has been successfully registered. Now you can find a legal expert to help you.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 16)),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const LawyerListScreen()));
                },
                icon: const Icon(Icons.search, color: Colors.white),
                label: const Text("SEARCH LAWYER", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentGold,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
              ),
            ),
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Go Back to Dashboard", style: TextStyle(color: navyBlue)))
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(padding: const EdgeInsets.only(bottom: 8.0), child: Text(text, style: const TextStyle(color: navyBlue, fontSize: 14, fontWeight: FontWeight.w600)));
  }

  Widget _buildDropdown({required String hint, required String? value, required List<String> items, required ValueChanged<String?> onChanged}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      decoration: BoxDecoration(color: lightGrey, borderRadius: BorderRadius.circular(15)),
      child: DropdownButtonFormField<String>(
        value: value,
        hint: Text(hint, style: const TextStyle(color: Colors.black26)),
        dropdownColor: Colors.white,
        icon: const Icon(Icons.keyboard_arrow_down, color: navyBlue),
        items: items.map((String item) => DropdownMenuItem<String>(value: item, child: Text(item, style: const TextStyle(color: Colors.black87)))).toList(),
        onChanged: onChanged,
        validator: (value) => value == null ? 'This field is required' : null,
        decoration: const InputDecoration(border: InputBorder.none),
      ),
    );
  }
}