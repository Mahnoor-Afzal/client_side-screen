import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'lawyer_requests_screen.dart';
import 'documents_screen.dart';
import 'my_cases_screen.dart';
import 'chat_screen.dart';
import 'hearing_list_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    _markAllAsRead();
  }

  void _markAllAsRead() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      // Unread notifications fetch karein
      var unreadDocs = await FirebaseFirestore.instance
          .collection('notifications')
          .where('userId', isEqualTo: uid)
          .where('isRead', isEqualTo: false)
          .get();

      // Batch update for efficiency
      WriteBatch batch = FirebaseFirestore.instance.batch();
      for (var doc in unreadDocs.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    } catch (e) {
      debugPrint("Error marking notifications as read: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color navyBlue = Color(0xFF001F3F);
    const Color gold = Color(0xFFD4AF37);
    final String? currentUid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: navyBlue,
        title: const Text("Notifications", style: TextStyle(color: gold, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: gold),
      ),
      body: currentUid == null 
          ? const Center(child: Text("Please login to see notifications"))
          : StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('notifications')
            .where('userId', isEqualTo: currentUid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text("Connection Error: ${snapshot.error}"));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: navyBlue));
          }

          var allDocs = snapshot.data?.docs ?? [];
          
          if (allDocs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none_rounded, size: 80, color: navyBlue.withValues(alpha: 0.2)),
                  const SizedBox(height: 16),
                  const Text(
                    "No notifications yet",
                    style: TextStyle(color: navyBlue, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            );
          }

          // In-memory sort to avoid requiring composite indexes in Firestore
          var docs = allDocs.toList();
          docs.sort((a, b) {
            DateTime getTime(dynamic data) {
              var t = (data as Map<String, dynamic>)['createdAt'];
              if (t is Timestamp) return t.toDate();
              if (t is String) return DateTime.tryParse(t) ?? DateTime.fromMillisecondsSinceEpoch(0);
              return DateTime.fromMillisecondsSinceEpoch(0);
            }
            return getTime(b.data()).compareTo(getTime(a.data()));
          });

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              var doc = docs[index];
              var notification = doc.data() as Map<String, dynamic>;
              bool isRead = notification['isRead'] ?? false;
              String type = notification['type'] ?? '';

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                elevation: isRead ? 1 : 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: isRead ? BorderSide.none : const BorderSide(color: gold, width: 0.8),
                ),
                child: ListTile(
                  onTap: () {
                    // Notification par click karne se wo delete (remove) ho jaye
                    doc.reference.delete();

                    // Navigation Logic based on notification type
                    if (type == 'request_received') {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const LawyerRequestsScreen()));
                    } else if (type == 'request_accepted') {
                       Navigator.push(context, MaterialPageRoute(builder: (context) => const MyCasesScreen(filterType: 'Consultation')));
                    } else if (type == 'document_received' || type == 'vakalatnama_signed') {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const DocumentsScreen(initialCategory: 'Vakalatnama')));
                    } else if (type == 'hearing_update') {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const HearingListScreen()));
                    } else if (type == 'chat_message' && notification['senderId'] != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatScreen(
                            receiverName: notification['senderName'] ?? "Chat",
                            receiverId: notification['senderId'],
                            requestId: notification['requestId'],
                            chatId: notification['chatId'], // Pass the explicit chatId from notification
                          ),
                        ),
                      );
                    }
                  },
                  leading: CircleAvatar(
                    backgroundColor: isRead ? navyBlue.withValues(alpha: 0.6) : navyBlue,
                    child: Icon(
                      type == 'chat_message' ? Icons.chat : Icons.notifications, 
                      color: gold, 
                      size: 20
                    ),
                  ),
                  title: Text(
                    notification['title'] ?? 'New Update',
                    style: TextStyle(
                      fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                      color: navyBlue,
                    ),
                  ),
                  subtitle: Text(notification['body'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _formatTimestamp(notification['createdAt']),
                        style: const TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                      const SizedBox(height: 4),
                      if (!isRead)
                        Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                        ),
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

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return '';
    try {
      DateTime date;
      if (timestamp is Timestamp) {
        date = timestamp.toDate();
      } else if (timestamp is String) {
        date = DateTime.tryParse(timestamp) ?? DateTime.now();
      } else {
        return '';
      }
      return "${date.day}/${date.month} ${date.hour}:${date.minute.toString().padLeft(2, '0')}";
    } catch (e) {
      return '';
    }
  }
}
