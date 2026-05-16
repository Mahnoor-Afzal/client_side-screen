import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ChatScreen extends StatefulWidget {
  final String receiverName;
  final String receiverId;
  final String? requestId;
  final String? chatId; // Added for explicit chat document reference

  const ChatScreen({
    super.key,
    required this.receiverName,
    required this.receiverId,
    this.requestId,
    this.chatId, // Initialize chatId
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final String serverKey = 'AIzaSyDQP_4C2i-KvTJs7EeM_KyxShTP8NXTmqA';
  String _currentUserName = "User";

  @override
  void initState() {
    super.initState();
    _fetchCurrentUserName();
    _markMessagesAsRead();
  }

  Future<void> _fetchCurrentUserName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      var doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists) {
        setState(() => _currentUserName = doc.data()?['name'] ?? doc.data()?['fullName'] ?? "User");
      } else {
        var lawyerDoc = await FirebaseFirestore.instance.collection('verified_lawyers').doc(user.uid).get();
        if (lawyerDoc.exists) {
          setState(() => _currentUserName = lawyerDoc.data()?['fullName'] ?? lawyerDoc.data()?['name'] ?? "Lawyer");
        }
      }
    }
  }

  void _markMessagesAsRead() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Is chat se mutalliq saare notifications ko read mark kar dein
    var notifications = await FirebaseFirestore.instance
        .collection('notifications')
        .where('userId', isEqualTo: user.uid)
        .where('senderId', isEqualTo: widget.receiverId)
        .where('isRead', isEqualTo: false)
        .get();

    for (var doc in notifications.docs) {
      await doc.reference.update({'isRead': true});
    }
  }

  // Chat ID generate karne ka function
  String getChatId(String currentUserId) {
    // 1. If we have an explicit chatId (from Messages/Notifications), use it.
    // This fixes the "Empty Chat" issue for existing conversations.
    if (widget.chatId != null && widget.chatId!.isNotEmpty) {
      return widget.chatId!;
    }

    // 2. Otherwise, use Deterministic Chat ID for new conversations.
    List<String> ids = [currentUserId, widget.receiverId];
    ids.sort(); 
    return ids.join("_");
  }

  Future<void> _sendPushNotification(String token, String title, String body) async {
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
            'type': 'chat_message',
            'senderId': FirebaseAuth.instance.currentUser?.uid,
            'requestId': widget.requestId,
          },
          'to': token,
        }),
      );
    } catch (e) {
      debugPrint("Notification Error: $e");
    }
  }

  String _formatTime(dynamic timestamp) {
    try {
      if (timestamp == null) return "..."; 
      DateTime dateTime;
      if (timestamp is Timestamp) {
        dateTime = timestamp.toDate();
      } else {
        return "...";
      }
      return DateFormat('hh:mm a').format(dateTime);
    } catch (e) {
      return "...";
    }
  }

  Future<bool> _isLawyer(String uid) async {
    var doc = await FirebaseFirestore.instance.collection('verified_lawyers').doc(uid).get();
    return doc.exists;
  }

  void _sendMessage() async {
    final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? "";
    if (_messageController.text.trim().isEmpty || currentUserId.isEmpty) return;

    String messageText = _messageController.text.trim();
    String chatId = getChatId(currentUserId);
    String receiverId = widget.receiverId;
    _messageController.clear();

    try {
      // Pehle determine karein ke lawyer kaun hai aur client kaun
      bool currentIsLawyer = await _isLawyer(currentUserId);
      String lawyerId = currentIsLawyer ? currentUserId : receiverId;
      String clientId = currentIsLawyer ? receiverId : currentUserId;

      // 1. Add message to sub-collection
      await FirebaseFirestore.instance
          .collection('chat')
          .doc(chatId)
          .collection('messages')
          .add({
        'senderId': currentUserId,
        'receiverId': receiverId,
        'text': messageText,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // 2. Update parent chat document
      await FirebaseFirestore.instance.collection('chat').doc(chatId).set({
        'lastMessage': messageText,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'users': [currentUserId, receiverId],
        'lawyerid': lawyerId,
        'clientId': clientId,
        'requestId': widget.requestId, // Track request if available
      }, SetOptions(merge: true));

      // 3. Send Push Notification to receiver
      DocumentSnapshot receiverDoc = await FirebaseFirestore.instance.collection('users').doc(receiverId).get();
      if (!receiverDoc.exists) {
        receiverDoc = await FirebaseFirestore.instance.collection('verified_lawyers').doc(receiverId).get();
      }

      // 4. Add to Notifications Collection for In-App Notification Screen
      await FirebaseFirestore.instance.collection('notifications').add({
        'userId': receiverId,
        'title': 'New Message',
        'body': messageText,
        'createdAt': FieldValue.serverTimestamp(),
        'type': 'chat_message',
        'senderId': currentUserId,
        'senderName': _currentUserName,
        'chatId': chatId,
        'isRead': false,
      });

      if (receiverDoc.exists) {
        String? token = (receiverDoc.data() as Map<String, dynamic>?)?['fcmToken'];
        if (token != null && token.isNotEmpty) {
          String senderName = "New Message";
          _sendPushNotification(token, senderName, messageText);
        }
      }

      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      debugPrint("Message Send Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color navyBlue = Color(0xFF001F3F);
    const Color gold = Color(0xFFD4AF37);
    final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? "";

    if (currentUserId.isEmpty) {
      return const Scaffold(body: Center(child: Text("User not logged in")));
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: navyBlue,
        title: Text(widget.receiverName, style: const TextStyle(color: gold, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: gold),
        elevation: 1,
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chat') // 'chat' singular
                  .doc(getChatId(currentUserId))
                  .collection('messages')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text("Error: ${snapshot.error}"));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: navyBlue));
                }
                
                var messages = snapshot.data?.docs ?? [];
                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline, size: 60, color: navyBlue.withValues(alpha: 0.1)),
                        const SizedBox(height: 10),
                        const Text("No messages yet. Say hi!", style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    var msg = messages[index].data() as Map<String, dynamic>;
                    bool isMe = msg['senderId'] == currentUserId;

                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                        decoration: BoxDecoration(
                          color: isMe ? navyBlue : Colors.grey[200],
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(15),
                            topRight: const Radius.circular(15),
                            bottomLeft: isMe ? const Radius.circular(15) : Radius.zero,
                            bottomRight: isMe ? Radius.zero : const Radius.circular(15),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              msg['text'] ?? "",
                              style: TextStyle(color: isMe ? Colors.white : Colors.black87, fontSize: 15),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatTime(msg['timestamp']),
                              style: TextStyle(
                                color: isMe ? Colors.white70 : Colors.black54,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: "Type a message...",
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: navyBlue,
                  child: IconButton(
                    icon: const Icon(Icons.send, color: gold),
                    onPressed: _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}