import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'client_notification_helper.dart';

class ChatScreen extends StatefulWidget {
  final String receiverName;
  final String receiverId;
  final String? requestId;
  final String? chatId;
  final String collectionPath;

  const ChatScreen({
    super.key,
    required this.receiverName,
    required this.receiverId,
    this.requestId,
    this.chatId,
    this.collectionPath = 'group_chats',
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _currentUserName = "User";
  String? _dynamicTitle;
  StreamSubscription? _chatSubscription;
  StreamSubscription? _statusSubscription;
  late bool _isGroup;
  late String _targetCollectionPath;
  String _activeChatId = "";
  List<dynamic> _groupUsers = [];
  final Map<String, String> _userNames = {};
  final Map<String, String> _userRoles = {};
  final Set<String> _pendingFetches = {};
  bool _isCaseClosed = false;
  bool _isLoading = true;

  static const Color navyBlue = Color(0xFF001F3F);
  static const Color gold = Color(0xFFD4AF37);

  @override
  void initState() {
    super.initState();
    _targetCollectionPath = widget.collectionPath;
    _isGroup = widget.collectionPath.contains('group') ||
        widget.collectionPath.contains('coordination') ||
        widget.receiverName.toLowerCase().contains("team chat");
    _activeChatId = _calculateChatId();
    _initializeChat();
  }

  String _calculateChatId() {
    if (widget.chatId != null && widget.chatId!.isNotEmpty) {
      return widget.chatId!;
    }
    if (widget.requestId != null && widget.requestId!.isNotEmpty) {
      return widget.requestId!;
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return "";

    if (!_isGroup && widget.receiverId.isNotEmpty) {
      List<String> ids = [user.uid, widget.receiverId];
      ids.sort();
      return ids.join("_");
    }

    if (_isGroup && widget.receiverId.isNotEmpty) {
      return widget.receiverId;
    }

    return "";
  }

  Future<void> _initializeChat() async {
    // Already loading by default
    
    try {
      await _fetchCurrentUserName();

      String cid = _calculateChatId();
      _activeChatId = cid;

      if (cid.isNotEmpty) {
        List<String> collectionsToTry = [
          widget.collectionPath,
          'group_chats',
          'group_chat',
          'coordination_requests',
          'chat'
        ];
        collectionsToTry = collectionsToTry.toSet().toList();

        for (String col in collectionsToTry) {
          try {
            var doc = await FirebaseFirestore.instance.collection(col).doc(cid).get();
            if (doc.exists) {
              var data = doc.data() as Map<String, dynamic>;
              if (mounted) {
                setState(() {
                  _targetCollectionPath = col;
                  _activeChatId = cid;
                  _isGroup = col.contains('group') || col.contains('coordination') || (data['isGroup'] == true);
                });
              }
              break;
            }
          } catch (e) {
            debugPrint("Error detecting collection $col: $e");
          }
        }
      }

      await _fetchChatDetails();
      await _checkCaseStatus();
      _markMessagesAsRead();
      _startChatListener();
    } catch (e) {
      debugPrint("Chat init error: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _checkCaseStatus() async {
    String? reqId = widget.requestId;
    
    // 1. Try to find requestId from the chat document itself if not provided
    if (reqId == null || reqId.isEmpty) {
      try {
        var chatDoc = await FirebaseFirestore.instance.collection(_targetCollectionPath).doc(_activeChatId).get();
        if (chatDoc.exists) {
          var data = chatDoc.data() as Map<String, dynamic>;
          reqId = data['requestId'] ?? data['caseId'] ?? data['case_id'];
        }
      } catch (e) {
        debugPrint("Error fetching reqId from chat: $e");
      }
    }

    final String finalReqId = reqId ?? _activeChatId;
    if (finalReqId.isEmpty) return;

    void updateStatus(String? status) {
      if (status == null) return;
      String s = status.toLowerCase();
      if (mounted) {
        setState(() {
          _isCaseClosed = (s == 'closed' || s == 'completed');
        });
      }
    }

    try {
      // 2. Check in suit_a_file_request (handles both direct and team chats linked to this collection)
      var directDoc = await FirebaseFirestore.instance.collection('suit_a_file_request').doc(finalReqId).get();
      if (directDoc.exists) {
        updateStatus(directDoc.data()?['status']);
        _statusSubscription?.cancel();
        _statusSubscription = directDoc.reference.snapshots().listen((snap) => updateStatus(snap.data()?['status']));
        return;
      }

      // Check by chatId inside suit_a_file_request as a fallback
      var chatQuery = await FirebaseFirestore.instance.collection('suit_a_file_request')
          .where('chatId', isEqualTo: _activeChatId).limit(1).get();
      if (chatQuery.docs.isNotEmpty) {
        updateStatus(chatQuery.docs.first.data()['status']);
        _statusSubscription?.cancel();
        _statusSubscription = chatQuery.docs.first.reference.snapshots().listen((snap) => updateStatus(snap.data()?['status']));
        return;
      }

      // Special check for direct chats: find suit_a_file_request by participants
      if (!_isGroup) {
        final currentUserId = FirebaseAuth.instance.currentUser?.uid;
        if (currentUserId != null && widget.receiverId.isNotEmpty) {
          var participantQuery = await FirebaseFirestore.instance.collection('suit_a_file_request')
              .where('clientId', isEqualTo: currentUserId)
              .where('lawyerId', isEqualTo: widget.receiverId)
              .limit(1).get();
          
          if (participantQuery.docs.isEmpty) {
            participantQuery = await FirebaseFirestore.instance.collection('suit_a_file_request')
                .where('clientId', isEqualTo: widget.receiverId)
                .where('lawyerId', isEqualTo: currentUserId)
                .limit(1).get();
          }

          if (participantQuery.docs.isNotEmpty) {
            updateStatus(participantQuery.docs.first.data()['status']);
            _statusSubscription?.cancel();
            _statusSubscription = participantQuery.docs.first.reference.snapshots().listen((snap) => updateStatus(snap.data()?['status']));
            return;
          }
        }
      }

      // 3. Check coordination_requests for Team Chat
      var coordDoc = await FirebaseFirestore.instance.collection('coordination_requests').doc(finalReqId).get();
      if (!coordDoc.exists && finalReqId != _activeChatId) {
        coordDoc = await FirebaseFirestore.instance.collection('coordination_requests').doc(_activeChatId).get();
      }

      if (coordDoc.exists) {
        updateStatus(coordDoc.data()?['status']);
        _statusSubscription?.cancel();
        _statusSubscription = coordDoc.reference.snapshots().listen((snap) => updateStatus(snap.data()?['status']));
      }
    } catch (e) {
      debugPrint("Error checking case status: $e");
    }
  }

  Future<void> _fetchChatDetails() async {
    if (_activeChatId.isEmpty) return;
    try {
      var doc = await FirebaseFirestore.instance.collection(_targetCollectionPath).doc(_activeChatId).get();
      if (doc.exists) {
        var data = doc.data() as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            if (_isGroup) {
              _dynamicTitle = data['groupName'] ?? data['caseType'] ?? widget.receiverName;
              _groupUsers = data['users'] ?? [];
            }
          });
        }
        if (_isGroup) {
          for (var uid in _groupUsers) {
            await _fetchUserName(uid.toString());
          }
        }
      }
    } catch (e) {
      debugPrint("Error fetching chat details: $e");
    }
  }

  Future<void> _fetchUserName(String uid) async {
    // If already known as lawyer or currently fetching, skip
    if (_userRoles[uid] == "Lawyer" || _pendingFetches.contains(uid)) return;
    
    _pendingFetches.add(uid);
    try {
      // 1. Try 'verified_lawyers' (plural - as seen in Firestore screenshot)
      var lawyerDoc = await FirebaseFirestore.instance.collection('verified_lawyers').doc(uid).get();
      
      // 2. Try 'verified_lawyer' (singular - as mentioned in prompt) if plural fails
      if (!lawyerDoc.exists) {
        lawyerDoc = await FirebaseFirestore.instance.collection('verified_lawyer').doc(uid).get();
      }

      if (lawyerDoc.exists) {
        var data = lawyerDoc.data() as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            _userNames[uid] = data['fullName'] ?? data['name'] ?? "Lawyer";
            _userRoles[uid] = "Lawyer";
          });
        }
        return;
      }

      // 3. Only if not found in lawyers, check the 'users' collection
      if (!_userNames.containsKey(uid) || _userRoles[uid] == null) {
        var doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
        if (doc.exists) {
          var data = doc.data() as Map<String, dynamic>;
          if (mounted) {
            setState(() {
              _userNames[uid] = data['name'] ?? data['fullName'] ?? "User";
              _userRoles[uid] = "Client";
            });
          }
        }
      }
    } catch (e) {
      debugPrint("Error fetching user name: $e");
    } finally {
      _pendingFetches.remove(uid);
    }
  }

  Future<void> _fetchCurrentUserName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // Check lawyers first for the current user too
      var lawyerDoc = await FirebaseFirestore.instance.collection('verified_lawyers').doc(user.uid).get();
      if (!lawyerDoc.exists) {
        lawyerDoc = await FirebaseFirestore.instance.collection('verified_lawyer').doc(user.uid).get();
      }

      if (lawyerDoc.exists) {
        if (mounted) {
          setState(() {
            _currentUserName = lawyerDoc.data()?['fullName'] ?? lawyerDoc.data()?['name'] ?? "Lawyer";
            _userRoles[user.uid] = "Lawyer";
            _userNames[user.uid] = _currentUserName;
          });
        }
        return;
      }

      var doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists) {
        if (mounted) {
          setState(() {
            _currentUserName = doc.data()?['name'] ?? doc.data()?['fullName'] ?? "User";
            _userRoles[user.uid] = "Client";
            _userNames[user.uid] = _currentUserName;
          });
        }
      }
    }
  }

  void _startChatListener() {
    if (_activeChatId.isEmpty) return;
    _chatSubscription = FirebaseFirestore.instance
        .collection(_targetCollectionPath)
        .doc(_activeChatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen((_) => _markMessagesAsRead());
  }

  void _markMessagesAsRead() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _activeChatId.isEmpty) return;

    try {
      var unreadMessages = await FirebaseFirestore.instance
          .collection(_targetCollectionPath)
          .doc(_activeChatId)
          .collection('messages')
          .where('receiverId', isEqualTo: user.uid)
          .where('isSeen', isEqualTo: false)
          .get();

      WriteBatch batch = FirebaseFirestore.instance.batch();
      for (var doc in unreadMessages.docs) {
        batch.update(doc.reference, {'isSeen': true});
      }
      await batch.commit();

      await FirebaseFirestore.instance
          .collection(_targetCollectionPath)
          .doc(_activeChatId)
          .update({'unreadCount.${user.uid}': 0});
    } catch (e) {
      debugPrint("Error marking read: $e");
    }
  }

  void _sendMessage() async {
    if (_isCaseClosed) return;

    final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? "";
    if (_messageController.text.trim().isEmpty || currentUserId.isEmpty) return;

    String messageText = _messageController.text.trim();
    _messageController.clear();

    try {
      String senderName = _userNames[currentUserId] ?? _currentUserName;
      String senderRole = _userRoles[currentUserId] ?? "User";

      await FirebaseFirestore.instance
          .collection(_targetCollectionPath)
          .doc(_activeChatId)
          .collection('messages')
          .add({
        'senderId': currentUserId,
        'receiverId': _isGroup ? null : widget.receiverId,
        'text': messageText,
        'message': messageText,
        'timestamp': FieldValue.serverTimestamp(),
        'isSeen': false,
        'senderName': senderName,
        'senderRole': senderRole,
      });

      await FirebaseFirestore.instance
          .collection(_targetCollectionPath)
          .doc(_activeChatId)
          .set({
        'lastMessage': messageText,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!_isGroup) {
        await NotificationHelper.sendPushNotification(widget.receiverId, senderName, messageText, {
          'type': 'chat_message',
          'chatId': _activeChatId,
          'senderId': currentUserId,
          'senderName': senderName,
        });
      }
    } catch (e) {
      debugPrint("Error sending message: $e");
    }
  }

  void _showDeleteOptions(BuildContext context, DocumentSnapshot doc, bool isMe) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Message"),
        content: Text(isMe
            ? "Delete message?"
            : "Do you want to delete this message?"),
        actions: [
          if (isMe) ...[
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                try {
                  await doc.reference.delete();
                } catch (e) {
                  debugPrint("Error deleting for everyone: $e");
                }
              },
              child: const Text("Delete from everyone", style: TextStyle(color: Colors.red)),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                try {
                  await doc.reference.update({
                    'deletedFor': FieldValue.arrayUnion([FirebaseAuth.instance.currentUser?.uid])
                  });
                } catch (e) {
                  debugPrint("Error deleting for me: $e");
                }
              },
              child: const Text("Delete from me", style: TextStyle(color: Colors.red)),
            ),
          ] else ...[
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                try {
                  await doc.reference.update({
                    'deletedFor': FieldValue.arrayUnion([FirebaseAuth.instance.currentUser?.uid])
                  });
                } catch (e) {
                  debugPrint("Error deleting message: $e");
                }
              },
              child: const Text("Delete", style: TextStyle(color: Colors.red)),
            ),
          ],
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _chatSubscription?.cancel();
    _statusSubscription?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F7FB),
        appBar: AppBar(
          backgroundColor: navyBlue,
          elevation: 0,
          title: Text(widget.receiverName, style: const TextStyle(color: gold, fontSize: 18, fontWeight: FontWeight.bold)),
          iconTheme: const IconThemeData(color: gold),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: const Center(child: CircularProgressIndicator(color: navyBlue)),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        backgroundColor: navyBlue,
        elevation: 0,
        title: Text(_dynamicTitle ?? widget.receiverName, style: const TextStyle(color: gold, fontSize: 18, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: gold),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
              children: [
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection(_targetCollectionPath)
                  .doc(_activeChatId)
                  .collection('messages')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                var docs = snapshot.data!.docs;
                return ListView.builder(
                  reverse: true,
                  controller: _scrollController,
                  itemCount: docs.length,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  itemBuilder: (context, index) {
                    var data = docs[index].data() as Map<String, dynamic>;
                    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
                    
                    // Filter messages deleted for this user
                    if ((data['deletedFor'] as List?)?.contains(currentUserId) ?? false) {
                      return const SizedBox.shrink();
                    }

                    bool isMe = data['senderId'] == currentUserId;
                    Timestamp? ts = data['timestamp'] as Timestamp?;
                    String timeLabel = ts != null ? DateFormat('hh:mm a').format(ts.toDate()) : "";

                    String? senderId = data['senderId'];
                    if (senderId != null) {
                      _fetchUserName(senderId);
                    }

                    String rawRole = (_userRoles[senderId] ?? data['senderRole'] ?? "Client").toString();
                    bool isLawyer = rawRole.toLowerCase() == 'lawyer';
                    String displayRole = isLawyer ? "LAWYER" : "CLIENT";
                    
                    Color labelColor = isLawyer ? Colors.green : Colors.blue;
                    Color labelBg = isLawyer ? Colors.green.shade50 : Colors.blue.shade50;
                    Color labelBorder = isLawyer ? Colors.green.shade200 : Colors.blue.shade200;

                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
                        child: Column(
                          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                          children: [
                            if (_isGroup)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4, left: 4, right: 4),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: labelBg,
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: labelBorder, width: 0.5),
                                      ),
                                      child: Text(
                                        displayRole,
                                        style: TextStyle(
                                          fontSize: 8,
                                          fontWeight: FontWeight.bold,
                                          color: labelColor,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      _userNames[senderId] ?? data['senderName'] ?? data['fullName'] ?? "Unknown",
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey.shade800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            GestureDetector(
                              onTap: () => _showDeleteOptions(context, docs[index], isMe),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                constraints: BoxConstraints(
                                  maxWidth: MediaQuery.of(context).size.width * 0.75,
                                ),
                                decoration: BoxDecoration(
                                  color: isMe ? navyBlue : Colors.white,
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(15),
                                    topRight: const Radius.circular(15),
                                    bottomLeft: Radius.circular(isMe ? 15 : 0),
                                    bottomRight: Radius.circular(isMe ? 0 : 15),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.05),
                                      blurRadius: 5,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                  border: isMe ? null : Border.all(color: Colors.grey.shade200),
                                ),
                                child: Column(
                                  crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      data['text'] ?? data['message'] ?? "",
                                      style: TextStyle(
                                        color: isMe ? Colors.white : Colors.black87,
                                        fontSize: 15,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          timeLabel,
                                          style: TextStyle(
                                            color: isMe ? Colors.white70 : Colors.grey,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
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
          _isCaseClosed
              ? Container(
                  padding: const EdgeInsets.all(15),
                  color: Colors.grey[200],
                  width: double.infinity,
                  child: const Text(
                    "This case is closed. You cannot send new messages.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                  ),
                )
              : Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(25),
                          ),
                          child: TextField(
                            controller: _messageController,
                            decoration: const InputDecoration(
                              hintText: "Type a message...",
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      CircleAvatar(
                        backgroundColor: navyBlue,
                        child: IconButton(
                          icon: const Icon(Icons.send, color: gold, size: 20),
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
