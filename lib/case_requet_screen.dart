import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
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
        title: const Text("New Requests", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: navyBlue,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: currentLawyerId == null
          ? const Center(child: Text("Please login to see requests"))
          : StreamBuilder<List<QuerySnapshot>>(
              stream: _getCombinedRequests(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                
                List<DocumentSnapshot> allDocs = [];
                if (snapshot.hasData) {
                  for (var snap in snapshot.data!) {
                    allDocs.addAll(snap.docs);
                  }
                }

                var filteredDocs = allDocs.where((doc) {
                  var data = doc.data() as Map<String, dynamic>;
                  String status = (data['status'] ?? "pending").toString().toLowerCase().trim();
                  if (status != 'pending') return false;

                  String lId = (data['lawyerid'] ?? data['lawyerId'] ?? "").toString().trim();
                  if (doc.reference.parent.id == 'suit_a_file_request') return true; 
                  return lId == currentLawyerId?.trim();
                }).toList();

                if (filteredDocs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.assignment_turned_in_outlined, size: 80, color: navyBlue.withOpacity(0.3)),
                        const SizedBox(height: 15),
                        const Text("No pending requests.", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
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

                    String clientName = data['clientName'] ?? data['fullName'] ?? "Client";
                    String caseType = data['caseType'] ?? data['title'] ?? "Legal Matter";

                    return Card(
                      elevation: 4,
                      margin: const EdgeInsets.only(bottom: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(clientName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: navyBlue)),
                            const SizedBox(height: 5),
                            Text("Type: $caseType", style: TextStyle(color: goldColor, fontWeight: FontWeight.w600)),
                            const Divider(height: 20),
                            Text(data['description'] ?? data['body'] ?? "New request received."),
                            const SizedBox(height: 15),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                                    onPressed: () => _updateStatus(doc, 'accepted'),
                                    child: const Text("Accept"),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
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

  Stream<List<QuerySnapshot>> _getCombinedRequests() {
    StreamController<List<QuerySnapshot>> controller = StreamController();
    StreamSubscription? s1; StreamSubscription? s2;
    QuerySnapshot? q1; QuerySnapshot? q2;

    void update() {
      if (!controller.isClosed) {
        List<QuerySnapshot> results = [];
        if (q1 != null) results.add(q1!);
        if (q2 != null) results.add(q2!);
        if (results.isNotEmpty) controller.add(results);
      }
    }
    s1 = FirebaseFirestore.instance.collection('Case request').snapshots().listen((s) { q1 = s; update(); });
    s2 = FirebaseFirestore.instance.collection('suit_a_file_request').snapshots().listen((s) { q2 = s; update(); });
    controller.onCancel = () { s1?.cancel(); s2?.cancel(); controller.close(); };
    return controller.stream;
  }

  Future<void> _updateStatus(DocumentSnapshot doc, String status) async {
    try {
      await doc.reference.set({
        'status': status,
        'lawyerid': currentLawyerId,
      }, SetOptions(merge: true));

      if (status == 'accepted') {
        var data = doc.data() as Map<String, dynamic>;
        String clientId = data['clientId'] ?? data['userId'] ?? "";
        String clientName = data['clientName'] ?? data['fullName'] ?? "Client";

        // Create 'chat' entry with type 'case' to keep it separate from consultations
        await FirebaseFirestore.instance.collection('chat').doc(doc.id).set({
          'requestId': doc.id,
          'lawyerid': currentLawyerId, 
          'clientId': clientId,
          'clientName': clientName,
          'topic': data['caseType'] ?? data['title'] ?? 'Legal Matter',
          'status': 'Active',
          'type': 'case', // Strictly marked as case
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
            'body': 'Your legal request has been accepted. Communication is now open.',
            'type': 'chat_enabled',
            'requestId': doc.id,
            'timestamp': FieldValue.serverTimestamp(),
            'isRead': false,
          });
        }
        
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Case Accepted! Added to Active Cases."), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }
}
