import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ClosedCasesScreen extends StatelessWidget {
  const ClosedCasesScreen({super.key});

  final Color navyBlue = const Color(0xFF101D3D);
  final Color goldColor = const Color(0xFFC5A358);

  @override
  Widget build(BuildContext context) {
    final String? uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text("Closed Cases", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: navyBlue,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: uid == null
          ? const Center(child: Text("Please login to see your cases"))
          : StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('suit_a_file_request').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          List<DocumentSnapshot> closedCases = [];
          if (snapshot.hasData) {
            closedCases = snapshot.data!.docs.where((doc) {
              var data = doc.data() as Map<String, dynamic>;
              String status = (data['status'] ?? "").toString().toLowerCase().trim();
              String leadId = (data['lawyerid'] ?? data['lawyerId'] ?? "").toString().trim();

              List assigned = data['assignedLawyers'] ?? [];
              bool isAssigned = (leadId == uid.trim()) || assigned.contains(uid.trim());

              return status == 'closed' && isAssigned;
            }).toList();
          }

          if (closedCases.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.archive_outlined, size: 70, color: Colors.grey[300]),
                  const SizedBox(height: 10),
                  const Text("No closed cases found", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: closedCases.length,
            itemBuilder: (context, index) {
              var doc = closedCases[index];
              var data = doc.data() as Map<String, dynamic>;
              String name = data['clientName'] ?? data['fullName'] ?? "Client";
              String type = data['caseType'] ?? data['title'] ?? "Matter";
              double rating = (data['rating'] ?? 0.0).toDouble();
              String review = data['review'] ?? "";

              return Card(
                elevation: 3,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(15),
                  leading: CircleAvatar(
                    backgroundColor: navyBlue.withOpacity(0.1),
                    child: Icon(Icons.check_circle, color: Colors.green),
                  ),
                  title: Text(name, style: TextStyle(fontWeight: FontWeight.bold, color: navyBlue)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(type, style: const TextStyle(fontSize: 13, color: Colors.black54)),
                      if (rating > 0) ...[
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            const Icon(Icons.star, color: Colors.amber, size: 16),
                            const SizedBox(width: 4),
                            Text("$rating", style: const TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                      if (review.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text("\"$review\"", style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                      ],
                    ],
                  ),
                  trailing: const Icon(Icons.chevron_right),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
