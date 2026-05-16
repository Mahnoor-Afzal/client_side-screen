import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'Hearing_details.dart';
import 'chat_screen.dart';
import 'wakalatnama_form.dart';

class ActiveCasesScreen extends StatelessWidget {
  const ActiveCasesScreen({super.key});

  final Color navyBlue = const Color(0xFF101D3D);
  final Color goldColor = const Color(0xFFC5A358);

  @override
  Widget build(BuildContext context) {
    final String? uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text("Active Cases", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: navyBlue,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: uid == null
          ? const Center(child: Text("Please login to see your cases"))
          : StreamBuilder<List<QuerySnapshot>>(
              stream: _getCombinedActiveCases(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                List<DocumentSnapshot> allActive = [];
                if (snapshot.hasData) {
                  for (var snap in snapshot.data!) {
                    allActive.addAll(snap.docs.where((doc) {
                      var data = doc.data() as Map<String, dynamic>;
                      String status = (data['status'] ?? "").toString().toLowerCase().trim();
                      String lId = (data['lawyerid'] ?? data['lawyerId'] ?? "").toString().trim();
                      
                      bool isActive = status == 'accepted' || status == 'active';
                      return isActive && lId == uid.trim();
                    }));
                  }
                }

                if (allActive.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.assignment_turned_in_outlined, size: 70, color: Colors.grey[300]),
                        const SizedBox(height: 10),
                        const Text("No active cases found", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: allActive.length,
                  itemBuilder: (context, index) {
                    var doc = allActive[index];
                    var data = doc.data() as Map<String, dynamic>;
                    String name = data['clientName'] ?? data['fullName'] ?? "Client";
                    String type = data['caseType'] ?? data['title'] ?? "Active Matter";
                    String clientId = data['clientId'] ?? data['userId'] ?? "";

                    return _buildCaseCard(context, doc.id, name, type, clientId);
                  },
                );
              },
            ),
    );
  }

  Stream<List<QuerySnapshot>> _getCombinedActiveCases() {
    StreamController<List<QuerySnapshot>> controller = StreamController();
    StreamSubscription? s1; StreamSubscription? s2;
    QuerySnapshot? q1; QuerySnapshot? q2;

    void update() {
      if (!controller.isClosed) {
        List<QuerySnapshot> res = [];
        if (q1 != null) res.add(q1!); if (q2 != null) res.add(q2!);
        if (res.isNotEmpty) controller.add(res);
      }
    }
    s1 = FirebaseFirestore.instance.collection('Case request').snapshots().listen((s) { q1 = s; update(); });
    s2 = FirebaseFirestore.instance.collection('suit_a_file_request').snapshots().listen((s) { q2 = s; update(); });
    controller.onCancel = () { s1?.cancel(); s2?.cancel(); controller.close(); };
    return controller.stream;
  }

  Widget _buildCaseCard(BuildContext context, String id, String name, String type, String clientId) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                CircleAvatar(backgroundColor: navyBlue, radius: 22, child: const Icon(Icons.person, color: Colors.white, size: 28)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: TextStyle(fontWeight: FontWeight.bold, color: navyBlue, fontSize: 18), maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text(type, style: const TextStyle(fontSize: 14, color: Colors.black54), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Fixed: Using Doc ID directly to avoid "Link/Index Error"
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('chat').doc(id).snapshots(),
              builder: (context, snap) {
                String lastMsg = "Tap Chat to communicate...";
                if (snap.hasData && snap.data!.exists) {
                  var cData = snap.data!.data() as Map<String, dynamic>;
                  lastMsg = cData['lastMessage'] ?? lastMsg;
                }
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(color: Colors.blue.withOpacity(0.05), borderRadius: BorderRadius.circular(10)),
                  child: Row(
                    children: [
                      const Icon(Icons.chat_bubble_outline, size: 14, color: Colors.blue),
                      const SizedBox(width: 8),
                      Expanded(child: Text(lastMsg, style: const TextStyle(fontSize: 12, color: Colors.blueGrey, fontStyle: FontStyle.italic), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                );
              },
            ),
            
            const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider(height: 1)),
            
            Wrap(
              spacing: 6,
              runSpacing: 8,
              alignment: WrapAlignment.start,
              children: [
                _buildActionChip(context, Icons.chat_outlined, "Chat", Colors.blue, () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => ChatScreen(consultationId: id, clientName: name, clientId: clientId)));
                }),
                _buildActionChip(context, Icons.gavel, "Hearings", goldColor, () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => HearingDetailsScreen(caseId: id, clientName: name, clientId: clientId)));
                }),
                _buildActionChip(context, Icons.assignment_outlined, "Vakalatnama", Colors.teal, () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => WakalatnamaForm(clientId: clientId, clientName: name, requestId: id)));
                }),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildActionChip(BuildContext context, IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
