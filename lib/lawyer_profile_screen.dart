import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_screen.dart';

class LawyerProfileScreen extends StatelessWidget {
  final Map<String, dynamic> lawyer;
  final String lawyerId;

  const LawyerProfileScreen({super.key, required this.lawyer, required this.lawyerId});

  static const Color navyBlue = Color(0xFF001F3F);
  static const Color accentGold = Color(0xFFD4AF37);

  String _safeString(dynamic value, {String defaultValue = "N/A"}) {
    if (value == null) return defaultValue;
    if (value is List) return value.join(", ");
    return value.toString();
  }

  @override
  Widget build(BuildContext context) {
    String name = _safeString(lawyer['fullName'] ?? lawyer['name'] ?? lawyer['organizationName'], defaultValue: "Advocate");
    String spec = _safeString(lawyer['specialization'], defaultValue: "Legal Expert");
    String exp = _safeString(lawyer['experience'], defaultValue: "5+ Years");
    String org = _safeString(lawyer['organizationName'] ?? lawyer['organization'], defaultValue: "Private Practice");
    String license = _safeString(lawyer['licenseType'], defaultValue: "High Court Advocate");
    String loc = _safeString(lawyer['province'] ?? lawyer['location'], defaultValue: "Not Specified");
    String email = _safeString(lawyer['email'], defaultValue: "Contact via App");
    String desc = _safeString(lawyer['description'] ?? lawyer['bio'],
        defaultValue: "Professional legal practitioner dedicated to providing top-tier legal services.");

    String? profilePic = lawyer['profilePicture'];
    ImageProvider? imageProvider;

    if (profilePic != null && profilePic.isNotEmpty) {
      try {
        imageProvider = MemoryImage(base64Decode(profilePic));
      } catch (e) {
        imageProvider = null;
      }
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: navyBlue,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  image: imageProvider != null
                      ? DecorationImage(image: imageProvider, fit: BoxFit.cover)
                      : null,
                  color: navyBlue,
                ),
                child: imageProvider == null
                    ? const Icon(Icons.person, size: 120, color: Colors.white54)
                    : null,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: navyBlue),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.verified, color: Colors.blue, size: 28),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    spec,
                    style: const TextStyle(fontSize: 18, color: accentGold, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 20),
                  _buildInfoRow(Icons.account_balance, "Organization", org),
                  _buildInfoRow(Icons.gavel, "License Type", license),
                  _buildInfoRow(Icons.work_history_outlined, "Experience", exp),
                  _buildInfoRow(Icons.location_on_outlined, "Province/Location", loc),
                  _buildInfoRow(Icons.email_outlined, "Contact", email),
                  const Divider(height: 40),
                  const Text("Professional Summary", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: navyBlue)),
                  const SizedBox(height: 10),
                  Text(desc, style: const TextStyle(fontSize: 16, color: Colors.black87, height: 1.5)),
                  const SizedBox(height: 30),
                  _buildRequestSection(context, name),
                  const SizedBox(height: 50),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestSection(BuildContext context, String lawyerName) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('consultation_request')
          .where('clientId', isEqualTo: uid)
          .where('lawyerId', isEqualTo: lawyerId)
          .snapshots(),
      builder: (context, consultSnapshot) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('suit_a_file_request')
              .where('clientId', isEqualTo: uid)
              .where('lawyerId', isEqualTo: lawyerId)
              .snapshots(),
          builder: (context, suitSnapshot) {
            if (consultSnapshot.connectionState == ConnectionState.waiting ||
                suitSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            bool isApproved = false;
            bool hasPending = false;

            List<DocumentSnapshot> allDocs = [];
            if (consultSnapshot.hasData) allDocs.addAll(consultSnapshot.data!.docs);
            if (suitSnapshot.hasData) allDocs.addAll(suitSnapshot.data!.docs);

            for (var doc in allDocs) {
              String status = (doc['status'] ?? '').toString().toLowerCase();
              if (['accepted', 'active', 'in progress', 'completed'].contains(status)) {
                isApproved = true;
              }
              if (status == 'pending') {
                hasPending = true;
              }
            }

            if (isApproved) {
              return SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _startChat(context, lawyerName),
                  icon: const Icon(Icons.chat_outlined),
                  label: const Text("MESSAGE NOW", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.1)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: navyBlue,
                    side: const BorderSide(color: navyBlue, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              );
            }

            return Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: hasPending ? null : () => _sendRequest(context, 'Consultation', lawyerName),
                    icon: Icon(hasPending ? Icons.hourglass_empty : Icons.chat_bubble_outline, size: 18),
                    label: Text(hasPending ? "Pending..." : "Consultation", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentGold,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: hasPending ? null : () => _sendRequest(context, 'File a Suit', lawyerName),
                    icon: Icon(hasPending ? Icons.hourglass_empty : Icons.gavel, size: 18),
                    label: Text(hasPending ? "Pending..." : "File a Suit", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: navyBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _sendRequest(BuildContext context, String type, String lawyerName) async {
    String? currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUserId).get();
      String clientName = _safeString((userDoc.data() as Map<String, dynamic>?)?['name'], defaultValue: "Client");

      String collectionName = type == 'Consultation' ? 'consultation_request' : 'suit_a_file_request';

      await FirebaseFirestore.instance.collection(collectionName).add({
        'clientId': currentUserId,
        'lawyerId': lawyerId,
        'status': 'Pending',
        'createdAt': FieldValue.serverTimestamp(),
        'clientName': clientName,
        'lawyerName': lawyerName,
        'type': type,
      });

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$type request sent!")));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  // FIXED START CHAT FUNCTION
  void _startChat(BuildContext context, String lawyerName) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    String? requestId;

    try {
      // Check for active requests to get the ID
      var consults = await FirebaseFirestore.instance
          .collection('consultation_request')
          .where('clientId', isEqualTo: uid)
          .where('lawyerId', isEqualTo: lawyerId)
          .get();
          
      var suits = await FirebaseFirestore.instance
          .collection('suit_a_file_request')
          .where('clientId', isEqualTo: uid)
          .where('lawyerId', isEqualTo: lawyerId)
          .get();

      List<DocumentSnapshot> all = [...consults.docs, ...suits.docs];
      
      // Look for the most relevant requestId (Accepted/Active ones first)
      for (var doc in all) {
        String status = (doc['status'] ?? '').toString().toLowerCase();
        if (['accepted', 'active', 'in progress'].contains(status)) {
          requestId = doc.id;
          break;
        }
      }
      
      // If no accepted one, just take the first one found or it will fallback to user_ids chat
      if (requestId == null && all.isNotEmpty) {
        requestId = all.first.id;
      }

      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              receiverName: lawyerName,
              receiverId: lawyerId,
              requestId: requestId,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint("Error finding requestId: $e");
    }
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: accentGold, size: 24),
          const SizedBox(width: 15),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
            Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: navyBlue)),
          ]),
        ],
      ),
    );
  }
}