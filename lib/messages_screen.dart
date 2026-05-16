import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'chat_screen.dart';

class MessagesScreen extends StatelessWidget {
  const MessagesScreen({super.key});

  String _formatTime(dynamic timestamp) {
    if (timestamp == null) return "";
    try {
      if (timestamp is Timestamp) {
        return DateFormat('hh:mm a').format(timestamp.toDate());
      }
      return "";
    } catch (e) {
      return "";
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color navyBlue = Color(0xFF001F3F);
    const Color gold = Color(0xFFD4AF37);

    return Scaffold(
      backgroundColor: Colors.white,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('chat')
            .where('users', arrayContains: FirebaseAuth.instance.currentUser?.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? "";
          var docs = snapshot.data?.docs ?? [];

          // Group chats by otherUserId to avoid duplicates on screen
          Map<String, QueryDocumentSnapshot> uniqueChats = {};

          for (var doc in docs) {
            var chatData = doc.data() as Map<String, dynamic>;
            String lawyerId = chatData['lawyerid'] ?? "";
            String clientId = chatData['clientId'] ?? "";
            List users = chatData['users'] ?? [];
            
            String otherUserId = "";
            if (currentUserId == lawyerId) {
              otherUserId = clientId;
            } else if (currentUserId == clientId) {
              otherUserId = lawyerId;
            } else if (users.isNotEmpty) {
              otherUserId = users.firstWhere((id) => id != currentUserId, orElse: () => "");
            }

            if (otherUserId.isNotEmpty) {
              // Agar is user ke liye pehle se chat mil chuki hai, toh latest wali rakhein
              if (!uniqueChats.containsKey(otherUserId)) {
                uniqueChats[otherUserId] = doc;
              } else {
                var existingTime = (uniqueChats[otherUserId]!.data() as Map<String, dynamic>)['lastMessageTime'] as Timestamp?;
                var currentTime = chatData['lastMessageTime'] as Timestamp?;
                
                if (currentTime != null && (existingTime == null || currentTime.compareTo(existingTime) > 0)) {
                  uniqueChats[otherUserId] = doc;
                }
              }
            }
          }

          var filteredDocs = uniqueChats.values.toList();

          // Sort by time (latest first)
          filteredDocs.sort((a, b) {
            var timeA = (a.data() as Map<String, dynamic>)['lastMessageTime'] as Timestamp?;
            var timeB = (b.data() as Map<String, dynamic>)['lastMessageTime'] as Timestamp?;
            if (timeA == null) return 1;
            if (timeB == null) return -1;
            return timeB.compareTo(timeA);
          });

          if (filteredDocs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.chat_bubble_outline, size: 80, color: navyBlue.withValues(alpha: 0.2)),
                  const SizedBox(height: 16),
                  const Text(
                    "No messages yet",
                    style: TextStyle(color: navyBlue, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Your conversations will appear here",
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: filteredDocs.length,
            itemBuilder: (context, index) {
              var chatDoc = filteredDocs[index];
              var chatData = chatDoc.data() as Map<String, dynamic>;

              // Identify the other user
              String lawyerId = chatData['lawyerid'] ?? "";
              String clientId = chatData['clientId'] ?? "";
              List users = chatData['users'] ?? [];
              
              String otherUserId = "";
              if (currentUserId == lawyerId) {
                otherUserId = clientId;
              } else if (currentUserId == clientId) {
                otherUserId = lawyerId;
              } else if (users.isNotEmpty) {
                otherUserId = users.firstWhere((id) => id != currentUserId, orElse: () => "");
              }

              if (otherUserId.isEmpty) return const SizedBox.shrink();

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection('verified_lawyers').doc(otherUserId).get().then((lawyerDoc) {
                  if (lawyerDoc.exists) return lawyerDoc;
                  return FirebaseFirestore.instance.collection('users').doc(otherUserId).get();
                }),
                builder: (context, userSnapshot) {
                  if (!userSnapshot.hasData) return const SizedBox.shrink();

                  var userData = userSnapshot.data?.data() as Map<String, dynamic>?;
                  String userName = userData?['fullName'] ?? userData?['name'] ?? chatData['clientName'] ?? "User";
                  String lastMessage = chatData['lastMessage'] ?? "No messages yet";

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: navyBlue,
                      child: Text(userName.isNotEmpty ? userName[0] : "?", style: const TextStyle(color: gold)),
                    ),
                    title: Text(userName, style: const TextStyle(fontWeight: FontWeight.bold, color: navyBlue)),
                    subtitle: Text(lastMessage, maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: Text(
                      _formatTime(chatData['lastMessageTime']),
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatScreen(
                            receiverName: userName,
                            receiverId: otherUserId,
                            requestId: chatData['requestId'],
                            chatId: chatDoc.id, // Pass the exact document ID found in the list
                          ),
                        ),
                      );
                    },
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