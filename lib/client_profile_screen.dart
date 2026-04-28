import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'client_login_screen.dart';
import 'client_signature_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  String? _base64Image; // To store image as string
  String? _userRole;
  String? _digitalSignatureUrl;
  bool _hasDigitalSignature = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      User? user = _auth.currentUser;
      if (user != null) {
        // Check 'users' collection first
        DocumentSnapshot doc = await _firestore.collection('users').doc(user.uid).get();
        
        if (!doc.exists) {
          // If not found in 'users', check 'verified_lawyers'
          doc = await _firestore.collection('verified_lawyers').doc(user.uid).get();
        }

        if (doc.exists) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          setState(() {
            // Handle both 'name' (clients) and 'fullName' (lawyers)
            _nameController.text = data['name'] ?? data['fullName'] ?? '';
            _phoneController.text = data['phone'] ?? '';
            _idController.text = data['idNumber'] ?? '';
            _locationController.text = data['location'] ?? '';
            _base64Image = data['profilePicture'];
            _userRole = data['role'] ?? (doc.reference.parent.id == 'verified_lawyers' ? 'lawyer' : 'client');
            _digitalSignatureUrl = data['digitalSignatureUrl'];
            _hasDigitalSignature = data['hasDigitalSignature'] ?? false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error loading data: $e")),
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

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    // Profile picture ke liye image size thora chota rakhte hain taake Firestore mein fit aa jaye
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 400, 
      maxHeight: 400,
      imageQuality: 70, 
    );

    if (pickedFile != null) {
      // Use readAsBytes() directly from XFile for cross-platform compatibility (Web, Android, iOS)
      final bytes = await pickedFile.readAsBytes();
      setState(() {
        _base64Image = base64Encode(bytes); // Image ko text (string) mein badal diya
      });
    }
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      User? user = _auth.currentUser;
      if (user != null) {
        // Determine which collection to update
        String collection = 'users';
        DocumentSnapshot userDoc = await _firestore.collection('users').doc(user.uid).get();
        if (!userDoc.exists) {
          DocumentSnapshot lawyerDoc = await _firestore.collection('verified_lawyers').doc(user.uid).get();
          if (lawyerDoc.exists) {
            collection = 'verified_lawyers';
          }
        }

        Map<String, dynamic> updateData = {
          'phone': _phoneController.text.trim(),
          'idNumber': _idController.text.trim(),
          'location': _locationController.text.trim(),
          'profilePicture': _base64Image, // Save image as string directly in Firestore
        };

        // Handle different name field names
        if (collection == 'verified_lawyers') {
          updateData['fullName'] = _nameController.text.trim();
        } else {
          updateData['name'] = _nameController.text.trim();
        }

        await _firestore.collection(collection).doc(user.uid).set(updateData, SetOptions(merge: true));

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Profile Updated Successfully!")),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Update failed: $e")),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  static const Color backgroundNavy = Color(0xFF0A0E1A);
  static const Color cardNavy = Color(0xFF151B29);
  static const Color accentGold = Color(0xFFD4AF37);
  static const Color textGrey = Color(0xFFB0B0B0);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundNavy,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text("MY PROFILE", style: TextStyle(color: Colors.white, fontSize: 16, letterSpacing: 1.5)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: accentGold),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: accentGold))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(25),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // --- Profile Picture Section ---
                    Center(
                      child: Stack(
                        children: [
                          GestureDetector(
                            onTap: _pickImage,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(color: accentGold, shape: BoxShape.circle),
                              child: CircleAvatar(
                                radius: 60,
                                backgroundColor: cardNavy,
                                backgroundImage: _base64Image != null
                                    ? MemoryImage(base64Decode(_base64Image!))
                                    : null,
                                child: _base64Image == null
                                    ? const Icon(Icons.person, size: 60, color: Colors.white)
                                    : null,
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 4,
                            child: GestureDetector(
                              onTap: _pickImage,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(color: accentGold, shape: BoxShape.circle),
                                child: const Icon(Icons.edit, color: backgroundNavy, size: 20),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),

                    // --- Input Fields ---
                    _buildProfileField(
                      label: "Full Name",
                      controller: _nameController,
                      icon: Icons.person_outline,
                      validator: (val) => val!.isEmpty ? "Enter your name" : null,
                    ),
                    const SizedBox(height: 20),
                    _buildProfileField(
                      label: "Phone Number",
                      controller: _phoneController,
                      icon: Icons.phone_outlined,
                      hint: "03*********",
                      validator: (val) {
                        if (val == null || val.isEmpty) return "Enter phone number";
                        if (!RegExp(r'^03[0-9]{9}$').hasMatch(val)) {
                          return "Must start with 03 and be 11 digits";
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    _buildProfileField(
                      label: "ID Number (CNIC/Passport)",
                      controller: _idController,
                      icon: Icons.badge_outlined,
                      hint: "***** - ******* - *",
                      validator: (val) {
                        if (val == null || val.isEmpty) return "Enter ID number";
                        if (val.length < 14) return "Must be at least 14 characters";
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    _buildProfileField(
                      label: "Location",
                      controller: _locationController,
                      icon: Icons.location_on_outlined,
                      validator: (val) => val!.isEmpty ? "Enter location" : null,
                    ),

                    if (_userRole == 'lawyer') ...[
                      const SizedBox(height: 30),
                      _buildSignatureSection(),
                    ],

                    const SizedBox(height: 50),

                    // --- Action Buttons ---
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _updateProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentGold,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        ),
                        child: _isSaving
                            ? const CircularProgressIndicator(color: backgroundNavy)
                            : const Text("SAVE CHANGES", style: TextStyle(color: backgroundNavy, fontWeight: FontWeight.bold)),
                      ),
                    ),

                    const SizedBox(height: 20),

                    TextButton.icon(
                      onPressed: () async {
                        await FirebaseAuth.instance.signOut();
                        if (!context.mounted) return;
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (context) => const LoginScreen()),
                          (route) => false,
                        );
                      },
                      icon: const Icon(Icons.logout, color: Colors.redAccent),
                      label: const Text("Logout", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSignatureSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardNavy,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: accentGold.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.history_edu, color: accentGold),
              SizedBox(width: 10),
              Text(
                "DIGITAL SIGNATURE",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.2),
              ),
            ],
          ),
          const SizedBox(height: 15),
          const Text(
            "Set up your digital signature to automatically include it in Vakalatnama documents.",
            style: TextStyle(color: textGrey, fontSize: 12),
          ),
          const SizedBox(height: 20),
          if (_hasDigitalSignature && _digitalSignatureUrl != null)
            Column(
              children: [
                Container(
                  height: 100,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Image.network(
                    _digitalSignatureUrl!,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const Center(child: Icon(Icons.error, color: Colors.red)),
                  ),
                ),
                const SizedBox(height: 15),
              ],
            ),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SignatureScreen(
                      title: "Setup Profile Signature",
                      isProfileSetup: true,
                    ),
                  ),
                );
                if (result == true) {
                  _loadUserData();
                }
              },
              icon: Icon(_hasDigitalSignature ? Icons.edit : Icons.add, color: accentGold),
              label: Text(
                _hasDigitalSignature ? "UPDATE SIGNATURE" : "CREATE SIGNATURE",
                style: const TextStyle(color: accentGold),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: accentGold),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    String? hint,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: textGrey, fontSize: 13)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          validator: validator,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: accentGold, size: 22),
            hintText: hint,
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.2)),
            filled: true,
            fillColor: cardNavy,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: const BorderSide(color: accentGold, width: 1),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: const BorderSide(color: Colors.redAccent, width: 1),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: const BorderSide(color: Colors.redAccent, width: 2),
            ),
            errorStyle: const TextStyle(color: Colors.redAccent),
          ),
        ),
      ],
    );
  }
}
