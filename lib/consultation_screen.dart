import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_screen.dart';

class ConsultationScreen extends StatefulWidget {
  const ConsultationScreen({super.key});

  @override
  State<ConsultationScreen> createState() => _ConsultationScreenState();
}

class _ConsultationScreenState extends State<ConsultationScreen> {
  final Color navyBlue = const Color(0xFF101D3D);
  final Color goldColor = const Color(0xFFC5A358);
  final String? currentLawyerId = FirebaseAuth.instance.currentUser?.uid;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        appBar: AppBar(
          title: const Text("Consultations", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          backgroundColor: navyBlue,
          iconTheme: const IconThemeData(color: Colors.white),
          bottom: const TabBar(
            indicatorColor: Color(0xFFC5A358),
            labelColor: Color(0xFFC5A358),
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(text: "Requests", icon: Icon(Icons.pending_actions)),
              Tab(text: "Ongoing / Chat", icon: Icon(Icons.chat_bubble_outline)),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildConsultationList('pending'),
            _buildConsultationList('ongoing'),
          ],
        ),
      ),
    );
  }

  Widget _buildConsultationList(String status) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chat') 
          .where('lawyerid', isEqualTo: currentLawyerId)
          .where('status', isEqualTo: status)
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
                Icon(Icons.chat_bubble_outline, size: 60, color: Colors.grey.withOpacity(0.5)),
                const SizedBox(height: 10),
                Text("No $status chats found.", style: const TextStyle(color: Colors.grey)),
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
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: CircleAvatar(backgroundColor: navyBlue, child: const Icon(Icons.person, color: Colors.white)),
                title: Text(data['clientName'] ?? "Client", style: const TextStyle(fontWeight: FontWeight.bold)),
                
                // Show real-time latest message from the sub-collection
                subtitle: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('chat')
                      .doc(doc.id)
                      .collection('messages')
                      .orderBy('timestamp', descending: true)
                      .limit(1)
                      .snapshots(),
                  builder: (context, msgSnap) {
                    String lastMsg = data['lastMessage'] ?? "Topic: ${data['topic'] ?? 'Legal Advice'}";
                    if (msgSnap.hasData && msgSnap.data!.docs.isNotEmpty) {
                      var mData = msgSnap.data!.docs.first.data() as Map<String, dynamic>;
                      lastMsg = mData['text'] ?? lastMsg;
                    }
                    return Text(
                      lastMsg,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.blueGrey),
                    );
                  },
                ),

                trailing: status == 'pending'
                    ? ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                        onPressed: () => _updateStatus(doc.id, 'ongoing', data),
                        child: const Text("Accept"),
                      )
                    : Icon(Icons.chevron_right, color: goldColor),
                onTap: status == 'ongoing' ? () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChatScreen(
                        consultationId: doc.id,
                        clientName: data['clientName'] ?? "Client",
                      ),
                    ),
                  );
                } : null,
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _updateStatus(String docId, String newStatus, Map<String, dynamic> data) async {
    try {
      await FirebaseFirestore.instance.collection('chat').doc(docId).update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted && newStatus == 'ongoing') {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Chat Enabled!"), backgroundColor: Colors.green));
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              consultationId: docId,
              clientName: data['clientName'] ?? "Client",
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }
}
