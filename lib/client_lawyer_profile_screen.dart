import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'client_chat_screen.dart';
import 'client_dashboard.dart';

import 'client_notification_helper.dart';

class LawyerProfileScreen extends StatefulWidget {
  final Map<String, dynamic> lawyer;
  final String lawyerId;

  const LawyerProfileScreen({super.key, required this.lawyer, required this.lawyerId});

  @override
  State<LawyerProfileScreen> createState() => _LawyerProfileScreenState();
}

class _LawyerProfileScreenState extends State<LawyerProfileScreen> {
  static const Color navyBlue = Color(0xFF001F3F);
  static const Color accentGold = Color(0xFFD4AF37);
  bool _showSuccess = false;

  String _safeString(dynamic value, {String defaultValue = "N/A"}) {
    if (value == null) return defaultValue;
    if (value is List) return value.join(", ");
    return value.toString();
  }

  @override
  Widget build(BuildContext context) {
    if (_showSuccess) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: const Text("CASE SUBMITTED", style: TextStyle(color: navyBlue, fontSize: 16, fontWeight: FontWeight.bold)),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: navyBlue),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: _buildSuccessView(context),
      );
    }
    String name = _safeString(widget.lawyer['fullName'] ?? widget.lawyer['name'] ?? widget.lawyer['organizationName'], defaultValue: "Advocate");
    String spec = _safeString(widget.lawyer['specialization'], defaultValue: "Legal Expert");
    String exp = _safeString(widget.lawyer['experience'], defaultValue: "5+ Years");
    String org = _safeString(widget.lawyer['organizationName'] ?? widget.lawyer['organization'], defaultValue: "Private Practice");
    String license = _safeString(widget.lawyer['licenseType'], defaultValue: "High Court Advocate");
    String loc = _safeString(widget.lawyer['province'] ?? widget.lawyer['location'], defaultValue: "Not Specified");
    String email = _safeString(widget.lawyer['email'], defaultValue: "Contact via App");
    String desc = _safeString(widget.lawyer['description'] ?? widget.lawyer['bio'],
        defaultValue: "Professional legal practitioner dedicated to providing top-tier legal services.");

    // Enhanced image detection logic for Profile Screen
    dynamic profilePicData = widget.lawyer['profilePicture'] ?? 
                             widget.lawyer['imageUrl'] ?? 
                             widget.lawyer['profileImageUrl'] ??
                             widget.lawyer['profile_pic'] ??
                             widget.lawyer['profilePic'] ??
                             widget.lawyer['profile_picture'] ??
                             widget.lawyer['image'] ?? 
                             widget.lawyer['photoUrl'] ??
                             widget.lawyer['profile_image'];
    
    ImageProvider? imageProvider;
    if (profilePicData != null) {
      if (profilePicData is String && profilePicData.trim().isNotEmpty) {
        String imgStr = profilePicData.trim();
        if (imgStr.startsWith('http')) {
          imageProvider = NetworkImage(imgStr);
        } else {
          try {
            // Clean Base64 prefix and remove whitespace
            String cleanBase64 = imgStr.contains(',') ? imgStr.split(',').last : imgStr;
            cleanBase64 = cleanBase64.replaceAll(RegExp(r'\s+'), '');
            
            // Fix padding if needed
            int padLength = cleanBase64.length % 4;
            if (padLength > 0) {
              cleanBase64 += '=' * (4 - padLength);
            }
            
            imageProvider = MemoryImage(base64Decode(cleanBase64));
          } catch (e) {
            debugPrint("Failed to decode image for Profile: $e");
          }
        }
      } else if (profilePicData is Uint8List) {
        imageProvider = MemoryImage(profilePicData);
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: navyBlue,
            iconTheme: const IconThemeData(color: accentGold),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  image: imageProvider != null
                      ? DecorationImage(image: imageProvider, fit: BoxFit.cover)
                      : null,
                  color: navyBlue,
                ),
                child: imageProvider == null
                    ? Icon(Icons.person, size: 120, color: Colors.white.withValues(alpha: 0.3))
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
                  Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 24),
                      const SizedBox(width: 5),
                      Text(
                        (double.tryParse((widget.lawyer['rating'] ?? '0').toString()) ?? 0.0).toStringAsFixed(1),
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: navyBlue),
                      ),
                      Text(
                        " (${widget.lawyer['reviewCount'] ?? '0'} Engaged Clients)",
                        style: const TextStyle(fontSize: 16, color: Colors.grey),
                      ),
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
          .where('lawyerId', isEqualTo: widget.lawyerId)
          .snapshots(),
      builder: (context, consultSnapshot) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('suit_a_file_request')
              .where('clientId', isEqualTo: uid)
              .where('lawyerId', isEqualTo: widget.lawyerId)
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

            return Column(
              children: [
                if (hasPending)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8.0),
                    child: Text("You already have a pending request with this lawyer.",
                        style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.w500)),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: hasPending ? null : () => _sendRequest(context, 'Consultation', lawyerName),
                        icon: Icon(hasPending ? Icons.hourglass_empty : Icons.chat_bubble_outline, size: 18),
                        label: Text(hasPending ? "Pending..." : "Consultation", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: hasPending ? Colors.grey : accentGold,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: hasPending
                            ? null
                            : () => _sendRequest(context, 'File a Suit', lawyerName),
                        icon: Icon(hasPending ? Icons.hourglass_empty : Icons.gavel, size: 18),
                        label: Text(hasPending ? "Pending..." : "File a Suit", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: hasPending ? Colors.grey : navyBlue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
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
        'lawyerId': widget.lawyerId,
        'status': 'Pending',
        'createdAt': FieldValue.serverTimestamp(),
        'clientName': clientName,
        'lawyerName': lawyerName,
        'type': type,
        'isDirectRequest': true,
      });

      // Send Push Notification via NotificationHelper
      DocumentSnapshot lawyerDoc = await FirebaseFirestore.instance.collection('verified_lawyers').doc(widget.lawyerId).get();
      String? fcmToken = (lawyerDoc.data() as Map<String, dynamic>?)?['fcmToken'];
      if (fcmToken != null && fcmToken.isNotEmpty) {
        await NotificationHelper.sendGlobalPushNotification(
          token: fcmToken,
          title: "New $type Request",
          body: "$clientName has sent you a $type request.",
          data: {
            'click_action': 'FLUTTER_NOTIFICATION_CLICK',
            'type': 'request_received',
          },
        );
      }

      if (context.mounted) {
        setState(() {
          _showSuccess = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$type request sent!")));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
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
          .where('lawyerId', isEqualTo: widget.lawyerId)
          .get();
          
      var suits = await FirebaseFirestore.instance
          .collection('suit_a_file_request')
          .where('clientId', isEqualTo: uid)
          .where('lawyerId', isEqualTo: widget.lawyerId)
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
        // Find if a direct chat already exists to use its collection path and ID
        List<String> ids = [uid!, widget.lawyerId];
        ids.sort();
        String chatId = ids.join("_");

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              receiverName: lawyerName,
              receiverId: widget.lawyerId,
              requestId: requestId,
              chatId: chatId,
              collectionPath: 'chat',
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

  Widget _buildSuccessView(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 100),
            const SizedBox(height: 20),
            const Text(
              "Case Submitted!",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: navyBlue),
            ),
            const SizedBox(height: 10),
            const Text(
              "Your case has been successfully registered. Now you can find a legal expert to help you.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context); // Go back to Lawyer List
                },
                icon: const Icon(Icons.search, color: Colors.white),
                label: const Text("SEARCH LAWYER", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentGold,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const DashboardScreen()),
                  (route) => false,
                );
              },
              child: const Text(
                "Go Back to Dashboard",
                style: TextStyle(color: navyBlue, fontWeight: FontWeight.w600),
              ),
            )
          ],
        ),
      ),
    );
  }
}
