import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'client_chat_screen.dart';

class GroupChatListScreen extends StatelessWidget {
  const GroupChatListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? "";
    const Color navyBlue = Color(0xFF001F3F);
    const Color gold = Color(0xFFD4AF37);

    if (currentUserId.isEmpty) {
      return const Scaffold(
        body: Center(child: Text("User not logged in")),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        backgroundColor: navyBlue,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          "Team Chat",
          style: TextStyle(color: gold, fontWeight: FontWeight.bold),
        ),
      ),
      // Sirf group_chats collection se stream lein taake duplicate cards ka masla hi khatam ho jaye
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('group_chats')
            .where('users', arrayContains: currentUserId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: navyBlue));
          }

          final groupDocs = snapshot.data?.docs ?? [];

          if (groupDocs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.group_outlined, size: 60, color: navyBlue.withValues(alpha: 0.2)),
                  const SizedBox(height: 10),
                  const Text(
                    "No team chats yet",
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: groupDocs.length,
            itemBuilder: (context, index) {
              var doc = groupDocs[index];
              var data = doc.data() as Map<String, dynamic>;
              String chatId = doc.id;

              String groupName = data['groupName'] ??
                  (data['caseId'] != null ? "Case Chat" : "Team Chat");

              if (data['clientName'] != null && groupName == "Team Chat") {
                groupName = "Team Chat: ${data['clientName']}";
              }

              String lastMessage = data['lastMessage'] ?? "Start chatting...";

              int unreadCount = 0;
              if (data['unreadCount'] != null && data['unreadCount'] is Map) {
                final unreadData = data['unreadCount'] as Map<String, dynamic>;
                unreadCount = (unreadData[currentUserId] ?? 0).toInt();
              }
              bool hasUnread = unreadCount > 0;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: navyBlue.withValues(alpha: 0.1),
                    child: const Icon(Icons.group, color: navyBlue),
                  ),
                  title: Text(
                    groupName,
                    style: TextStyle(
                      fontWeight: hasUnread ? FontWeight.bold : FontWeight.w600,
                      color: navyBlue,
                    ),
                  ),
                  subtitle: Text(
                    lastMessage,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: hasUnread ? Colors.black87 : Colors.grey[600],
                      fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  trailing: hasUnread
                      ? Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Color(0xFF25D366),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      unreadCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                      : const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                  onTap: () {
                    List usersList = data['users'] ?? [];
                    String receiverId = "";
                    for (var u in usersList) {
                      if (u != currentUserId) {
                        receiverId = u;
                        break;
                      }
                    }

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatScreen(
                          receiverName: groupName,
                          receiverId: receiverId,
                          chatId: chatId,
                          collectionPath: 'group_chats',
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}