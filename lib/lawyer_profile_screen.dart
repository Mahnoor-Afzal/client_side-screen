import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart'; // Web / Bytes checking
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
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
  final _ageController = TextEditingController();
  final _expController = TextEditingController();

  String? selectedProvince;
  String? selectedGender;
  bool _isLoading = false;

  // Image Upload Variables
  File? _selectedImage;
  Uint8List? _webImageBytes;
  String? _profileImageUrl;

  // Cloudinary Configurations
  final String cloudName = "gasafl8q";
  final String uploadPreset = "ml_default"; // Fixed Preset Key

  // 📷 Pick Image Function
  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);

    if (image != null) {
      if (kIsWeb) {
        final bytes = await image.readAsBytes();
        setState(() {
          _webImageBytes = bytes;
        });
      } else {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    }
  }

  // ☁️ Upload Image to Cloudinary Function
  Future<String?> _uploadImageToCloudinary() async {
    if (_selectedImage == null && _webImageBytes == null) return null;

    try {
      var uri = Uri.parse("https://api.cloudinary.com/v1_1/$cloudName/image/upload");
      var request = http.MultipartRequest("POST", uri);

      request.fields['upload_preset'] = uploadPreset;

      if (kIsWeb && _webImageBytes != null) {
        request.files.add(
          http.MultipartFile.fromBytes('file', _webImageBytes!, filename: 'profile.jpg'),
        );
      } else if (_selectedImage != null) {
        request.files.add(
          await http.MultipartFile.fromPath('file', _selectedImage!.path),
        );
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        var responseData = jsonDecode(response.body);
        return responseData['secure_url'];
      } else {
        throw "Image upload failed with status ${response.statusCode}";
      }
    } catch (e) {
      debugPrint("Cloudinary Image Upload Error: $e");
      return null;
    }
  }

  Future<void> _saveProfile() async {
    if (_nameController.text.isEmpty ||
        _cnicController.text.isEmpty ||
        _phoneController.text.isEmpty ||
        _ageController.text.isEmpty ||
        _expController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill all fields")));
      return;
    }

    int age = int.tryParse(_ageController.text) ?? 0;
    int exp = int.tryParse(_expController.text) ?? 0;

    // Validation: Experience must be at least 18 years less than Age
    if (age - exp < 18) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Invalid Experience! At least 18 years gap required between Age and Experience."),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      // Step 1: Image upload process if selected
      if (_selectedImage != null || _webImageBytes != null) {
        _profileImageUrl = await _uploadImageToCloudinary();
      }

      String uid = FirebaseAuth.instance.currentUser!.uid;

      // Step 2: Firestore update with profile picture URL
      await FirebaseFirestore.instance.collection('lawyers').doc(uid).update({
        'fullName': _nameController.text.trim(),
        'cnic': _cnicController.text.trim(),
        'phone': _phoneController.text.trim(),
        'age': age,
        'experience': exp,
        'province': selectedProvince,
        'gender': selectedGender,
        'area': _areaController.text.trim(),
        'profileImageUrl': _profileImageUrl ?? '',
        'registrationStatus': 'profile_completed',
      });

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const LawyerLicenseScreen()),
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
        title: const Text("Profile Setup", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 📸 Interactive Profile Image Selector
              Center(
                child: GestureDetector(
                  onTap: _pickImage,
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Container(
                        width: 95,
                        height: 95,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          shape: BoxShape.circle,
                          border: Border.all(color: goldColor, width: 2),
                          image: _getProfileImageProvider(),
                        ),
                        child: (_selectedImage == null && _webImageBytes == null)
                            ? const Icon(Icons.person_outline, color: Colors.white38, size: 50)
                            : null,
                      ),
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: const BoxDecoration(
                          color: goldColor,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.camera_alt, color: navyBlue, size: 18),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _buildTextField("Full Name", _nameController, Icons.person_outline),
              const SizedBox(height: 15),

              Row(
                children: [
                  Expanded(child: _buildTextField("Age", _ageController, Icons.cake_outlined, type: TextInputType.number)),
                  const SizedBox(width: 15),
                  Expanded(child: _buildTextField("Exp (Years)", _expController, Icons.work_outline, type: TextInputType.number)),
                ],
              ),
              const SizedBox(height: 15),

              // CNIC Input: Auto-formats to XXXXX-XXXXXXX-X (15 chars limit)
              _buildTextField(
                "CNIC Number",
                _cnicController,
                Icons.credit_card,
                limit: 15,
                type: TextInputType.number,
                formatters: [_CnicInputFormatter()],
                hint: "xxxxx-xxxxxxx-x",
              ),
              const SizedBox(height: 15),

              // Simple Phone Input: 11 Digits max, no dash formatting
              _buildTextField(
                "Phone Number",
                _phoneController,
                Icons.phone_android_outlined,
                type: TextInputType.phone,
                limit: 11,
                formatters: [FilteringTextInputFormatter.digitsOnly],
                hint: "03XXXXXXXXX",
              ),
              const SizedBox(height: 15),
              Row(
                children: [
                  Expanded(
                    child: _buildDropdownField("Province", selectedProvince, ["Punjab", "Sindh", "KPK", "Balochistan"], Icons.map_outlined, (value) {
                      setState(() => selectedProvince = value);
                    }),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: _buildDropdownField("Gender", selectedGender, ["Male", "Female"], Icons.transgender_outlined, (value) {
                      setState(() => selectedGender = value);
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              _buildTextField("Area", _areaController, Icons.location_on_outlined),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: goldColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: navyBlue)
                      : const Text("NEXT TO LICENSE →", style: TextStyle(color: navyBlue, fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // Helper method to display selected image dynamically (Web & Mobile supported)
  DecorationImage? _getProfileImageProvider() {
    if (kIsWeb && _webImageBytes != null) {
      return DecorationImage(image: MemoryImage(_webImageBytes!), fit: BoxFit.cover);
    } else if (_selectedImage != null) {
      return DecorationImage(image: FileImage(_selectedImage!), fit: BoxFit.cover);
    }
    return null;
  }

  Widget _buildTextField(
      String label,
      TextEditingController controller,
      IconData icon, {
        TextInputType type = TextInputType.text,
        int? limit,
        List<TextInputFormatter>? formatters,
        String? hint,
      }) {
    return TextFormField(
      controller: controller,
      keyboardType: type,
      maxLength: limit,
      inputFormatters: formatters,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54, fontSize: 12),
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
        prefixIcon: Icon(icon, color: const Color(0xFFC5A358), size: 20),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(vertical: 10),
        counterText: "",
      ),
    );
  }

  Widget _buildDropdownField(String label, String? selectedValue, List<String> items, IconData icon, ValueChanged<String?> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 5),
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
              hint: const Text("Select", style: TextStyle(color: Colors.white38, fontSize: 12)),
              style: const TextStyle(color: Colors.white, fontSize: 14),
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

// 🇵🇰 Custom CNIC Formatter (Formats input to XXXXX-XXXXXXX-X)
class _CnicInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var digitsOnly = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digitsOnly.length > 13) digitsOnly = digitsOnly.substring(0, 13);

    String formatted = '';
    for (int i = 0; i < digitsOnly.length; i++) {
      if (i == 5 || i == 12) {
        formatted += '-';
      }
      formatted += digitsOnly[i];
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}