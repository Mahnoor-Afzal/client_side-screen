import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'Lawyer_dashboard.dart';

class PaymentVerificationScreen extends StatefulWidget {
  const PaymentVerificationScreen({super.key});

  @override
  State<PaymentVerificationScreen> createState() => _PaymentVerificationScreenState();
}

class _PaymentVerificationScreenState extends State<PaymentVerificationScreen> {
  final _tidController = TextEditingController();
  Uint8List? _selectedImageBytes;
  File? _selectedImageFile;
  bool _isLoading = false;

  final Color navyBlue = const Color(0xFF101D3D);
  final Color goldColor = const Color(0xFFC5A358);

  // Cloudinary Configuration
  final String cloudName = "gasafl8q";
  final String uploadPreset = "ml_default";

  Future<void> _pickScreenshot() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);

      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _selectedImageBytes = bytes;
          if (!kIsWeb) {
            _selectedImageFile = File(image.path);
          }
        });
      }
    } catch (e) {
      debugPrint("Image Picker Error: $e");
    }
  }

  Future<String?> _uploadScreenshotToCloudinary() async {
    if (_selectedImageBytes == null && _selectedImageFile == null) return null;

    try {
      var uri = Uri.parse("https://api.cloudinary.com/v1_1/$cloudName/image/upload");
      var request = http.MultipartRequest("POST", uri);

      request.fields['upload_preset'] = uploadPreset;

      if (kIsWeb && _selectedImageBytes != null) {
        request.files.add(
          http.MultipartFile.fromBytes('file', _selectedImageBytes!, filename: 'payment_proof.jpg'),
        );
      } else if (_selectedImageFile != null) {
        request.files.add(
          await http.MultipartFile.fromPath('file', _selectedImageFile!.path),
        );
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        var responseData = jsonDecode(response.body);
        return responseData['secure_url'];
      }
      return null;
    } catch (e) {
      debugPrint("Cloudinary Upload Error: $e");
      return null;
    }
  }

  Future<void> _submitPayment() async {
    if (_tidController.text.trim().isEmpty || (_selectedImageBytes == null && _selectedImageFile == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter TID and upload the screenshot.")),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("User session missing. Please login again.");
      String uid = user.uid;

      DocumentSnapshot lawyerSnap = await FirebaseFirestore.instance.collection('lawyers').doc(uid).get();
      Map<String, dynamic> lawyerData = lawyerSnap.exists ? (lawyerSnap.data() as Map<String, dynamic>) : {};

      String? finalImageReference = await _uploadScreenshotToCloudinary();
      if (finalImageReference == null) {
        throw Exception("Failed to upload payment screenshot. Please try again.");
      }

      WriteBatch batch = FirebaseFirestore.instance.batch();

      batch.update(FirebaseFirestore.instance.collection('lawyers').doc(uid), {
        'paymentScreenshot': finalImageReference,
        'transactionId': _tidController.text.trim(),
        'paymentStatus': 'Submitted',
        'isApproved': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      batch.set(FirebaseFirestore.instance.collection('admin_requests').doc(uid), {
        'lawyerId': uid,
        'fullName': lawyerData['fullName'] ?? "New Lawyer",
        'email': user.email,
        'transactionId': _tidController.text.trim(),
        'paymentScreenshot': finalImageReference,
        'status': 'pending',
        'submittedAt': FieldValue.serverTimestamp(),
        'isWebUpload': kIsWeb,
      });

      batch.set(FirebaseFirestore.instance.collection('admin_notifications').doc(), {
        'title': 'New Payment Submitted',
        'body': '${lawyerData['fullName'] ?? "Lawyer"} has submitted payment verification.',
        'lawyerId': uid,
        'isRead': false,
        'timestamp': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Payment submitted! Verification pending.")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        backgroundColor: navyBlue,
        body: const Center(child: Text("Loading user credentials...", style: TextStyle(color: Colors.white))),
      );
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('lawyers').doc(user.uid).snapshots(),
      builder: (context, lawyerSnapshot) {
        if (lawyerSnapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(backgroundColor: navyBlue, body: Center(child: CircularProgressIndicator(color: goldColor)));
        }

        var lawyerData = lawyerSnapshot.data?.data() as Map<String, dynamic>? ?? {};
        String status = lawyerData['paymentStatus'] ?? 'Unpaid';
        bool isApproved = lawyerData['isApproved'] == true;

        if (status == 'Approved' || isApproved) {
          return const LawyerDashboard();
        }

        // Fetching Admin Payment Info from app_settings/payment_info dynamically
        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('app_settings').doc('payment_info').snapshots(),
          builder: (context, paymentSettingsSnapshot) {
            var paymentData = paymentSettingsSnapshot.data?.data() as Map<String, dynamic>? ?? {};

            String accountTitle = paymentData['account_title'] ?? 'Admin';
            String easypaisaNumber = paymentData['easypaisa_number'] ?? 'N/A';
            String jazzcashNumber = paymentData['jazzcash_number'] ?? 'N/A';
            String feeAmount = paymentData['fee_amount'] ?? '2000';

            return Scaffold(
              backgroundColor: navyBlue,
              appBar: AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                title: const Text("Registration Fee", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                actions: [
                  IconButton(onPressed: () => FirebaseAuth.instance.signOut(), icon: const Icon(Icons.logout, color: Colors.white))
                ],
              ),
              body: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(25),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.account_balance_wallet_outlined, size: 70, color: goldColor),
                      const SizedBox(height: 20),
                      Text("One-Time Registration Fee: Rs. $feeAmount", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      Text("Account Title: $accountTitle", style: const TextStyle(color: Colors.white70)),
                      const SizedBox(height: 5),
                      Text("EasyPaisa: $easypaisaNumber", style: const TextStyle(color: Colors.white70)),
                      const SizedBox(height: 5),
                      Text("JazzCash: $jazzcashNumber", style: const TextStyle(color: Colors.white70)),
                      const SizedBox(height: 30),

                      if (status == 'Submitted') ...[
                        const Icon(Icons.access_time_filled, size: 60, color: Colors.orangeAccent),
                        const SizedBox(height: 15),
                        const Text("Verification Pending", style: TextStyle(color: Colors.orangeAccent, fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 5),
                        const Text("We are verifying your payment. Thank you!", textAlign: TextAlign.center, style: TextStyle(color: Colors.white70)),
                      ] else ...[
                        TextField(
                          controller: _tidController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: "Enter TID",
                            hintStyle: const TextStyle(color: Colors.white24),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.05),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            prefixIcon: Icon(Icons.receipt_long, color: goldColor),
                          ),
                        ),
                        const SizedBox(height: 20),
                        GestureDetector(
                          onTap: _pickScreenshot,
                          child: Container(
                            height: 180,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: _selectedImageBytes != null ? goldColor : Colors.white10),
                            ),
                            child: _selectedImageBytes != null
                                ? Padding(
                              padding: const EdgeInsets.all(4.0),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.memory(_selectedImageBytes!, fit: BoxFit.contain),
                              ),
                            )
                                : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_photo_alternate_outlined, color: goldColor, size: 40),
                                Text("Upload Screenshot", style: TextStyle(color: goldColor)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 30),
                        SizedBox(
                          width: double.infinity,
                          height: 55,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _submitPayment,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: goldColor,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: _isLoading
                                ? const CircularProgressIndicator(color: Colors.black)
                                : const Text("SUBMIT PAYMENT", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}