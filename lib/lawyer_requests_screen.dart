import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http; // Naya import
import 'dart:convert'; // Naya import
import 'chat_screen.dart';
import 'package:file_picker/file_picker.dart';

class LawyerRequestsScreen extends StatefulWidget {
  const LawyerRequestsScreen({super.key});

  @override
  State<LawyerRequestsScreen> createState() => _LawyerRequestsScreenState();
}

class _LawyerRequestsScreenState extends State<LawyerRequestsScreen> {
  static const Color navyBlue = Color(0xFF001F3F);
  static const Color gold = Color(0xFFD4AF37);
  final String? lawyerId = FirebaseAuth.instance.currentUser?.uid;

  // Aapki fetch ki hui Server Key
  final String serverKey = 'AIzaSyDQP_4C2i-KvTJs7EeM_KyxShTP8NXTmqA';

  // Notification bhejney ka function
  Future<void> sendPushNotification(String token, String title, String body) async {
    try {
      await http.post(
        Uri.parse('https://fcm.googleapis.com/fcm/send'),
        headers: <String, String>{
          'Content-Type': 'application/json',
          'Authorization': 'key=$serverKey',
        },
        body: jsonEncode(<String, dynamic>{
          'notification': <String, dynamic>{
            'body': body,
            'title': title,
            'android_channel_id': 'high_importance_channel',
          },
          'priority': 'high',
          'data': <String, dynamic>{
            'click_action': 'FLUTTER_NOTIFICATION_CLICK',
            'status': 'done',
          },
          'to': token,
        }),
      );
      debugPrint("Notification sent successfully!");
    } catch (e) {
      debugPrint("Error sending notification: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        backgroundColor: navyBlue,
        title: const Text("Client Requests",
            style: TextStyle(color: gold, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: gold),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('consultation_request')
            .where('lawyerId', isEqualTo: lawyerId)
            .snapshots(),
        builder: (context, consultSnapshot) {
          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('suit_a_file_request')
                .where('lawyerId', isEqualTo: lawyerId)
                .snapshots(),
            builder: (context, suitSnapshot) {
              if (consultSnapshot.connectionState == ConnectionState.waiting ||
                  suitSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: navyBlue));
              }

              List<QueryDocumentSnapshot> allRequests = [];
              if (consultSnapshot.hasData) allRequests.addAll(consultSnapshot.data!.docs);
              if (suitSnapshot.hasData) allRequests.addAll(suitSnapshot.data!.docs);

              allRequests.sort((a, b) {
                var dataA = a.data() as Map<String, dynamic>;
                var dataB = b.data() as Map<String, dynamic>;
                Timestamp t1 = dataA['createdAt'] ?? Timestamp.now();
                Timestamp t2 = dataB['createdAt'] ?? Timestamp.now();
                return t2.compareTo(t1);
              });

              if (allRequests.isEmpty) {
                return const Center(child: Text("No requests from clients yet."));
              }

              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: allRequests.length,
                itemBuilder: (context, index) {
                  var doc = allRequests[index];
                  var data = doc.data() as Map<String, dynamic>;
                  String collectionName = doc.reference.parent.id;
                  return _buildRequestCard(context, doc.id, data, collectionName);
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildRequestCard(BuildContext context, String requestId, Map<String, dynamic> data, String collectionName) {
    String status = data['status'] ?? 'Pending';
    String clientName = data['clientName'] ?? 'Unknown Client';
    String type = data['type'] ?? (collectionName == 'consultation_request' ? 'Consultation' : 'File a Suit');

    bool isPending = status == 'Pending';
    bool canChat = ['Accepted', 'Active', 'In Progress'].contains(status);
    Map<String, dynamic>? aiAnalysis = data['aiAnalysis'];

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(clientName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: navyBlue)),
                    Text(type, style: const TextStyle(color: gold, fontWeight: FontWeight.w600)),
                  ],
                ),
                _buildStatusChip(status),
              ],
            ),
            if (aiAnalysis != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.auto_awesome, size: 16, color: Colors.blue),
                        SizedBox(width: 5),
                        Text("AI Case Analysis", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 13)),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text("Case Type: ${aiAnalysis['case_type'] ?? 'N/A'}", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    Text("Summary: ${aiAnalysis['reason'] ?? 'No summary available'}", style: const TextStyle(fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
            const Divider(height: 25),
            if (isPending)
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _handleAccept(context, requestId, collectionName, type, data['clientId'] ?? '', clientName),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text("Accept", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _handleReject(context, requestId, collectionName),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text("Reject"),
                    ),
                  ),
                ],
              )
            else if (canChat)
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _openChat(context, data['clientId'], clientName, requestId),
                      icon: const Icon(Icons.chat_outlined),
                      label: const Text("MESSAGE CLIENT", style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: navyBlue,
                        side: const BorderSide(color: navyBlue),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  if (type == 'File a Suit' && status == 'Accepted') ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _sendVakalatnama(context, data['clientId'] ?? '', clientName, requestId),
                        icon: const Icon(Icons.assignment_outlined, size: 18),
                        label: const Text("VAKALATNAMA", style: TextStyle(fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: gold,
                          foregroundColor: navyBlue,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendVakalatnama(BuildContext context, String clientId, String clientName, String requestId) async {
    try {
      // Current lawyer ki details fetch karein
      DocumentSnapshot lawyerDoc = await FirebaseFirestore.instance.collection('verified_lawyers').doc(lawyerId ?? "").get();
      String lawyerName = lawyerDoc.exists ? (lawyerDoc.get('fullName') ?? lawyerDoc.get('name') ?? 'Advocate') : 'Advocate';

      // Sahi fields save karna taake Document Screen par sahi filter ho
      await FirebaseFirestore.instance.collection('documents').add({
        'userId': clientId, // Ye client ki ID honi chahiye
        'clientName': clientName, // Client ka naam save karein
        'lawyerId': lawyerId,
        'lawyerName': lawyerName, // Lawyer ka naam explicitly save karein
        'requestId': requestId,
        'title': 'Vakalatnama - $clientName',
        'category': 'Vakalatnama',
        'status': 'Pending Signature',
        'uploadedAt': FieldValue.serverTimestamp(),
        'fileSize': 1024,
        'extension': 'pdf',
      });

      // 2. Notifications collection mein entry (App ke andar Notification Screen ke liye)
      await FirebaseFirestore.instance.collection('notifications').add({
        'userId': clientId,
        'title': 'Vakalatnama Received',
        'body': 'Your lawyer has sent a Vakalatnama for you to sign.',
        'createdAt': FieldValue.serverTimestamp(),
        'type': 'document_received',
        'requestId': requestId,
        'isRead': false,
      });

      // 3. Real-time Push Notification (Mobile Popup)
      DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(clientId).get();
      if (userDoc.exists) {
        String? token = userDoc.get('fcmToken');
        if (token != null && token.isNotEmpty) {
          await sendPushNotification(
            token,
            "Vakalatnama Received",
            "Your lawyer has sent a Vakalatnama for you to sign in the Documents section."
          );
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Vakalatnama sent to client!"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint("Error sending Vakalatnama: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildStatusChip(String status) {
    Color color = status == 'Rejected' ? Colors.red : (status == 'Accepted' ? Colors.blue : Colors.orange);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
      child: Text(status, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }

  // Yahan notification aur chat initialization ka logic add kiya gaya hai
  void _handleAccept(BuildContext context, String requestId, String collectionName, String type, String clientId, String clientName) async {
    try {
      final String? currentLawyerId = FirebaseAuth.instance.currentUser?.uid;
      if (currentLawyerId == null) return;

      // Lawyer ka naam fetch karein taake request doc mein save ho sakey
      DocumentSnapshot lawyerDoc = await FirebaseFirestore.instance.collection('verified_lawyers').doc(currentLawyerId).get();
      String lawyerName = lawyerDoc.exists ? (lawyerDoc.get('fullName') ?? lawyerDoc.get('name') ?? 'Advocate') : 'Advocate';

      // 1. Firestore status update karein
      await FirebaseFirestore.instance.collection(collectionName).doc(requestId).update({
        'status': 'Accepted',
        'acceptedAt': FieldValue.serverTimestamp(),
        'lawyerName': lawyerName,
        'lawyerId': currentLawyerId, // Fix: Ensure lawyerId is set in the request document
      });

      // Generate deterministic Chat ID
      List<String> ids = [currentLawyerId, clientId];
      ids.sort();
      String chatId = ids.join("_");

      // 2. Chat initialize karein (Using deterministic chatId)
      await FirebaseFirestore.instance.collection('chat').doc(chatId).set({
        'users': [currentLawyerId, clientId],
        'lawyerid': currentLawyerId,
        'clientId': clientId,
        'clientName': clientName,
        'requestId': requestId, // Latest requestId reference
        'lastMessage': "Request Accepted. You can now start chatting.",
        'lastMessageTime': FieldValue.serverTimestamp(),
        'status': 'ongoing',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // 3. Pehla message add karein
      await FirebaseFirestore.instance.collection('chat').doc(chatId).collection('messages').add({
        'senderId': currentLawyerId,
        'receiverId': clientId,
        'text': "Your request for $type has been accepted. How can I help you?",
        'timestamp': FieldValue.serverTimestamp(),
      });

      // 4. Notification to Client (Firestore)
      await FirebaseFirestore.instance.collection('notifications').add({
        'userId': clientId,
        'title': 'Request Accepted!',
        'body': 'Your $type request has been accepted by the lawyer.',
        'createdAt': FieldValue.serverTimestamp(),
        'type': 'request_accepted',
        'requestId': requestId,
        'chatId': chatId, // Pass chatId so client can open the same document
        'senderId': currentLawyerId,
        'senderName': lawyerName,
        'isRead': false,
      });

      // 5. Client ka token dhoond kar notification bhejien (Push)
      DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(clientId).get();
      if (userDoc.exists) {
        String? token = userDoc.get('fcmToken');
        if (token != null && token.isNotEmpty) {
          await sendPushNotification(
              token,
              "Request Accepted!",
              "Your $type request has been accepted. You can now chat with the advocate."
          );
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Request Accepted & Chat Enabled!")));
      }
    } catch (e) {
      debugPrint("Accept error: $e");
    }
  }

  void _handleReject(BuildContext context, String requestId, String collectionName) async {
    try {
      await FirebaseFirestore.instance.collection(collectionName).doc(requestId).update({
        'status': 'Rejected',
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Request Rejected.")));
      }
    } catch (e) {
      debugPrint("Reject error: $e");
    }
  }

  void _openChat(BuildContext context, String? clientId, String clientName, String requestId) {
    if (clientId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            receiverId: clientId, 
            receiverName: clientName,
            requestId: requestId, // Pass requestId here
          ),
        ),
      );
    }
  }
}
