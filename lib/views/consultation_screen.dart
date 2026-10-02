import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:rxdart/rxdart.dart';
import '../services/chat_service.dart';
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
  final ChatService _chatService = ChatService();
  
  // Streams ko cache karne ke liye variables
  Stream<List<QueryDocumentSnapshot>>? _requestsStream;
  Stream<QuerySnapshot>? _chatsStream;

  @override
  void initState() {
    super.initState();
    _initStreams();
  }

  void _initStreams() {
    if (currentLawyerId == null) return;

    // Firestore streams ko broadcast banaya taaki multiple components ise listen kar sakein
    final s1 = FirebaseFirestore.instance
        .collection('consultation_request')
        .where('lawyerId', isEqualTo: currentLawyerId)
        .where('status', isEqualTo: 'Pending')
        .snapshots();

    final s2 = FirebaseFirestore.instance
        .collection('suit_a_file_request')
        .where('lawyerId', isEqualTo: currentLawyerId)
        .where('status', isEqualTo: 'Pending')
        .snapshots();

    _requestsStream = Rx.combineLatest2(
      s1, 
      s2, 
      (QuerySnapshot snap1, QuerySnapshot snap2) {
        List<QueryDocumentSnapshot> combined = [...snap1.docs, ...snap2.docs];
        combined.sort((a, b) {
          var da = (a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
          var db = (b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
          if (da == null) return 1;
          if (db == null) return -1;
          return db.compareTo(da); // Newest first
        });
        return combined;
      }
    ).asBroadcastStream();

    _chatsStream = FirebaseFirestore.instance
        .collection('chat')
        .where('users', arrayContains: currentLawyerId)
        .snapshots()
        .asBroadcastStream();
  }

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

  Widget _buildRequestList() {
    return StreamBuilder<List<QueryDocumentSnapshot>>(
      stream: _requestsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptyState("pending requests");
        }

        final allRequests = snapshot.data!;

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: allRequests.length,
          itemBuilder: (context, index) {
            var doc = allRequests[index];
            var data = doc.data() as Map<String, dynamic>;
            String type = data['type'] ?? "Consultation";
            String collection = doc.reference.parent.id;

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: CircleAvatar(
                  backgroundColor: type == "Consultation" ? navyBlue : Colors.deepOrange,
                  child: Icon(type == "Consultation" ? Icons.chat : Icons.gavel, color: Colors.white)
                ),
                title: Text(data['clientName'] ?? "Client", style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text("$type Requested"),
                trailing: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                  onPressed: () => _acceptConsultation(doc.id, data, collection),
                  child: const Text("Accept"),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildOngoingList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _chatsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        final docs = snapshot.data?.docs.where((doc) {
          var data = doc.data() as Map<String, dynamic>;
          String status = (data['status'] ?? "").toString().toLowerCase();
          String type = (data['type'] ?? "").toString().toLowerCase();

          bool isLegalChat = type == 'consultation' || type == 'suit' || type == 'file a suit';
          bool isActive = status == 'active' || status == 'ongoing' || status == 'accepted';

          return isLegalChat && isActive;
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
                  },
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
          Icon(Icons.chat_bubble_outline, size: 60, color: Colors.grey.withValues(alpha: 0.5)),
          const SizedBox(height: 10),
          Text("No $msg found.", style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Future<void> _acceptConsultation(String docId, Map<String, dynamic> data, String collection) async {
    try {
      await _chatService.acceptConsultation(
        docId: docId,
        data: data,
        collection: collection,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Accepted! Opening chat..."), backgroundColor: Colors.green));
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              consultationId: docId,
              clientName: data['clientName'] ?? "Client",
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
