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
  String searchQuery = "";
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

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
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      setState(() {
                        searchQuery = value.toLowerCase();
                      });
                    },
                    decoration: InputDecoration(
                      hintText: "Search by client name or category...",
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    ),
                  ),
                ),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('suit_a_file_request').snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(child: Text("Error: ${snapshot.error}"));
                      }
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      var allDocs = snapshot.data?.docs ?? [];

                      // Strictly filter by assigned lawyer and search query
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
                        if (!isStrictlyForThisLawyer || status != 'pending') return false;

                        // Search Filter
                        String clientName = (data['clientName'] ?? data['fullName'] ?? "").toString().toLowerCase();
                        String caseCategory = (data['caseCategory'] ?? data['category'] ?? "").toString().toLowerCase();
                        String subCategory = (data['subCategory'] ?? data['subcategory'] ?? "").toString().toLowerCase();

                        return clientName.contains(searchQuery) ||
                            caseCategory.contains(searchQuery) ||
                            subCategory.contains(searchQuery);
                      }).toList();

                      if (filteredDocs.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.assignment_turned_in_outlined,
                                  size: 80, color: navyBlue.withValues(alpha: 0.3)),
                              const SizedBox(height: 15),
                              Text(
                                  searchQuery.isEmpty ? "No pending case requests found." : "No results for \"$searchQuery\"",
                                  style: const TextStyle(
                                      color: Colors.grey,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: filteredDocs.length,
                        itemBuilder: (context, index) {
                          var doc = filteredDocs[index];
                          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

                          String clientName = (data['clientName'] ?? data['fullName'] ?? "Client").toString();
                          String reqType = (data['type'] ?? "File a Suit").toString();

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
                                          color: goldColor.withValues(alpha: 0.15),
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

                                  if (data['aiAnalysis'] != null) ...[
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      margin: const EdgeInsets.only(bottom: 12),
                                      decoration: BoxDecoration(
                                        color: Colors.purple.withValues(alpha: 0.05),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: Colors.purple.withValues(alpha: 0.2)),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              const Icon(Icons.auto_awesome, color: Colors.purple, size: 18),
                                              const SizedBox(width: 8),
                                              Text(
                                                "AI Analysis Report",
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.purple.shade700,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            "Summary: ${data['aiAnalysis']['reason'] ?? 'N/A'}",
                                            style: const TextStyle(fontSize: 13, color: Colors.black87),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            "Suggested Type: ${data['aiAnalysis']['case_type'] ?? 'N/A'}",
                                            style: const TextStyle(fontSize: 12, color: Colors.black54, fontStyle: FontStyle.italic),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],

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
                ),
              ],
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
