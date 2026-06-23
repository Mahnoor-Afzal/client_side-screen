import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_screen.dart';

class CoordinationScreen extends StatelessWidget {
  const CoordinationScreen({super.key});

  final Color navyBlue = const Color(0xFF101D3D);
  final Color goldColor = const Color(0xFFC5A358);

  @override
  Widget build(BuildContext context) {
    final String? uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text("Lawyer Coordination", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: navyBlue,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: uid == null
          ? const Center(child: Text("Please login to see coordination data"))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('coordination')
                  .where('assignedLawyers', arrayContains: uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.group_off_outlined, size: 70, color: Colors.grey[300]),
                        const SizedBox(height: 10),
                        const Text("No active coordination found", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    var doc = snapshot.data!.docs[index];
                    var data = doc.data() as Map<String, dynamic>;
                    
                    return _buildCoordinationCard(context, doc.id, data);
                  },
                );
              },
            ),
    );
  }

  Widget _buildCoordinationCard(BuildContext context, String docId, Map<String, dynamic> data) {
    String clientName = data['clientName'] ?? "Client";
    String caseType = data['caseType'] ?? "Legal Matter";
    List assignedLawyers = data['assignedLawyers'] ?? [];
    String leadLawyerId = data['leadLawyerId'] ?? "";
    String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? "";

    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(clientName, style: TextStyle(fontWeight: FontWeight.bold, color: navyBlue, fontSize: 18)),
                      Text(caseType, style: const TextStyle(fontSize: 14, color: Colors.black54)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: goldColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    leadLawyerId == currentUserId ? "Lead Lawyer" : "Associate",
                    style: TextStyle(color: goldColor, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const Divider(height: 25),
            const Text("Team Members:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87)),
            const SizedBox(height: 8),
            
            // FutureBuilder to fetch lawyer names
            FutureBuilder<QuerySnapshot>(
              future: FirebaseFirestore.instance
                  .collection('lawyers')
                  .where(FieldPath.documentId, whereIn: assignedLawyers)
                  .get(),
              builder: (context, lawyerSnap) {
                if (!lawyerSnap.hasData) return const SizedBox(height: 20, child: LinearProgressIndicator());
                
                var names = lawyerSnap.data!.docs.map((d) => d.get('fullName') ?? "Lawyer").toList();
                
                return Wrap(
                  spacing: 6,
                  children: names.map((name) => Chip(
                    label: Text(name, style: const TextStyle(fontSize: 11)),
                    backgroundColor: Colors.blue.withOpacity(0.05),
                    avatar: const Icon(Icons.person, size: 14),
                  )).toList(),
                );
              },
            ),
            
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChatScreen(
                        consultationId: data['requestId'] ?? docId,
                        clientName: clientName,
                        clientId: data['clientId'],
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.forum_outlined, size: 18, color: Colors.white),
                label: const Text("Team Chat", style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: navyBlue,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
