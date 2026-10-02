import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../utils/client_notification_helper.dart';
import '../services/chat_service.dart';

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
  final ChatService _chatService = ChatService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _currentUserName = "User";
  String? _dynamicTitle;
  StreamSubscription? _statusSubscription;
  late bool _isGroup;
  late String _targetCollectionPath;
  String _activeChatId = "";
  List<dynamic> _groupUsers = [];
  final Map<String, String> _userNames = {};
  final Map<String, String> _userRoles = {};
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
        // Optimized: Try the provided collection first, then fallback to others ONLY if needed
        var doc = await FirebaseFirestore.instance.collection(_targetCollectionPath).doc(cid).get();
        
        if (!doc.exists && _targetCollectionPath == 'group_chats') {
          // Fallback only for specific known alternatives
          var altDoc = await FirebaseFirestore.instance.collection('chat').doc(cid).get();
          if (altDoc.exists) {
            _targetCollectionPath = 'chat';
          }
        }
        
        if (doc.exists) {
          var data = doc.data() as Map<String, dynamic>;
          if (mounted) {
            setState(() {
              _isGroup = _targetCollectionPath.contains('group') || (data['isGroup'] == true);
            });
          }
        }
      }

      // Parallel fetching for faster startup
      await Future.wait([
        _fetchChatDetails(),
        _checkCaseStatus(),
      ]);
      
      if (_activeChatId.isNotEmpty) {
        _chatService.markAsRead(_activeChatId, _targetCollectionPath);
      }
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
    _statusSubscription?.cancel();
    _statusSubscription = _chatService
        .getCaseStatusStream(
          _activeChatId,
          _targetCollectionPath,
          requestId: widget.requestId,
        )
        .listen((isClosed) {
      if (mounted) setState(() => _isCaseClosed = isClosed);
    });
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
    final profile = await _chatService.getUserProfile(uid);
    if (profile != null && mounted) {
      setState(() {
        _userNames[uid] = profile['fullName'] ?? profile['name'] ?? "User";
        _userRoles[uid] = profile['role'] ?? (profile.containsKey('lawyerId') ? "Lawyer" : "Client");
      });
    }
  }

  Future<void> _fetchCurrentUserName() async {
    final uid = _chatService.currentUserId;
    if (uid != null) {
      final profile = await _chatService.getUserProfile(uid);
      if (profile != null && mounted) {
        setState(() {
          _currentUserName = profile['fullName'] ?? profile['name'] ?? "User";
          _userNames[uid] = _currentUserName;
          _userRoles[uid] = profile['role'] ?? "Client";
        });
      }
    }
  }

  void _sendMessage() async {
    if (_isCaseClosed || _messageController.text.trim().isEmpty) return;

    final String currentUserId = _chatService.currentUserId ?? "";
    String messageText = _messageController.text.trim();
    _messageController.clear();

    String senderName = _userNames[currentUserId] ?? _currentUserName;
    String senderRole = _userRoles[currentUserId] ?? "User";

    await _chatService.sendMessage(
      chatId: _activeChatId,
      text: messageText,
      senderName: senderName,
      senderRole: senderRole,
      targetCollection: _targetCollectionPath,
      receiverId: _isGroup ? null : widget.receiverId,
    );

    if (!_isGroup) {
      NotificationHelper.sendPushNotification(widget.receiverId, senderName, messageText, {
        'type': 'chat_message',
        'chatId': _activeChatId,
        'senderId': currentUserId,
        'senderName': senderName,
      });
    }
  }

  void _showDeleteOptions(BuildContext context, DocumentSnapshot doc, bool isMe) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Message"),
        content: Text(isMe
            ? "Choose how you want to delete this message:"
            : "Do you want to delete this message for yourself?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _chatService.deleteMessage(
                chatId: _activeChatId,
                messageId: doc.id,
                targetCollection: _targetCollectionPath,
                forEveryone: false,
              );
            },
            child: Text(isMe ? "Delete for me" : "Delete", style: const TextStyle(color: Colors.red)),
          ),
          if (isMe)
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await _chatService.deleteMessage(
                  chatId: _activeChatId,
                  messageId: doc.id,
                  targetCollection: _targetCollectionPath,
                  forEveryone: true,
                );
              },
              child: const Text("Delete for everyone", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
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

                // Mark messages as read when they arrive
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (docs.isNotEmpty) {
                    _chatService.markAsRead(_activeChatId, _targetCollectionPath);
                  }
                });

                return ListView.builder(
                  reverse: true,
                  controller: _scrollController,
                  itemCount: docs.length,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  itemBuilder: (context, index) {
                    var doc = docs[index];
                    var data = doc.data() as Map<String, dynamic>;
                    final currentUserId = _chatService.currentUserId;
                    
                    if ((data['deletedFor'] as List?)?.contains(currentUserId) ?? false) {
                      return const SizedBox.shrink();
                    }

                    bool isMe = data['senderId'] == currentUserId;
                    Timestamp? ts = data['timestamp'] as Timestamp?;
                    String timeLabel = ts != null ? DateFormat('hh:mm a').format(ts.toDate()) : "";

                    String? senderId = data['senderId'];
                    // Note: _fetchUserName call removed from build for performance
                    // Names are pre-loaded in _fetchChatDetails or fetched when new messages arrive

                    String rawRole = (data['senderRole'] ?? _userRoles[senderId] ?? "Client").toString();
                    bool isLawyer = rawRole.toLowerCase() == 'lawyer';
                    String displayRole = isLawyer ? "LAWYER" : "CLIENT";
                    
                    Color labelColor = isLawyer ? Colors.green.shade800 : Colors.blue.shade700;
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
