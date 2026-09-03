
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'client_documents_screen.dart';
import 'client_hearing_list_screen.dart';

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
    _syncHearingsToCollection();
  }

  String _formatDateTime(dynamic timestamp) {
    if (timestamp == null) return "Just now";
    DateTime dateTime;
    if (timestamp is Timestamp) {
      dateTime = timestamp.toDate();
    } else if (timestamp is String) {
      dateTime = DateTime.tryParse(timestamp) ?? DateTime.now();
    } else {
      return "Just now";
    }
    return DateFormat('hh:mm a, dd MMM').format(dateTime);
  }

  void _markAllAsRead() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      var unreadDocs = await FirebaseFirestore.instance
          .collection('notifications')
          .where('userId', isEqualTo: uid)
          .where('isRead', isEqualTo: false)
          .get();

      WriteBatch batch = FirebaseFirestore.instance.batch();
      for (var doc in unreadDocs.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    } catch (e) {
      debugPrint("Error marking as read: $e");
    }
  }

  void _syncHearingsToCollection() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      var snapshot = await FirebaseFirestore.instance
          .collection('notifications')
          .where('userId', isEqualTo: uid)
          .where('syncedToHearings', isNotEqualTo: true)
          .get();

      for (var doc in snapshot.docs) {
        var data = doc.data();
        String type = (data['type'] ?? '').toString().toLowerCase();
        if (type.contains("hearing") || type.contains("case")) {
          await doc.reference.update({'syncedToHearings': true});
        }
      }
    } catch (e) {
      debugPrint("Sync Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color navyBlue = Color(0xFF001F3F);
    const Color accentGold = Color(0xFFD4AF37);
    final String? currentUid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: navyBlue,
        elevation: 0,
        title: const Text("Notifications",
            style: TextStyle(color: accentGold, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: accentGold),
      ),
      body: currentUid == null
          ? const Center(child: Text("Please login first"))
          : StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('notifications')
            .where('userId', isEqualTo: currentUid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text("Error loading data"));
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: navyBlue));
          }

          var docs = snapshot.data?.docs ?? [];

          docs.sort((a, b) {
            var timeA = (a.data() as Map<String, dynamic>)['createdAt'];
            var timeB = (b.data() as Map<String, dynamic>)['createdAt'];
            DateTime dtA = timeA is Timestamp ? timeA.toDate() : DateTime.fromMillisecondsSinceEpoch(0);
            DateTime dtB = timeB is Timestamp ? timeB.toDate() : DateTime.fromMillisecondsSinceEpoch(0);
            return dtB.compareTo(dtA);
          });

          if (docs.isEmpty) {
            return const Center(child: Text("No notifications yet"));
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              var data = docs[index].data() as Map<String, dynamic>;
              bool isRead = data['isRead'] ?? false;
              String type = (data['type'] ?? '').toString().toLowerCase();
              String timeLabel = _formatDateTime(data['createdAt']);

              IconData iconData = Icons.notifications_rounded;
              Color iconColor = navyBlue;

              if (type.contains('document')) {
                iconData = Icons.description_rounded;
                iconColor = Colors.blue;
              } else if (type.contains('hearing')) {
                iconData = Icons.gavel_rounded;
                iconColor = Colors.orange;
              }

              return Dismissible(
                key: Key(docs[index].id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.redAccent,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Icon(Icons.delete_outline, color: Colors.white),
                ),
                onDismissed: (direction) {
                  FirebaseFirestore.instance
                      .collection('notifications')
                      .doc(docs[index].id)
                      .delete();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Notification deleted")),
                  );
                },
                child: Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: isRead ? 0 : 3,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  // .withOpacity ki jagah .withValues use kiya gaya hai
                  color: isRead ? Colors.white : Colors.blue.withValues(alpha: 0.05),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: iconColor.withValues(alpha: 0.1),
                      child: Icon(iconData, color: iconColor),
                    ),
                    title: Text(
                      data['title'] ?? 'New Update',
                      style: TextStyle(
                        fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                        color: navyBlue,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(data['body'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 5),
                        Text(timeLabel, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                      ],
                    ),
                    onTap: () {
                      if (type.contains('document')) {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => const DocumentsScreen()));
                      } else if (type.contains('hearing')) {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => const HearingListScreen()));
                      }
                    },
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