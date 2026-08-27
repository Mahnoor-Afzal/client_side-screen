import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class CaseRequestsScreen extends StatefulWidget {
  const CaseRequestsScreen({super.key});

  @override
  State<CaseRequestsScreen> createState() => _CaseRequestsScreenState();
}

class _CaseRequestsScreenState extends State<CaseRequestsScreen> {
  final Color navyBlue = const Color(0xFF101D3D);
  final Color goldColor = const Color(0xFFC5A358);
  final String? currentLawyerId = FirebaseAuth.instance.currentUser?.uid;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text("Case Requests",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: navyBlue,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: currentLawyerId == null
          ? const Center(child: Text("Please login to see requests"))
          : StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('suit_a_file_request').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          var allDocs = snapshot.data?.docs ?? [];

          // Strictly filter by assigned lawyer
          var filteredDocs = allDocs.where((doc) {
            var data = doc.data() as Map<String, dynamic>;

            String lawyer = (data['lawyerid'] ?? data['lawyerId'] ?? data['lawyerUID'] ?? '')
                .toString()
                .trim();

            String status = (data['status'] ?? "pending")
                .toString()
                .toLowerCase()
                .trim();

            bool isStrictlyForThisLawyer = (lawyer == currentLawyerId);

            return isStrictlyForThisLawyer && status == 'pending';
          }).toList();

          if (filteredDocs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.assignment_turned_in_outlined,
                      size: 80, color: navyBlue.withAlpha(76)),
                  const SizedBox(height: 15),
                  const Text("No pending case requests found.",
                      style: TextStyle(
                          color: Colors.grey,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: filteredDocs.length,
            itemBuilder: (context, index) {
              var doc = filteredDocs[index];
              Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

              String clientName = (data['clientName'] ?? data['fullName'] ?? "Client").toString();
              String reqType = (data['type'] ?? "File a Suit").toString();

              // Checks ALL possible naming variations from Firestore
              String caseCategory = (data['caseCategory'] ?? data['category'] ?? data['case_category'] ?? "").toString().trim();
              String subCategory = (data['subCategory'] ?? data['subcategory'] ?? data['sub_category'] ?? "").toString().trim();
              String desc = (data['description'] ?? data['details'] ?? data['caseDetails'] ?? "").toString().trim();

              return Card(
                elevation: 4,
                margin: const EdgeInsets.only(bottom: 15),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              clientName,
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: navyBlue),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: goldColor.withAlpha(38),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: goldColor),
                            ),
                            child: Text(
                              reqType,
                              style: TextStyle(
                                  color: goldColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Screenshot 1 Chips Design
                      if (caseCategory.isNotEmpty || subCategory.isNotEmpty) ...[
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            if (caseCategory.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE8F0FE),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.gavel_outlined, size: 14, color: navyBlue),
                                    const SizedBox(width: 4),
                                    Text(
                                      caseCategory,
                                      style: TextStyle(
                                        color: navyBlue,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (subCategory.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFCE8E6),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.subdirectory_arrow_right, size: 14, color: Colors.deepOrange),
                                    const SizedBox(width: 4),
                                    Text(
                                      subCategory,
                                      style: const TextStyle(
                                        color: Colors.deepOrange,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],

                      const Divider(height: 15),

                      // Description Section
                      const Text(
                        "Description / Details:",
                        style: TextStyle(
                            color: Colors.grey,
                            fontWeight: FontWeight.bold,
                            fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        desc.isNotEmpty ? desc : "No description provided.",
                        style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 14,
                            height: 1.3),
                      ),
                      const SizedBox(height: 15),

                      // Action Buttons
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10))),
                              onPressed: () => _updateStatus(doc, 'accepted'),
                              child: const Text("Accept"),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.redAccent,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10))),
                              onPressed: () => _updateStatus(doc, 'rejected'),
                              child: const Text("Reject"),
                            ),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _updateStatus(DocumentSnapshot doc, String status) async {
    try {
      await doc.reference.set({
        'status': status == 'accepted' ? 'accepted' : 'rejected',
        'lawyerid': currentLawyerId,
        'lawyerId': currentLawyerId,
      }, SetOptions(merge: true));

      if (status == 'accepted') {
        var data = doc.data() as Map<String, dynamic>;
        String clientId = data['clientId'] ?? data['userId'] ?? "";
        String clientName = data['clientName'] ?? data['fullName'] ?? "Client";

        await FirebaseFirestore.instance.collection('chat').doc(doc.id).set({
          'requestId': doc.id,
          'lawyerid': currentLawyerId,
          'clientId': clientId,
          'clientName': clientName,
          'topic': data['type'] ?? 'Case Request',
          'status': 'Active',
          'type': 'case',
          'date': DateFormat('dd MMM yyyy').format(DateTime.now()),
          'time': TimeOfDay.now().format(context),
          'updatedAt': FieldValue.serverTimestamp(),
          'lastMessage': 'Case accepted. Chat started.',
          'users': [clientId, currentLawyerId],
        }, SetOptions(merge: true));

        if (clientId.isNotEmpty) {
          await FirebaseFirestore.instance.collection('notifications').add({
            'userId': clientId,
            'title': 'Request Accepted!',
            'body': 'Your request has been accepted. Communication is now open.',
            'type': 'chat_enabled',
            'requestId': doc.id,
            'timestamp': FieldValue.serverTimestamp(),
            'isRead': false,
          });
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text("Request Accepted! Added to Active Cases."),
              backgroundColor: Colors.green));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }
}