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
            _buildRequestList(),
            _buildOngoingList(),
          ],
        ),
      ),
    );
  }

  // Requests Tab: Showing pending requests from 'consultation_request' (e.g. Javeria)
  Widget _buildRequestList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('consultation_request')
          .where('lawyerId', isEqualTo: currentLawyerId)
          .where('status', isEqualTo: 'Pending')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState("pending requests");
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
                title: Text(data['clientName'] ?? "Javeria", style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text("Consultation Requested"),
                trailing: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                  onPressed: () => _acceptConsultation(doc.id, data),
                  child: const Text("Accept"),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Ongoing Tab: Showing chats from 'chat' collection (Restored Javeria)
  Widget _buildOngoingList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chat')
          .where('users', arrayContains: currentLawyerId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        final docs = snapshot.data?.docs.where((doc) {
          var data = doc.data() as Map<String, dynamic>;
          String status = (data['status'] ?? "").toString().toLowerCase();
          String type = (data['type'] ?? "").toString().toLowerCase();
          
          // STRICT SEPARATION: 
          // 1. Agar type 'case' hai, toh Consultation mein nahi dikhayenge (Kainat bibi yahan se hide ho jayegi).
          // 2. Agar type empty hai ya 'consultation' hai, toh Javeria show hogi.
          bool isCase = type == 'case' || type == 'file a suit';
          bool isActive = status == 'active' || status == 'ongoing' || status == 'accepted';
          
          return !isCase && isActive;
        }).toList() ?? [];

        if (docs.isEmpty) return _buildEmptyState("ongoing chats");

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            var doc = docs[index];
            var data = doc.data() as Map<String, dynamic>;

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: CircleAvatar(backgroundColor: navyBlue, child: const Icon(Icons.person, color: Colors.white)),
                title: Text(data['clientName'] ?? "Client", style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('chat')
                      .doc(doc.id)
                      .collection('messages')
                      .orderBy('timestamp', descending: true)
                      .limit(1)
                      .snapshots(),
                  builder: (context, msgSnap) {
                    String lastMsg = data['lastMessage'] ?? "Click to start chatting...";
                    if (msgSnap.hasData && msgSnap.data!.docs.isNotEmpty) {
                       var mData = msgSnap.data!.docs.first.data() as Map<String, dynamic>;
                       lastMsg = mData['text'] ?? lastMsg;
                    }
                    return Text(lastMsg, maxLines: 1, overflow: TextOverflow.ellipsis);
                  }
                ),
                trailing: Icon(Icons.chat, color: goldColor),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChatScreen(
                        consultationId: doc.id,
                        clientName: data['clientName'] ?? "Client",
                        clientId: data['clientId'] ?? data['userId'],
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState(String msg) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 60, color: Colors.grey.withOpacity(0.5)),
          const SizedBox(height: 10),
          Text("No $msg found.", style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Future<void> _acceptConsultation(String docId, Map<String, dynamic> data) async {
    try {
      await FirebaseFirestore.instance.collection('consultation_request').doc(docId).update({
        'status': 'Accepted',
      });

      await FirebaseFirestore.instance.collection('chat').doc(docId).set({
        'lawyerid': currentLawyerId,
        'lawyerId': currentLawyerId,
        'clientId': data['clientId'],
        'clientName': data['clientName'],
        'status': 'Active',
        'type': 'consultation',
        'lastMessage': 'Consultation started',
        'updatedAt': FieldValue.serverTimestamp(),
        'users': [data['clientId'], currentLawyerId],
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Accepted! Opening chat..."), backgroundColor: Colors.green));
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              consultationId: docId,
              clientName: data['clientName'] ?? "Javeria",
              clientId: data['clientId'],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }
}
