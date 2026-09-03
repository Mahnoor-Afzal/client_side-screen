import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

// Adjust imports as per your actual file directory
import 'case_requet_screen.dart';
import 'messages_list_screen.dart';
import 'Hearing_details.dart';
import 'documents_screen.dart';
import 'consultation_screen.dart';
import 'chat_screen.dart';
import 'coordination_screen.dart';

/// Helper function to get total unread count for bell icons across the app
Stream<int> getTotalUnreadNotificationsCount(String currentUid) {
  final controller = StreamController<int>();

  int rawNotifUnread = 0;
  int req1Unread = 0;
  int req2Unread = 0;

  void calculateTotal() {
    if (controller.isClosed) return;
    int total = rawNotifUnread + req1Unread + req2Unread;
    controller.add(total);
  }

  // 1. Notifications collection se unread count
  final sub1 = FirebaseFirestore.instance
      .collection('notifications')
      .where('userId', isEqualTo: currentUid)
      .where('isRead', isEqualTo: false)
      .snapshots()
      .listen((snapshot) {
    rawNotifUnread = snapshot.docs.length;
    calculateTotal();
  });

  // 2. Case requests se pending unread count
  final sub2 = FirebaseFirestore.instance
      .collection('Case request')
      .snapshots()
      .listen((snapshot) {
    req1Unread = snapshot.docs.where((doc) {
      var d = doc.data() as Map<String, dynamic>;
      String lawyer = (d['lawyerid'] ?? d['lawyerId'] ?? '').toString().trim();
      String status = (d['status'] ?? 'pending').toString().toLowerCase().trim();
      bool isRead = d['isRead'] ?? false;
      return lawyer == currentUid && status == 'pending' && !isRead;
    }).length;
    calculateTotal();
  });

  // 3. Suit requests se pending unread count
  final sub3 = FirebaseFirestore.instance
      .collection('suit_a_file_request')
      .snapshots()
      .listen((snapshot) {
    req2Unread = snapshot.docs.where((doc) {
      var d = doc.data() as Map<String, dynamic>;
      String lawyer = (d['lawyerid'] ?? d['lawyerId'] ?? '').toString().trim();
      String status = (d['status'] ?? 'pending').toString().toLowerCase().trim();
      bool isRead = d['isRead'] ?? false;
      return lawyer == currentUid && status == 'pending' && !isRead;
    }).length;
    calculateTotal();
  });

  controller.onCancel = () {
    sub1.cancel();
    sub2.cancel();
    sub3.cancel();
    controller.close();
  };

  return controller.stream;
}

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final String? uid = FirebaseAuth.instance.currentUser?.uid;
  static const Color navyBlue = Color(0xFF101D3D);
  static const Color goldColor = Color(0xFFC5A358);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: StreamBuilder<List<Map<String, dynamic>>>(
          stream: _getAllNotificationsAndRequests(uid ?? ''),
          builder: (context, snapshot) {
            int totalUnread = 0;
            if (snapshot.hasData) {
              for (var item in snapshot.data!) {
                if (item['isRead'] == false) {
                  totalUnread += (item['unreadCount'] != null && item['unreadCount'] > 0) ? (item['unreadCount'] as int) : 1;
                }
              }
            }
            return Row(
              children: [
                const Text("Notifications", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                if (totalUnread > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: goldColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      "$totalUnread",
                      style: const TextStyle(color: navyBlue, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
        backgroundColor: navyBlue,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all),
            onPressed: () => _markAllAsRead(uid),
            tooltip: "Mark all as read",
          )
        ],
      ),
      body: uid == null
          ? const Center(child: Text("Please login to see notifications"))
          : StreamBuilder<List<Map<String, dynamic>>>(
        stream: _getAllNotificationsAndRequests(uid!),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final notifications = snapshot.data ?? [];
          if (notifications.isEmpty) return _buildEmptyState();

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              var data = notifications[index];
              bool isRead = data['isRead'] ?? false;
              Timestamp? ts = data['timestamp'];
              String type = data['type']?.toString().toLowerCase() ?? '';
              String title = data['title']?.toString() ?? '';

              return Card(
                elevation: isRead ? 1 : 3,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                  side: BorderSide(color: isRead ? Colors.transparent : navyBlue.withValues(alpha: 0.15)),
                ),
                color: isRead ? Colors.white : Colors.blue.shade50,
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isRead ? Colors.grey[200] : goldColor.withValues(alpha: 0.2),
                    child: Icon(_getIcon(type, title), color: isRead ? Colors.grey : goldColor),
                  ),
                  title: Text(
                    data['title'] ?? "Notification",
                    style: TextStyle(fontWeight: isRead ? FontWeight.normal : FontWeight.bold, color: navyBlue),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 2),
                      Text(data['body'] ?? "", style: const TextStyle(fontSize: 13, color: Colors.black87)),
                      const SizedBox(height: 6),
                      Text(
                        ts != null ? DateFormat('dd MMM, hh:mm a').format(ts.toDate()) : "",
                        style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  trailing: !isRead ? const CircleAvatar(radius: 5, backgroundColor: Colors.red) : null,
                  onTap: () async {
                    await _markSingleAsRead(data);
                    if (context.mounted) _navigateToTarget(context, data);
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  Stream<List<Map<String, dynamic>>> _getAllNotificationsAndRequests(String currentUid) {
    final controller = StreamController<List<Map<String, dynamic>>>();

    List<Map<String, dynamic>> rawNotifList = [], req1List = [], req2List = [];

    void emitCombined() {
      if (controller.isClosed) return;

      Map<String, Map<String, dynamic>> chatGroups = {};
      List<Map<String, dynamic>> otherNotifs = [];

      for (var notif in rawNotifList) {
        if (notif['type']?.toString().toLowerCase() == 'chat_message') {
          String groupKey = (notif['senderId'] ?? notif['senderName'] ?? notif['chatId'] ?? notif['docId']).toString();

          if (!chatGroups.containsKey(groupKey)) {
            chatGroups[groupKey] = Map<String, dynamic>.from(notif);
            chatGroups[groupKey]!['unreadCount'] = (notif['isRead'] == false) ? 1 : 0;
            chatGroups[groupKey]!['allDocIds'] = [notif['docId']];
          } else {
            var existing = chatGroups[groupKey]!;
            List docIds = existing['allDocIds'] ?? [];
            if (notif['docId'] != null) docIds.add(notif['docId']);
            existing['allDocIds'] = docIds;

            if (notif['isRead'] == false) existing['unreadCount'] = (existing['unreadCount'] ?? 0) + 1;

            Timestamp newTs = notif['timestamp'] is Timestamp ? notif['timestamp'] : Timestamp.now();
            Timestamp oldTs = existing['timestamp'] is Timestamp ? existing['timestamp'] : Timestamp.now();

            if (newTs.compareTo(oldTs) >= 0) {
              existing['body'] = notif['body'];
              existing['timestamp'] = notif['timestamp'];
            }
            existing['isRead'] = (existing['unreadCount'] ?? 0) == 0;
          }
        } else {
          otherNotifs.add(notif);
        }
      }

      var groupedChatList = chatGroups.values.map((item) {
        int count = item['unreadCount'] ?? 0;
        if (count > 1 && !item['title'].toString().contains('(')) {
          item['title'] = "${item['title']} ($count)";
        }
        return item;
      }).toList();

      List<Map<String, dynamic>> combined = [...groupedChatList, ...otherNotifs, ...req1List, ...req2List];
      combined.sort((a, b) {
        Timestamp tA = a['timestamp'] is Timestamp ? a['timestamp'] : Timestamp.now();
        Timestamp tB = b['timestamp'] is Timestamp ? b['timestamp'] : Timestamp.now();
        return tB.compareTo(tA);
      });

      controller.add(combined);
    }

    final sub1 = FirebaseFirestore.instance.collection('notifications').where('userId', isEqualTo: currentUid).snapshots().listen((snap) {
      rawNotifList = snap.docs.map((doc) => {...doc.data(), 'docId': doc.id, 'source': 'notifications_col'}).toList();
      emitCombined();
    });

    final sub2 = FirebaseFirestore.instance.collection('Case request').snapshots().listen((snap) {
      req1List = _mapRequests(snap, currentUid, 'case_request');
      emitCombined();
    });

    final sub3 = FirebaseFirestore.instance.collection('suit_a_file_request').snapshots().listen((snap) {
      req2List = _mapRequests(snap, currentUid, 'suit_request');
      emitCombined();
    });

    controller.onCancel = () {
      sub1.cancel();
      sub2.cancel();
      sub3.cancel();
      controller.close();
    };

    return controller.stream;
  }

  List<Map<String, dynamic>> _mapRequests(QuerySnapshot snap, String uid, String source) {
    return snap.docs.where((doc) {
      var d = doc.data() as Map<String, dynamic>;
      String lawyer = (d['lawyerid'] ?? d['lawyerId'] ?? '').toString().trim();
      String status = (d['status'] ?? 'pending').toString().toLowerCase().trim();
      return lawyer == uid && status == 'pending';
    }).map((doc) {
      var d = doc.data() as Map<String, dynamic>;
      bool isSuit = source == 'suit_request';
      return {
        'docId': doc.id,
        'requestId': doc.id,
        'consultationId': d['consultationId'] ?? doc.id,
        'source': source,
        'type': isSuit ? 'suit_request' : 'consultation_request',
        'title': isSuit ? 'New File a Suit Request' : 'New Consultation Request',
        'body': "${d['clientName'] ?? d['fullName'] ?? 'A Client'} has sent a request for \"${d['caseType'] ?? d['title'] ?? 'Legal Matter'}\".",
        'isRead': d['isRead'] ?? false,
        'timestamp': d['createdAt'] ?? d['timestamp'] ?? Timestamp.now(),
      };
    }).toList();
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_none, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text("No notifications yet", style: TextStyle(color: Colors.grey[600], fontSize: 16)),
        ],
      ),
    );
  }

  IconData _getIcon(String type, String title) {
    String t = title.toLowerCase();
    String typeLower = type.toLowerCase();

    if (t.contains('wakalatnama') || typeLower.contains('wakalatnama') || t.contains('signed')) {
      return Icons.assignment_turned_in;
    } else if (t.contains('document') || typeLower.contains('document')) {
      return Icons.insert_drive_file_outlined;
    } else if (t.contains('consultation') || typeLower.contains('consultation')) {
      return Icons.chat_bubble_outline;
    } else if (t.contains('suit') || typeLower.contains('suit')) {
      return Icons.assignment_late_outlined;
    } else if (t.contains('hearing') || typeLower.contains('hearing')) {
      return Icons.gavel;
    } else if (t.contains('chat') || t.contains('message') || typeLower.contains('chat') || typeLower == 'chat_message') {
      return Icons.chat_outlined;
    }
    return Icons.notifications_none_outlined;
  }

  void _navigateToTarget(BuildContext context, Map<String, dynamic> item) {
    // Basic extraction with lowercasing for easier matching
    String title = (item['title'] ?? '').toString().toLowerCase();
    String type = (item['type'] ?? '').toString().toLowerCase();
    String source = (item['source'] ?? '').toString().toLowerCase();
    String body = (item['body'] ?? '').toString().toLowerCase();
    String chatType = (item['chatType'] ?? item['category'] ?? '').toString().toLowerCase();

    // IDs and Names extraction
    String clientId = item['senderId'] ?? item['clientId'] ?? item['userId'] ?? '';
    
    // For Team Chat, we prefer client names or case types over individual sender names
    String clientName = item['clientName'] ?? item['fullName'] ?? item['caseType'] ?? item['senderName'] ?? 'Team Chat';
    
    // Improved caseId extraction logic - Critical for Team Chat and Hearing screens
    String caseId = item['caseId'] ?? item['chatId'] ?? item['requestId'] ?? '';
    // If caseId is still empty, and the source isn't the general notifications collection, docId might be the ID we need.
    if (caseId.isEmpty && source != 'notifications_col') {
      caseId = item['docId'] ?? '';
    }

    String consultationId = item['consultationId'] ?? item['requestId'] ?? item['docId'] ?? '';

    // 1. TEAM CHAT / COORDINATION: Navigation to TeamChatScreen
    // Higher priority check for team-related keywords
    if (chatType == 'team' || 
        type == 'team_chat' || 
        type == 'coordination' ||
        title.contains('team') || 
        body.contains('team') || 
        title.contains('coordination') || 
        body.contains('coordination')) {

      if (caseId.isNotEmpty) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TeamChatScreen(
              caseId: caseId,
              clientName: clientName,
              currentUid: uid ?? '',
            ),
          ),
        );
        return;
      }
    }

    // 2. REGULAR CHAT: Navigation to ChatScreen (Lawyer-Client 1-on-1)
    if (type.contains('chat') || type.contains('message') || source == 'chat') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            clientId: clientId,
            clientName: clientName,
            consultationId: consultationId,
          ),
        ),
      );
      return;
    }

    Widget? target;

    // 3. DOCUMENTS VAULT
    if (title.contains('wakalatnama') ||
        type.contains('wakalatnama') ||
        title.contains('signed') ||
        type.contains('signed') ||
        body.contains('signed') ||
        body.contains('wakalatnama') ||
        title.contains('document') ||
        type.contains('document')) {
      target = const DocumentsScreen();
    }
    // 4. CONSULTATIONS
    else if (title.contains('consultation') || type.contains('consultation')) {
      target = const ConsultationScreen();
    }
    // 5. CASE REQUESTS
    else if (title.contains('suit') || type.contains('suit_request') || source == 'suit_request' || type.contains('case_request') || source == 'case_request') {
      target = const CaseRequestsScreen();
    }
    // 6. HEARING DETAILS
    else if (title.contains('hearing') || type.contains('hearing')) {
      target = HearingDetailsScreen(
        caseId: caseId,
        clientName: clientName,
        clientId: clientId,
      );
    }
    // 7. OTHER NOTIFICATIONS
    else {
      target = null;
    }

    // Finalize navigation
    if (target != null) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => target!));
    }
  }

  Future<void> _markSingleAsRead(Map<String, dynamic> item) async {
    if (item['source'] == 'notifications_col') {
      List allIds = item['allDocIds'] ?? (item['docId'] != null ? [item['docId']] : []);
      WriteBatch firestoreBatch = FirebaseFirestore.instance.batch();
      for (var id in allIds) {
        firestoreBatch.update(FirebaseFirestore.instance.collection('notifications').doc(id), {'isRead': true});
      }
      await firestoreBatch.commit();
    } else if (item['docId'] != null) {
      String col = item['source'] == 'case_request' ? 'Case request' : 'suit_a_file_request';
      await FirebaseFirestore.instance.collection(col).doc(item['docId']).update({'isRead': true});
    }
  }

  Future<void> _markAllAsRead(String? currentUid) async {
    if (currentUid == null) return;
    WriteBatch batch = FirebaseFirestore.instance.batch();

    var notifs = await FirebaseFirestore.instance.collection('notifications').where('userId', isEqualTo: currentUid).where('isRead', isEqualTo: false).get();
    for (var doc in notifs.docs) {
      batch.update(doc.reference, {'isRead': true});
    }

    for (var col in ['Case request', 'suit_a_file_request']) {
      var reqs = await FirebaseFirestore.instance.collection(col).get();
      for (var doc in reqs.docs) {
        var d = doc.data();
        if ((d['lawyerid'] ?? d['lawyerId'] ?? '').toString().trim() == currentUid && d['isRead'] != true) {
          batch.update(doc.reference, {'isRead': true});
        }
      }
    }

    await batch.commit();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("All notifications marked as read.")));
  }
}