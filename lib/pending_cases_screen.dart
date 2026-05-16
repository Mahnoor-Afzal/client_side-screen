import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PendingCasesScreen extends StatelessWidget {
  const PendingCasesScreen({super.key});

  final Color navyBlue = const Color(0xFF101D3D);
  final Color goldColor = const Color(0xFFC5A358);

  @override
  Widget build(BuildContext context) {
    final String? uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text("Pending Requests", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: navyBlue,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: uid == null
          ? const Center(child: Text("Please login to see requests"))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('Case request')
                  .where('lawyerid', isEqualTo: uid)
                  .where('status', isEqualTo: 'pending')
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
                        Icon(Icons.hourglass_empty, size: 80, color: navyBlue.withOpacity(0.3)),
                        const SizedBox(height: 15),
                        const Text("No pending requests found.", style: TextStyle(color: Colors.grey)),
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

                    return Card(
                      elevation: 4,
                      margin: const EdgeInsets.only(bottom: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(backgroundColor: navyBlue, child: const Icon(Icons.person, color: Colors.white)),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(data['clientName'] ?? "Client",
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: navyBlue)),
                                ),
                              ],
                            ),
                            const Divider(height: 25),
                            Text("Type: ${data['caseType']}", style: const TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 5),
                            Text(data['description'] ?? "", style: const TextStyle(color: Colors.black87)),
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                                    onPressed: () => _updateStatus(context, doc.id, 'accepted'),
                                    child: const Text("Accept"),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                                    onPressed: () => _updateStatus(context, doc.id, 'rejected'),
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

  Future<void> _updateStatus(BuildContext context, String docId, String status) async {
    try {
      await FirebaseFirestore.instance.collection('Case request').doc(docId).update({'status': status});
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Request $status successfully!")));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }
}
