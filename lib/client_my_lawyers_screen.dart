import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'client_lawyer_profile_screen.dart';

class MyLawyersScreen extends StatelessWidget {
  const MyLawyersScreen({super.key});

  String _safeString(dynamic value, {String defaultValue = ""}) {
    if (value == null) return defaultValue;
    if (value is List) return value.join(", ");
    return value.toString();
  }

  Widget _buildStatusChip(String status) {
    Color color;
    switch (status) {
      case 'Active':
      case 'Accepted':
      case 'In Progress':
        color = Colors.green;
        break;
      case 'Rejected':
        color = Colors.red;
        break;
      default:
        color = Colors.orange;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        status,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color navyBlue = Color(0xFF001F3F);
    const Color gold = Color(0xFFD4AF37);
    final String? uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: navyBlue,
        title: const Text("My Lawyers", style: TextStyle(color: gold, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: gold),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('consultation_request')
            .where('clientId', isEqualTo: uid)
            .snapshots(),
        builder: (context, consultSnapshot) {
          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('suit_a_file_request')
                .where('clientId', isEqualTo: uid)
                .snapshots(),
            builder: (context, suitSnapshot) {
              if (consultSnapshot.connectionState == ConnectionState.waiting ||
                  suitSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: navyBlue));
              }

              List<QueryDocumentSnapshot> allRequests = [];
              if (consultSnapshot.hasData) allRequests.addAll(consultSnapshot.data!.docs);
              if (suitSnapshot.hasData) allRequests.addAll(suitSnapshot.data!.docs);

              if (allRequests.isEmpty) {
                return _buildEmptyState(navyBlue);
              }

              // Map lawyerId to their "best" current status
              Map<String, String> lawyerStatuses = {};
              for (var doc in allRequests) {
                final data = doc.data() as Map<String, dynamic>;
                String? lId = data['lawyerId'];
                String status = data['status'] ?? 'Pending';
                
                if (lId != null) {
                  if (!lawyerStatuses.containsKey(lId)) {
                    lawyerStatuses[lId] = status;
                  } else {
                    List<String> priority = ['Active', 'In Progress', 'Accepted', 'Pending', 'Rejected'];
                    int currentPrio = priority.indexOf(status);
                    int existingPrio = priority.indexOf(lawyerStatuses[lId]!);
                    if (currentPrio >= 0 && (existingPrio < 0 || currentPrio < existingPrio)) {
                      lawyerStatuses[lId] = status;
                    }
                  }
                }
              }

              List<String> lawyerIds = lawyerStatuses.keys.toList();

              if (lawyerIds.isEmpty) {
                return _buildEmptyState(navyBlue);
              }

              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('verified_lawyers')
                    .where(FieldPath.documentId, whereIn: lawyerIds)
                    .snapshots(),
                builder: (context, userSnapshot) {
                  if (userSnapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: navyBlue));
                  }

                  if (!userSnapshot.hasData || userSnapshot.data!.docs.isEmpty) {
                    return _buildEmptyState(navyBlue);
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
                    itemCount: userSnapshot.data!.docs.length,
                    itemBuilder: (context, index) {
                      var doc = userSnapshot.data!.docs[index];
                      var lawyer = doc.data() as Map<String, dynamic>;
                      String lawyerId = doc.id;
                      String status = lawyerStatuses[lawyerId] ?? 'Pending';
                      
                      String name = _safeString(lawyer['fullName'] ?? lawyer['name'] ?? lawyer['organizationName'], defaultValue: "Advocate");
                      String spec = _safeString(lawyer['specialization'], defaultValue: "Legal Expert");
                      
                      // Robust image detection logic matching LawyerListScreen
                      dynamic profilePicData = lawyer['profilePicture'] ?? 
                                               lawyer['profile_picture'] ??
                                               lawyer['profileImage'] ??
                                               lawyer['profile_image'] ??
                                               lawyer['profilePic'] ??
                                               lawyer['profile_pic'] ??
                                               lawyer['profileImageUrl'] ??
                                               lawyer['imageUrl'] ?? 
                                               lawyer['image'] ?? 
                                               lawyer['photoUrl'] ??
                                               lawyer['avatar'];
                      
                      ImageProvider? imageProvider;
                      if (profilePicData != null) {
                        if (profilePicData is String && profilePicData.trim().isNotEmpty) {
                          String imgStr = profilePicData.trim();
                          if (imgStr.startsWith('http')) {
                            imageProvider = NetworkImage(imgStr);
                          } else {
                            try {
                              String cleanBase64 = imgStr.contains(',') ? imgStr.split(',').last : imgStr;
                              cleanBase64 = cleanBase64.replaceAll(RegExp(r'\s+'), '');
                              int padLength = cleanBase64.length % 4;
                              if (padLength > 0) cleanBase64 += '=' * (4 - padLength);
                              imageProvider = MemoryImage(base64Decode(cleanBase64));
                            } catch (e) {
                              debugPrint("Failed to decode image: $e");
                            }
                          }
                        } else if (profilePicData is Uint8List) {
                          imageProvider = MemoryImage(profilePicData);
                        }
                      }

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => LawyerProfileScreen(lawyer: lawyer, lawyerId: lawyerId),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 30,
                                  backgroundColor: navyBlue.withValues(alpha: 0.05),
                                  backgroundImage: imageProvider,
                                  child: imageProvider == null 
                                      ? const Icon(Icons.person, color: navyBlue, size: 30) 
                                      : null,
                                ),
                                const SizedBox(width: 15),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              name,
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: navyBlue),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          _buildStatusChip(status),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        spec,
                                        style: const TextStyle(color: gold, fontSize: 13, fontWeight: FontWeight.w600),
                                      ),
                                      const SizedBox(height: 4),
                                      const Text(
                                        "Tap to view profile and chat",
                                        style: TextStyle(color: Colors.grey, fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(Color navyBlue) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_search_rounded, size: 80, color: navyBlue.withValues(alpha: 0.1)),
          const SizedBox(height: 16),
          const Text(
            "No lawyers contacted yet",
            style: TextStyle(color: Colors.grey, fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          const Text(
            "Send a request to see them here.",
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
