import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart'; // Web / Bytes checking
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'professional_details_screen.dart';

class LawyerLicenseScreen extends StatefulWidget {
  const LawyerLicenseScreen({super.key});

  @override
  State<LawyerLicenseScreen> createState() => _LawyerLicenseScreenState();
}

class _LawyerLicenseScreenState extends State<LawyerLicenseScreen> {
  String? selectedLicenseType;
  String? selectedBarCouncil;
  final _licenseIdController = TextEditingController();
  final _orgNameController = TextEditingController();
  bool _isLoading = false;

  // Cloudinary Configurations
  final String cloudName = "gasafl8q";
  final String uploadPreset = "ml_default";

  // Image Selection Variables (Mobile)
  File? _cnicFrontFile;
  File? _cnicBackFile;
  File? _licenseFrontFile;
  File? _licenseBackFile;

  // Image Selection Variables (Web)
  Uint8List? _cnicFrontBytes;
  Uint8List? _cnicBackBytes;
  Uint8List? _licenseFrontBytes;
  Uint8List? _licenseBackBytes;

  final List<String> barCouncils = [
    "Punjab Bar Council",
    "Sindh Bar Council",
    "KPK Bar Council",
    "Balochistan Bar Council",
    "Islamabad Bar Council"
  ];

  // 📷 Generic Image Picker Helper
  Future<void> _pickImage(String type) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);

    if (image != null) {
      if (kIsWeb) {
        final bytes = await image.readAsBytes();
        setState(() {
          if (type == 'cnicFront') _cnicFrontBytes = bytes;
          if (type == 'cnicBack') _cnicBackBytes = bytes;
          if (type == 'licenseFront') _licenseFrontBytes = bytes;
          if (type == 'licenseBack') _licenseBackBytes = bytes;
        });
      } else {
        setState(() {
          if (type == 'cnicFront') _cnicFrontFile = File(image.path);
          if (type == 'cnicBack') _cnicBackFile = File(image.path);
          if (type == 'licenseFront') _licenseFrontFile = File(image.path);
          if (type == 'licenseBack') _licenseBackFile = File(image.path);
        });
      }
    }
  }

  // ☁️ Cloudinary Upload Helper
  Future<String?> _uploadSingleImageToCloudinary(File? file, Uint8List? bytes, String fileName) async {
    if (file == null && bytes == null) return null;

    try {
      var uri = Uri.parse("https://api.cloudinary.com/v1_1/$cloudName/image/upload");
      var request = http.MultipartRequest("POST", uri);

      request.fields['upload_preset'] = uploadPreset;

      if (kIsWeb && bytes != null) {
        request.files.add(
          http.MultipartFile.fromBytes('file', bytes, filename: '$fileName.jpg'),
        );
      } else if (file != null) {
        request.files.add(
          await http.MultipartFile.fromPath('file', file.path),
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
      debugPrint("Cloudinary Upload Error ($fileName): $e");
      return null;
    }
  }

  Future<void> _saveLicenseDetails() async {
    if (_licenseIdController.text.isEmpty || selectedBarCouncil == null || selectedLicenseType == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill all required fields")));
      return;
    }

    setState(() => _isLoading = true);
    try {
      // Step 1: Upload Documents to Cloudinary
      String? cnicFrontUrl = await _uploadSingleImageToCloudinary(_cnicFrontFile, _cnicFrontBytes, "cnic_front");
      String? cnicBackUrl = await _uploadSingleImageToCloudinary(_cnicBackFile, _cnicBackBytes, "cnic_back");
      String? licenseFrontUrl = await _uploadSingleImageToCloudinary(_licenseFrontFile, _licenseFrontBytes, "license_front");
      String? licenseBackUrl = await _uploadSingleImageToCloudinary(_licenseBackFile, _licenseBackBytes, "license_back");

      String uid = FirebaseAuth.instance.currentUser!.uid;

      // Step 2: Save to Firestore
      await FirebaseFirestore.instance.collection('lawyers').doc(uid).update({
        'licenseId': _licenseIdController.text.trim(),
        'organizationName': _orgNameController.text.trim(),
        'barCouncil': selectedBarCouncil,
        'licenseType': selectedLicenseType,
        'cnicFrontUrl': cnicFrontUrl ?? '',
        'cnicBackUrl': cnicBackUrl ?? '',
        'licenseFrontUrl': licenseFrontUrl ?? '',
        'licenseBackUrl': licenseBackUrl ?? '',
        'registrationStatus': 'license_completed',
      });

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const ProfessionalDetailsScreen()),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color navyBlue = Color(0xFF101D3D);
    const Color goldColor = Color(0xFFC5A358);

    return Scaffold(
      backgroundColor: navyBlue,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
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

              _buildField("License ID", _licenseIdController),
              const SizedBox(height: 20),

              // Organization Name Field Added Here
              _buildField("Organization Name", _orgNameController),
              const SizedBox(height: 20),

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

              const Text("Upload CNIC (Front & Back)", style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _uploadBox("CNIC Front", 'cnicFront', _cnicFrontFile, _cnicFrontBytes)),
                  const SizedBox(width: 10),
                  Expanded(child: _uploadBox("CNIC Back", 'cnicBack', _cnicBackFile, _cnicBackBytes)),
                ],
              ),

              const SizedBox(height: 25),

              const Text("Upload License (Front & Back)", style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _uploadBox("License Front", 'licenseFront', _licenseFrontFile, _licenseFrontBytes)),
                  const SizedBox(width: 10),
                  Expanded(child: _uploadBox("License Back", 'licenseBack', _licenseBackFile, _licenseBackBytes)),
                ],
              ),

              const SizedBox(height: 30),
              const Text("License Type", style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w500)),
              const SizedBox(height: 10),
              _buildLicenseOption("District court", goldColor),
              _buildLicenseOption("High court", goldColor),
              _buildLicenseOption("Supreme court", goldColor),

              const SizedBox(height: 40),

              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: goldColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isLoading ? null : _saveLicenseDetails,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: navyBlue)
                      : const Text("SUBMIT SETUP", style: TextStyle(color: navyBlue, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 50),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(String hint, TextEditingController controller) => TextField(
    controller: controller,
    style: const TextStyle(color: Colors.white),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white24),
      filled: true,
      fillColor: Colors.white.withOpacity(0.05),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    ),
  );

  Widget _uploadBox(String text, String type, File? file, Uint8List? bytes) {
    bool hasImage = (kIsWeb && bytes != null) || (!kIsWeb && file != null);

    return GestureDetector(
      onTap: () => _pickImage(type),
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          color: hasImage ? const Color(0xFFC5A358).withOpacity(0.15) : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: hasImage ? const Color(0xFFC5A358) : Colors.white10),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              hasImage ? Icons.check_circle_outline : Icons.add_a_photo_outlined,
              color: const Color(0xFFC5A358),
              size: 30,
            ),
            const SizedBox(height: 5),
            Text(
              hasImage ? "$text (Selected)" : text,
              style: TextStyle(
                color: hasImage ? Colors.white : Colors.white38,
                fontSize: 12,
                fontWeight: hasImage ? FontWeight.bold : FontWeight.normal,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

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