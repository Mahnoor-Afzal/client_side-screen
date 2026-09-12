import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PendingCasesScreen extends StatefulWidget {
  const PendingCasesScreen({super.key});

  @override
  State<PendingCasesScreen> createState() => _PendingCasesScreenState();
}

class _PendingCasesScreenState extends State<PendingCasesScreen> {
  final Color navyBlue = const Color(0xFF101D3D);
  final Color goldColor = const Color(0xFFC5A358);

  Stream<List<Map<String, dynamic>>> _getAllPendingRequestsStream(String uid) {
    late StreamController<List<Map<String, dynamic>>> controller;
    StreamSubscription? sub1, sub2, sub3;
    QuerySnapshot? snap1, snap2, snap3;

    void updateCombinedData() {
      if (!controller.isClosed) {
        List<Map<String, dynamic>> allRequests = [];

        void extractDocs(QuerySnapshot? snapshot, String collectionName) {
          if (snapshot == null) return;
          for (var doc in snapshot.docs) {
            var data = doc.data() as Map<String, dynamic>?;
            if (data == null) continue;

            String lawyer = (data['lawyerId'] ?? data['lawyerid'] ?? data['lawyerUID'] ?? '').toString().trim();
            String status = (data['status'] ?? 'pending').toString().toLowerCase().trim();

            if (lawyer == uid && (status == 'pending' || status.isEmpty)) {
              Map<String, dynamic> item = Map<String, dynamic>.from(data);
              item['docId'] = doc.id;
              item['collectionName'] = collectionName;
              allRequests.add(item);
            }
          }
        }

        // 1. Suit / Case Filing Requests
        extractDocs(snap1, 'suit_a_file_request');
        // 2. Generic Case Requests
        extractDocs(snap2, 'Case request');
        // 3. Consultation Requests
        extractDocs(snap3, 'consultation_request');

        controller.add(allRequests);
      }
    }

    controller = StreamController<List<Map<String, dynamic>>>(
      onListen: () {
        sub1 = FirebaseFirestore.instance.collection('suit_a_file_request').snapshots().listen((s) { snap1 = s; updateCombinedData(); });
        sub2 = FirebaseFirestore.instance.collection('Case request').snapshots().listen((s) { snap2 = s; updateCombinedData(); });
        sub3 = FirebaseFirestore.instance.collection('consultation_request').snapshots().listen((s) { snap3 = s; updateCombinedData(); });
      },
      onCancel: () {
        sub1?.cancel();
        sub2?.cancel();
        sub3?.cancel();
        controller.close();
      },
    );

    return controller.stream;
  }

  Future<void> _updateStatus(BuildContext context, String collection, String docId, String status) async {
    try {
      await FirebaseFirestore.instance.collection(collection).doc(docId).update({'status': status});
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Request $status successfully!")),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    }
  }

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
          : StreamBuilder<List<Map<String, dynamic>>>(
        stream: _getAllPendingRequestsStream(uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final requests = snapshot.data ?? [];

          if (requests.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.hourglass_empty, size: 80, color: navyBlue.withValues(alpha: 0.3)),
                  const SizedBox(height: 15),
                  const Text("No pending requests found.", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: requests.length,
            itemBuilder: (context, index) {
              var data = requests[index];

              String docId = data['docId'];
              String collection = data['collectionName'];

              String clientName = data['clientName'] ??
                  data['fullName'] ??
                  data['fullname'] ??
                  data['userName'] ??
                  data['name'] ??
                  "Client";

              // Correct Type Logic for Both Cases and Consultation
              String reqType = collection == 'consultation_request'
                  ? "Consultation Request"
                  : (data['caseType'] ?? data['type'] ?? data['requestType'] ?? "Case Request");

              String desc = data['description'] ??
                  data['details'] ??
                  data['caseDescription'] ??
                  "New request received.";

              return Card(
                elevation: 4,
                margin: const EdgeInsets.only(bottom: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        clientName,
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: navyBlue),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "Type: $reqType",
                        style: TextStyle(color: goldColor, fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const Divider(height: 20),
                      Text(
                        desc,
                        style: const TextStyle(color: Colors.black87, fontSize: 14),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: () => _updateStatus(context, collection, docId, 'accepted'),
                              child: const Text("Accept"),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.redAccent,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: () => _updateStatus(context, collection, docId, 'rejected'),
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
}