import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_screen.dart';

class MessagesListScreen extends StatelessWidget {
  const MessagesListScreen({super.key});

  // Last Message Tick Widget Logic for List Screen
  Widget _buildLastMessageTick(Map<String, dynamic> data, String currentLawyerId) {
    String lastSenderId = data['lastSenderId'] ?? '';

    // If the last message was not sent by the lawyer (you), do not show the tick icon
    if (lastSenderId != currentLawyerId) return const SizedBox.shrink();

    bool isRead = data['isRead'] ?? false;
    List readBy = data['readBy'] ?? [];

    bool showBlueTick = isRead || readBy.length > 1;

    // Exact WhatsApp Cyan Blue Hex: 0xFF34B7F1
    Color tickColor = showBlueTick ? const Color(0xFF34B7F1) : const Color(0xFF8696A0);

    return Padding(
      padding: const EdgeInsets.only(right: 4.0),
      child: Icon(
        Icons.done_all,
        size: 16,
        color: tickColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String? currentLawyerId = FirebaseAuth.instance.currentUser?.uid;
    const Color navyBlue = Color(0xFF101D3D);
    const Color goldColor = Color(0xFFC5A358);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text("Messages", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: navyBlue,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: currentLawyerId == null
          ? const Center(child: Text("Please login to see messages"))
          : StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('chat')
            .where('users', arrayContains: currentLawyerId)
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
                  const Text("No messages yet.", style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          final Map<String, DocumentSnapshot> uniqueClientChats = {};

          for (var doc in snapshot.data!.docs) {
            var data = doc.data() as Map<String, dynamic>?;
            if (data == null) continue;

            List users = data['users'] is List ? data['users'] : [];

            String clientId = data['clientId'] ?? data['userId'] ?? "";
            if (clientId.isEmpty) {
              clientId = users.firstWhere(
                    (id) => id.toString() != currentLawyerId,
                orElse: () => "",
              ).toString();
            }

            if (clientId.isEmpty) continue;

            if (!uniqueClientChats.containsKey(clientId)) {
              uniqueClientChats[clientId] = doc;
            } else {
              var existingData = uniqueClientChats[clientId]!.data() as Map<String, dynamic>?;
              Timestamp? existingTime = existingData?['updatedAt'] ?? existingData?['lastMessageTime'];
              Timestamp? currentTime = data['updatedAt'] ?? data['lastMessageTime'];

              if (currentTime != null && (existingTime == null || currentTime.compareTo(existingTime) > 0)) {
                uniqueClientChats[clientId] = doc;
              }
            }
          }

          final docs = uniqueClientChats.values.toList();

          if (docs.isEmpty) {
            return const Center(
              child: Text("No active messages found.", style: TextStyle(color: Colors.grey)),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              var doc = docs[index];
              var data = doc.data() as Map<String, dynamic>;

              List users = data['users'] is List ? data['users'] : [];
              String clientId = data['clientId'] ?? data['userId'] ?? "";
              if (clientId.isEmpty) {
                clientId = users.firstWhere(
                      (id) => id.toString() != currentLawyerId,
                  orElse: () => "",
                ).toString();
              }

              String savedClientName = data['clientName'] ?? "";

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection('users').doc(clientId).get(),
                builder: (context, userSnap) {
                  String realClientName = savedClientName;

                  if (userSnap.hasData && userSnap.data != null && userSnap.data!.exists) {
                    var userData = userSnap.data!.data() as Map<String, dynamic>?;
                    if (userData != null) {
                      realClientName = userData['fullName'] ?? userData['name'] ?? userData['clientName'] ?? realClientName;
                    }
                  }

                  bool isLoading = userSnap.connectionState == ConnectionState.waiting && realClientName.isEmpty;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      leading: const CircleAvatar(
                        backgroundColor: navyBlue,
                        child: Icon(Icons.person, color: Colors.white),
                      ),
                      title: isLoading
                          ? Container(
                        width: 100,
                        height: 16,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      )
                          : Text(
                        realClientName.isEmpty ? "Client" : realClientName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Row(
                          children: [
                            _buildLastMessageTick(data, currentLawyerId),
                            Expanded(
                              child: Text(
                                data['lastMessage'] ?? "No messages yet",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_right, color: goldColor),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatScreen(
                              consultationId: doc.id,
                              clientName: realClientName.isEmpty ? "Client" : realClientName,
                              clientId: clientId,
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
        },
      ),
    );
  }
}