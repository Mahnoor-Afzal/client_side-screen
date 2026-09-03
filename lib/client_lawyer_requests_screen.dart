import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http; // Naya import
import 'dart:convert'; // Naya import
import 'client_chat_screen.dart';
import 'client_pdf_helper.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'dart:typed_data';
import 'client_app_config.dart';

class LawyerRequestsScreen extends StatefulWidget {
  const LawyerRequestsScreen({super.key});

  @override
  State<LawyerRequestsScreen> createState() => _LawyerRequestsScreenState();
}

class _LawyerRequestsScreenState extends State<LawyerRequestsScreen> {
  static const Color navyBlue = Color(0xFF001F3F);
  static const Color gold = Color(0xFFD4AF37);
  final String? lawyerId = FirebaseAuth.instance.currentUser?.uid;

  // Notification bhejney ka function
  Future<void> sendPushNotification(String token, String title, String body, {Map<String, dynamic>? data}) async {
    try {
      await http.post(
        Uri.parse('https://fcm.googleapis.com/fcm/send'),
        headers: <String, String>{
          'Content-Type': 'application/json',
          'Authorization': 'key=${AppConfig.fcmServerKey}',
        },
        body: jsonEncode(<String, dynamic>{
          'notification': <String, dynamic>{
            'body': body,
            'title': title,
            'android_channel_id': 'high_importance_channel',
            'sound': 'default',
          },
          'priority': 'high',
          'data': data ?? <String, dynamic>{
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
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: navyBlue,
        elevation: 0,
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
                .where('lawyerId', isEqualTo: lawyerId) // Specifically for this lawyer
                .snapshots(),
            builder: (context, suitSnapshot) {
              if (consultSnapshot.connectionState == ConnectionState.waiting ||
                  suitSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: navyBlue));
              }

              if (lawyerId == null) {
                return const Center(child: Text("User session error. Please login again."));
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
    bool isDirect = data['isDirectRequest'] == true;

    bool isPending = status == 'Pending';
    bool canChat = ['Accepted', 'Active', 'In Progress'].contains(status);
    Map<String, dynamic>? aiAnalysis = data['aiAnalysis'];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
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
                    Row(
                      children: [
                        Text(type, style: const TextStyle(color: gold, fontWeight: FontWeight.w600)),
                        if (isDirect) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              "DIRECT",
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange),
                            ),
                          ),
                        ],
                      ],
                    ),
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
              Column(
                children: [
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
                  if (type == 'File a Suit' && status == 'Accepted') ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _createCoordinationGroup(context, data['clientId'] ?? '', clientName, requestId),
                        icon: const Icon(Icons.group_add_outlined),
                        label: const Text("CREATE TEAM CHAT", style: TextStyle(fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: navyBlue,
                          foregroundColor: Colors.white,
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
      
      String? lawyerSignatureUrl = lawyerDoc.exists ? lawyerDoc.get('digitalSignatureUrl') : null;
      String? lawyerSignatureBase64 = lawyerDoc.exists ? lawyerDoc.get('digitalSignatureBase64') : null;

      String status = 'Pending Signature';
      if (lawyerSignatureUrl == null) {
        if (!context.mounted) return;
        bool? proceed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Signature Missing"),
            content: const Text("You haven't set up a digital signature in your profile. You can send the Vakalatnama now and sign it later, or go to your profile to set it up now."),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, null), child: const Text("Cancel")),
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Send Anyway")),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: navyBlue),
                child: const Text("Go to Profile", style: TextStyle(color: gold)),
              ),
            ],
          ),
        );

        if (proceed == null) return;
        if (proceed == true) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please go to Profile -> Digital Signature")));
          return;
        }
        status = 'Waiting for Advocate Signature';
      }

      // Generate PDF
      Uint8List pdfBytes = await PdfHelper.generateVakalatnama(
        courtName: "DISTRICT COURT", // Default for now
        caseNo: "8876/2023", // Default for now
        clientName: clientName,
        respondentName: "DEFENDANT", // Default for now
        lawyerName: lawyerName,
        lawyerSignatureBase64: lawyerSignatureBase64,
      );

      // Upload PDF to Cloudinary
      final cloudinary = CloudinaryPublic('gasafl8q', 'ml_default', cache: false);
      CloudinaryResponse cloudinaryResponse = await cloudinary.uploadFile(
        CloudinaryFile.fromBytesData(
          pdfBytes,
          identifier: 'vakalatnama_${requestId}_${DateTime.now().millisecondsSinceEpoch}.pdf',
          folder: 'documents/$clientId',
        ),
      );

      // Sahi fields save karna taake Document Screen par sahi filter ho
      DocumentReference docRef = await FirebaseFirestore.instance.collection('documents').add({
        'userId': clientId, 
        'clientId': clientId,
        'lawyerId': lawyerId,
        'senderId': lawyerId,
        'receiverId': clientId,
        'senderType': 'lawyer',
        'senderName': lawyerName,
        'lawyerName': lawyerName,
        'clientName': clientName,
        'requestId': requestId,
        'title': 'Vakalatnama - $clientName',
        'category': 'Vakalatnama',
        'status': status,
        'lawyerSignatureUrl': lawyerSignatureUrl,
        'lawyerSignature': lawyerSignatureBase64,
        'uploadedAt': FieldValue.serverTimestamp(),
        'timestamp': FieldValue.serverTimestamp(),
        'fileSize': pdfBytes.length,
        'extension': 'pdf',
        'fileUrl': cloudinaryResponse.secureUrl,
        'courtName': "DISTRICT COURT",
        'caseNo': "8876/2023",
        'respondentName': "DEFENDANT",
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
        'docId': docRef.id,
      });

      // 4. Real-time Push Notification (Mobile Popup)
      DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(clientId).get();
      if (userDoc.exists) {
        String? token = (userDoc.data() as Map<String, dynamic>?)?['fcmToken'];
        if (token != null && token.isNotEmpty) {
          await sendPushNotification(
            token,
            "Vakalatnama Received",
            "Your lawyer has sent a Vakalatnama for you to sign in the Documents section.",
            data: {
              'click_action': 'FLUTTER_NOTIFICATION_CLICK',
              'type': 'document_received',
              'requestId': requestId,
              'docId': docRef.id,
            },
          );
        }
      }

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Vakalatnama sent to client!"),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      debugPrint("Error sending Vakalatnama: $e");
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _createCoordinationGroup(BuildContext context, String clientId, String clientName, String requestId) async {
    try {
      final String? currentLawyerId = FirebaseAuth.instance.currentUser?.uid;
      if (currentLawyerId == null) return;

      DocumentSnapshot lawyerDoc = await FirebaseFirestore.instance.collection('verified_lawyers').doc(currentLawyerId).get();
      String lawyerName = lawyerDoc.exists ? (lawyerDoc.get('fullName') ?? lawyerDoc.get('name') ?? 'Advocate') : 'Advocate';

      String groupChatId = "group_${requestId}_coordination";
      String groupName = "Team Chat";

      await FirebaseFirestore.instance.collection('group_chats').doc(groupChatId).set({
        'isGroup': true,
        'groupName': groupName,
        'users': [currentLawyerId, clientId],
        'lawyerid': currentLawyerId,
        'lawyerId': currentLawyerId,
        'clientId': clientId,
        'lawyerName': lawyerName,
        'clientName': clientName,
        'requestId': requestId,
        'lastMessage': "Team Chat created.",
        'lastMessageTime': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'createdBy': currentLawyerId,
        'unreadCount': {
          clientId: 1,
          currentLawyerId: 0,
        },
      }, SetOptions(merge: true));

      await FirebaseFirestore.instance.collection('group_chats').doc(groupChatId).collection('messages').add({
        'senderId': currentLawyerId,
        'text': "Welcome to the Team Chat. We will use this for case updates.",
        'timestamp': FieldValue.serverTimestamp(),
        'isSeen': false,
        'senderName': lawyerName,
      });

      await FirebaseFirestore.instance.collection('notifications').add({
        'userId': clientId,
        'title': 'Group Chat Created',
        'body': '$lawyerName created a Team Chat for your case.',
        'createdAt': FieldValue.serverTimestamp(),
        'type': 'chat_message', 
        'chatId': groupChatId,
        'senderId': currentLawyerId,
        'senderName': groupName,
        'isRead': false,
        'collectionPath': 'group_chats',
      });

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Team Chat Created!"), backgroundColor: Colors.green),
      );
      
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            receiverName: groupName,
            receiverId: clientId, 
            requestId: requestId,
            chatId: groupChatId,
            collectionPath: 'group_chats',
          ),
        ),
      );
    } catch (e) {
      debugPrint("Error creating group: $e");
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

  void _handleAccept(BuildContext context, String requestId, String collectionName, String type, String clientId, String clientName) async {
    try {
      final String? currentLawyerId = FirebaseAuth.instance.currentUser?.uid;
      if (currentLawyerId == null) return;

      DocumentSnapshot lawyerDoc = await FirebaseFirestore.instance.collection('verified_lawyers').doc(currentLawyerId).get();
      String lawyerName = lawyerDoc.exists ? (lawyerDoc.get('fullName') ?? lawyerDoc.get('name') ?? 'Advocate') : 'Advocate';

      DocumentReference docRef = FirebaseFirestore.instance.collection(collectionName).doc(requestId);
      
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        DocumentSnapshot snapshot = await transaction.get(docRef);
        if (!snapshot.exists) throw Exception("Request no longer exists");
        
        var data = snapshot.data() as Map<String, dynamic>;
        if (data['lawyerId'] != null && data['lawyerId'] != currentLawyerId) {
          throw Exception("This case has already been accepted by another lawyer.");
        }

        transaction.update(docRef, {
          'status': 'Accepted',
          'acceptedAt': FieldValue.serverTimestamp(),
          'lawyerName': lawyerName,
          'lawyerId': currentLawyerId,
        });
      });

      List<String> ids = [currentLawyerId, clientId];
      ids.sort();
      String chatId = ids.join("_");

      await FirebaseFirestore.instance.collection('chat').doc(chatId).set({
        'users': [currentLawyerId, clientId],
        'lawyerid': currentLawyerId,
        'clientId': clientId,
        'clientName': clientName,
        'lawyerName': lawyerName,
        'requestId': requestId,
        'lastMessage': "Request Accepted. You can now start chatting.",
        'lastMessageTime': FieldValue.serverTimestamp(),
        'status': 'ongoing',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await FirebaseFirestore.instance.collection('notifications').add({
        'userId': clientId,
        'title': 'Request Accepted!',
        'body': '$lawyerName has accepted your $type request.',
        'createdAt': FieldValue.serverTimestamp(),
        'type': 'request_accepted',
        'requestId': requestId,
        'chatId': chatId,
        'senderId': currentLawyerId,
        'senderName': lawyerName,
        'isRead': false,
      });

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Request Accepted & Chat Enabled!"), backgroundColor: Colors.green));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
      }
    }
  }

  void _handleReject(BuildContext context, String requestId, String collectionName) async {
    try {
      await FirebaseFirestore.instance.collection(collectionName).doc(requestId).update({
        'status': 'Rejected',
      });
    } catch (e) {
      debugPrint("Reject error: $e");
    }
  }

  void _openChat(BuildContext context, String? clientId, String clientName, String requestId) {
    if (clientId != null && lawyerId != null) {
      List<String> ids = [lawyerId!, clientId];
      ids.sort();
      String chatId = ids.join("_");

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            receiverId: clientId, 
            receiverName: clientName,
            requestId: requestId,
            chatId: chatId,
          ),
        ),
      );
    }
  }
}

