import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'lawyer_profile_screen.dart';

class LawyerListScreen extends StatefulWidget {
  final String? specializationFilter;
  final Map<String, dynamic>? aiAnalysis;

  const LawyerListScreen({super.key, this.specializationFilter, this.aiAnalysis});

  @override
  State<LawyerListScreen> createState() => _LawyerListScreenState();
}

class _LawyerListScreenState extends State<LawyerListScreen> {
  static const Color navyBlue = Color(0xFF001F3F);
  static const Color accentGold = Color(0xFFD4AF37);
  
  late TextEditingController _searchController;
  late String _searchQuery;

  @override
  void initState() {
    super.initState();
    _searchQuery = widget.specializationFilter ?? "";
    _searchController = TextEditingController(text: _searchQuery);
  }
  String _safeString(dynamic value, {String defaultValue = ""}) {
    if (value == null) return defaultValue;
    if (value is List) return value.join(", ");
    return value.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        backgroundColor: navyBlue,
        elevation: 0,
        title: const Text("Legal Experts", style: TextStyle(color: accentGold, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: accentGold),
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('verified_lawyers')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: navyBlue));
                }

                if (snapshot.hasError) {
                  return Center(child: Text("Error: ${snapshot.error}"));
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildEmptyState();
                }

                var filteredLawyers = snapshot.data!.docs.where((doc) {
                  var data = doc.data() as Map<String, dynamic>;
                  // Search in name or organization
                  String name = _safeString(data['fullName'] ?? data['name'] ?? data['organizationName']).toLowerCase();
                  String spec = _safeString(data['specialization']).toLowerCase();
                  return name.contains(_searchQuery.toLowerCase()) || spec.contains(_searchQuery.toLowerCase());
                }).toList();

                if (filteredLawyers.isEmpty) {
                  return _buildEmptyState();
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  itemCount: filteredLawyers.length,
                  itemBuilder: (context, index) {
                    var doc = filteredLawyers[index];
                    var lawyerData = doc.data() as Map<String, dynamic>;
                    return _buildLawyerCard(lawyerData, doc.id);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(15),
      color: navyBlue,
      child: TextField(
        controller: _searchController,
        style: const TextStyle(color: Colors.white),
        onChanged: (value) => setState(() => _searchQuery = value),
        decoration: InputDecoration(
          hintText: "Search by name or specialization...",
          hintStyle: const TextStyle(color: Colors.white54),
          prefixIcon: const Icon(Icons.search, color: accentGold),
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.1),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
        ),
      ),
    );
  }

  Widget _buildLawyerCard(Map<String, dynamic> lawyer, String lawyerId) {
    // Debugging: This will print the exact data from Firestore in your console
    debugPrint("Lawyer Data for $lawyerId: $lawyer");

    // Using field names seen in your Firestore screenshot
    String name = _safeString(lawyer['fullName'] ?? lawyer['name'] ?? lawyer['organizationName'], defaultValue: "Advocate");
    String spec = _safeString(lawyer['specialization'], defaultValue: "Legal Expert");
    String exp = _safeString(lawyer['experience'], defaultValue: "0");
    String org = _safeString(lawyer['organizationName'] ?? lawyer['organization'], defaultValue: "Independent Practice");
    String license = _safeString(lawyer['licenseType'], defaultValue: "Advocate");
    String province = _safeString(lawyer['province'], defaultValue: "Location N/A");
    String description = _safeString(lawyer['description'] ?? lawyer['bio'], defaultValue: "Expert legal practitioner providing professional services.");

    dynamic profilePicData = lawyer['profilePicture'];
    ImageProvider? imageProvider;
    if (profilePicData is String && profilePicData.isNotEmpty) {
      try {
        imageProvider = MemoryImage(base64Decode(profilePicData));
      } catch (e) {
        debugPrint("Image decode error: $e");
      }
    }
    
    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 35,
                  backgroundColor: navyBlue.withValues(alpha: 0.1),
                  backgroundImage: imageProvider,
                  child: imageProvider == null ? const Icon(Icons.person, size: 40, color: navyBlue) : null,
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: navyBlue),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.verified, color: Colors.blue, size: 18),
                        ],
                      ),
                      Text(spec, style: const TextStyle(color: accentGold, fontWeight: FontWeight.w600, fontSize: 14)),
                      const SizedBox(height: 4),
                      Text(org, style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildInfoChip(Icons.gavel, license),
                const SizedBox(width: 8),
                _buildInfoChip(Icons.location_on, province),
                const SizedBox(width: 8),
                _buildInfoChip(Icons.history, "$exp Years Exp"),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.black87.withValues(alpha: 0.7), fontSize: 13, height: 1.4),
            ),
            const Divider(height: 30),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _handleRequest(lawyerId, name, "Consultation"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentGold,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    child: const Text("Consultation", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _handleRequest(lawyerId, name, "File a Suit"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: navyBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    child: const Text("File a Suit", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => LawyerProfileScreen(lawyer: lawyer, lawyerId: lawyerId)));
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: navyBlue,
                  side: const BorderSide(color: navyBlue),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text("View Full Profile"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: navyBlue),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 12, color: navyBlue, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  void _handleRequest(String lawyerId, String lawyerName, String type) async {
    String? currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUserId).get();
      String clientName = _safeString((userDoc.data() as Map<String, dynamic>?)?['name'], defaultValue: "Client");

      String collectionName = type == 'Consultation' ? 'consultation_request' : 'suit_a_file_request';

      // 1. Create the Request in specific collection
      DocumentReference requestRef = await FirebaseFirestore.instance.collection(collectionName).add({
        'clientId': currentUserId,
        'lawyerId': lawyerId,
        'status': 'Pending',
        'createdAt': FieldValue.serverTimestamp(),
        'clientName': clientName,
        'lawyerName': lawyerName,
        'type': type,
        'aiAnalysis': widget.aiAnalysis, // AI Summary included here
      });

      // 2. Send Notification to Lawyer (Firestore entry for Dashboard)
      await FirebaseFirestore.instance.collection('notifications').add({
        'userId': lawyerId,
        'title': 'New $type Request',
        'body': '$clientName has sent you a $type request with AI Analysis.',
        'createdAt': FieldValue.serverTimestamp(),
        'requestId': requestRef.id,
        'requestCollection': collectionName,
        'type': 'request_received',
        'isRead': false,
      });

      // 3. Push Notification (FCM) agar user ne set kiya ho toh
      DocumentSnapshot lawyerDoc = await FirebaseFirestore.instance.collection('verified_lawyers').doc(lawyerId).get();
      String? fcmToken = (lawyerDoc.data() as Map<String, dynamic>?)?['fcmToken'];
      if (fcmToken != null) {
        // Aapka existing sendPushNotification function yahan call ho sakta hai
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Request sent to $lawyerName"), backgroundColor: Colors.green));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_search, size: 80, color: navyBlue.withValues(alpha: 0.2)),
          const SizedBox(height: 20),
          const Text("No verified lawyers found", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: navyBlue)),
          const SizedBox(height: 10),
          const Text("Check back later or try a different search.", style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}
