import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  final Color navyBlue = const Color(0xFF101D3D);
  final Color goldColor = const Color(0xFFC5A358);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text("Admin Panel - Lawyer Requests", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: navyBlue,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('admin_requests')
            .where('status', isEqualTo: 'pending')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No pending verification requests."));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var doc = snapshot.data!.docs[index];
              var data = doc.data() as Map<String, dynamic>;

              return Card(
                elevation: 4,
                margin: const EdgeInsets.only(bottom: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(data['fullName'] ?? "New Lawyer", 
                           style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: navyBlue)),
                      const SizedBox(height: 5),
                      Text("Email: ${data['email'] ?? 'N/A'}", style: const TextStyle(color: Colors.grey)),
                      const Divider(height: 25),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                              onPressed: () => _handleRequest(doc.id, data['lawyerId'], true, context),
                              child: const Text("ACCEPT"),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                              onPressed: () => _handleRequest(doc.id, data['lawyerId'], false, context),
                              child: const Text("REJECT"),
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

  Future<void> _handleRequest(String requestId, String lawyerId, bool isAccepted, BuildContext context) async {
    try {
      if (isAccepted) {
        // Verify the lawyer in their main document
        await FirebaseFirestore.instance.collection('lawyers').doc(lawyerId).update({
          'isVerified': true,
        });
      }

      // Update the request status
      await FirebaseFirestore.instance.collection('admin_requests').doc(requestId).update({
        'status': isAccepted ? 'accepted' : 'rejected',
        'processedAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isAccepted ? "Lawyer Verified!" : "Request Rejected"), backgroundColor: isAccepted ? Colors.green : Colors.red),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }
}
