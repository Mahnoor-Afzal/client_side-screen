import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'client_lawyer_list_screen.dart';
import 'client_dashboard.dart';
import 'client_notification_helper.dart';

class CreateCaseScreen extends StatefulWidget {
  final String? lawyerId;
  final String? lawyerName;
  const CreateCaseScreen({super.key, this.lawyerId, this.lawyerName});

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

  bool _showSuccess = false;

  Future<void> _submitCase() async {
    if (_formKey.currentState!.validate()) {
      final caseData = {
        'caseCategory': _selectedCaseType,
        'subCategory': _selectedCategory,
        'state': _selectedState,
        'description': _descriptionController.text.trim(),
        'type': 'File a Suit',
      };

      if (widget.lawyerId != null) {
        // If we already have a lawyer (e.g., coming from profile), send it immediately
        setState(() => _isLoading = true);
        try {
          User? user = FirebaseAuth.instance.currentUser;
          String clientName = "A Client";

          if (user != null) {
            DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
            if (userDoc.exists) {
              clientName = userDoc['name'] ?? "A Client";
            }
          }

          DocumentReference docRef = await FirebaseFirestore.instance.collection('suit_a_file_request').add({
            ...caseData,
            'clientName': clientName,
            'status': 'Pending',
            'createdAt': FieldValue.serverTimestamp(),
            'clientId': user?.uid,
            'lawyerId': widget.lawyerId,
            'lawyerName': widget.lawyerName,
            'isDirectRequest': true,
          });

          await FirebaseFirestore.instance.collection('notifications').add({
            'userId': widget.lawyerId,
            'title': 'New Direct Case Request',
            'body': '$clientName sent you a $_selectedCaseType request.',
            'createdAt': FieldValue.serverTimestamp(),
            'requestId': docRef.id,
            'type': 'request_received',
            'isRead': false,
          });

          // Send Push Notification
          DocumentSnapshot lawyerDoc = await FirebaseFirestore.instance.collection('verified_lawyers').doc(widget.lawyerId!).get();
          String? fcmToken = (lawyerDoc.data() as Map<String, dynamic>?)?['fcmToken'];
          if (fcmToken != null && fcmToken.isNotEmpty) {
            await NotificationHelper.sendGlobalPushNotification(
              token: fcmToken,
              title: 'Direct Case Request!',
              body: '$clientName has sent you a $_selectedCaseType case.',
              data: {
                'type': 'request_received',
                'requestId': docRef.id,
                'isDirectRequest': 'true',
                'click_action': 'FLUTTER_NOTIFICATION_CLICK',
              },
            );
          }

          if (mounted) {
            setState(() {
              _showSuccess = true;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Case request sent to ${widget.lawyerName}"), backgroundColor: Colors.green),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed: $e")));
          }
        } finally {
          if (mounted) setState(() => _isLoading = false);
        }
      } else {
        // No lawyer selected yet. Do NOT save to Firestore yet.
        // Just show the success view and pass the data to LawyerListScreen.
        setState(() {
          _showSuccess = true;
        });
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
        title: Text(
          _showSuccess ? "CASE SUBMITTED" : "CREATE NEW CASE",
          style: const TextStyle(color: navyBlue, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.5),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: navyBlue),
          onPressed: () {
            if (_showSuccess) {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const DashboardScreen()),
                (route) => false,
              );
            } else {
              Navigator.pop(context);
            }
          },
        ),
      ),
      body: _showSuccess ? _buildSuccessView() : _buildFormView(),
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
                  Navigator.push(
                    context, 
                    MaterialPageRoute(
                      builder: (context) => LawyerListScreen(
                        stateFilter: _selectedState,
                        specializationFilter: _selectedCaseType,
                        pendingCaseData: {
                          'caseCategory': _selectedCaseType,
                          'subCategory': _selectedCategory,
                          'state': _selectedState,
                          'description': _descriptionController.text.trim(),
                        },
                      )
                    )
                  );
                },
                icon: const Icon(Icons.search, color: Colors.white),
                label: const Text("SEARCH LAWYER", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentGold,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const DashboardScreen()),
                  (route) => false,
                );
              },
              child: const Text("Go Back to Dashboard", style: TextStyle(color: navyBlue)),
            )
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
        initialValue: value,
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
