import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class ChatScreen extends StatefulWidget {
  final String consultationId;
  final String clientName;
  final String? clientId;
  final String? collectionPath;

  const ChatScreen({
    super.key,
    required this.consultationId,
    required this.clientName,
    this.clientId,
    this.collectionPath,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String? _lawyerName;
  Map<String, dynamic>? _replyMessage;
  bool _isCaseClosed = false;

  String? get currentUserId => FirebaseAuth.instance.currentUser?.uid;

  bool get isGroupChat => widget.collectionPath != null && widget.collectionPath!.isNotEmpty;

  String get effectiveChatId {
    if (!isGroupChat && widget.clientId != null && widget.clientId!.isNotEmpty && currentUserId != null) {
      List<String> ids = [currentUserId!, widget.clientId!];
      ids.sort();
      return ids.join('_');
    }
    return widget.consultationId.trim();
  }

  CollectionReference<Map<String, dynamic>> get _messagesRef {
    if (isGroupChat) {
      return FirebaseFirestore.instance.collection(widget.collectionPath!);
    }
    return FirebaseFirestore.instance
        .collection('chat')
        .doc(effectiveChatId)
        .collection('messages');
  }

  @override
  void initState() {
    super.initState();
    _fetchLawyerName();
    _checkCaseStatus();
  }

  void _checkCaseStatus() {
    FirebaseFirestore.instance
        .collection('suit_a_file_request')
        .doc(widget.consultationId.trim())
        .snapshots()
        .listen((doc) {
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['status'] == 'closed') {
          if (mounted) {
            setState(() {
              _isCaseClosed = true;
            });
          }
        }
      }
    });
  }

  void _markMessagesAsRead(List<QueryDocumentSnapshot> docs) async {
    if (currentUserId == null) return;

    WriteBatch batch = FirebaseFirestore.instance.batch();
    bool hasUpdates = false;

    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final String senderId = data['senderId'] ?? '';
      final bool isRead = data['isRead'] ?? false;
      final List readBy = List.from(data['readBy'] ?? []);

      if (senderId != currentUserId && (!isRead || !readBy.contains(currentUserId))) {
        DocumentReference msgRef = _messagesRef.doc(doc.id);

        batch.update(msgRef, {
          'isRead': true,
          'readBy': FieldValue.arrayUnion([currentUserId]),
        });
        hasUpdates = true;
      }
    }

    if (hasUpdates) {
      await batch.commit().catchError((e) => debugPrint("Batch mark read error: $e"));
      if (!isGroupChat) {
        FirebaseFirestore.instance.collection('chat').doc(effectiveChatId).update({
          'isRead': true,
        }).catchError((e) => debugPrint("Chat doc read error: $e"));
      }
    }
  }

  void _fetchLawyerName() async {
    if (currentUserId == null) return;
    var doc = await FirebaseFirestore.instance.collection('lawyers').doc(currentUserId).get();
    if (doc.exists) {
      setState(() {
        _lawyerName = doc.data()?['fullName'] ?? doc.data()?['name'] ?? "Lawyer";
      });
    }
  }

  void _sendMessage() async {
    if (_isCaseClosed) return;
    if (_messageController.text.trim().isEmpty || currentUserId == null) return;

    final String text = _messageController.text.trim();
    final Map<String, dynamic>? replyData = _replyMessage;

    _messageController.clear();
    setState(() => _replyMessage = null);

    try {
      await _messagesRef.add({
        'text': text,
        'senderId': currentUserId,
        'senderName': _lawyerName ?? "Lawyer",
        'timestamp': FieldValue.serverTimestamp(),
        'deletedFor': [],
        'isDeletedForEveryone': false,
        'isRead': false,
        'readBy': [currentUserId],
        'replyTo': replyData != null ? {
          'text': replyData['text'],
          'senderName': replyData['senderName'],
        } : null,
      });

      if (!isGroupChat) {
        DocumentReference chatDoc = FirebaseFirestore.instance.collection('chat').doc(effectiveChatId);
        await chatDoc.set({
          'lastMessage': text,
          'lastMessageTime': FieldValue.serverTimestamp(),
          'lastSenderId': currentUserId,
          'isRead': false,
          'readBy': [currentUserId],
          'updatedAt': FieldValue.serverTimestamp(),
          'users': FieldValue.arrayUnion([currentUserId, widget.clientId]),
          'clientName': widget.clientName,
          'status': 'Active',
        }, SetOptions(merge: true));
      }

      _scrollToBottom();
    } catch (e) {
      debugPrint("Chat Sync Error: $e");
    }
  }

  void _deleteForMe(String messageId) async {
    if (currentUserId == null) return;
    try {
      await _messagesRef.doc(messageId).update({
        'deletedFor': FieldValue.arrayUnion([currentUserId]),
      });
    } catch (e) {
      debugPrint("Delete For Me Error: $e");
    }
  }

  void _deleteForEveryone(String messageId) async {
    try {
      await _messagesRef.doc(messageId).update({
        'text': 'This message was deleted',
        'isDeletedForEveryone': true,
        'replyTo': null,
      });
    } catch (e) {
      debugPrint("Delete For Everyone Error: $e");
    }
  }

  void _showDeleteOptions(String messageId, bool isMe, bool isAlreadyDeleted) {
    if (isAlreadyDeleted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Message?"),
        content: const Text("Choose how you want to delete this message:"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              _deleteForMe(messageId);
              Navigator.pop(context);
            },
            child: const Text("Delete for Me", style: TextStyle(color: Colors.red)),
          ),
          if (isMe)
            TextButton(
              onPressed: () {
                _deleteForEveryone(messageId);
                Navigator.pop(context);
              },
              child: const Text("Delete for Everyone", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(0.0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  String _formatTime(Timestamp? ts) {
    if (ts == null) return "...";
    return DateFormat('hh:mm a').format(ts.toDate());
  }

  @override
  Widget build(BuildContext context) {
    const Color navyBlue = Color(0xFF101D3D);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: navyBlue,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          widget.clientName,
          style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _messagesRef.orderBy('timestamp', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                final docs = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  List deletedFor = data['deletedFor'] ?? [];
                  return !deletedFor.contains(currentUserId);
                }).toList();

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _markMessagesAsRead(docs);
                });

                return ListView.builder(
                  reverse: true,
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final bool isMe = data['senderId'] == currentUserId;
                    final String senderName = data['senderName'] ?? "Lawyer";
                    final ts = data['timestamp'] as Timestamp?;
                    final bool isDeletedForEveryone = data['isDeletedForEveryone'] ?? false;

                    return Dismissible(
                      key: Key(doc.id),
                      direction: isDeletedForEveryone ? DismissDirection.none : DismissDirection.startToEnd,
                      confirmDismiss: (direction) async {
                        if (_isCaseClosed) return false;
                        setState(() => _replyMessage = data);
                        return false;
                      },
                      background: Container(
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.only(left: 20),
                        child: const Icon(Icons.reply, color: Colors.grey),
                      ),
                      child: GestureDetector(
                        onLongPress: () => _isCaseClosed ? null : _showDeleteOptions(doc.id, isMe, isDeletedForEveryone),
                        child: Align(
                          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                          child: Column(
                            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                            children: [
                              Container(
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                                decoration: BoxDecoration(
                                  color: isDeletedForEveryone
                                      ? Colors.grey[300]
                                      : (isMe ? navyBlue : Colors.white),
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(15),
                                    topRight: const Radius.circular(15),
                                    bottomLeft: isMe ? const Radius.circular(15) : Radius.zero,
                                    bottomRight: isMe ? Radius.zero : const Radius.circular(15),
                                  ),
                                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 2)],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (isGroupChat && !isMe && !isDeletedForEveryone)
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 4),
                                        child: Text(
                                          senderName,
                                          style: const TextStyle(
                                            color: Color(0xFFC5A358),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                    if (data['replyTo'] != null && !isDeletedForEveryone)
                                      Container(
                                        margin: const EdgeInsets.only(bottom: 5),
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withAlpha(13),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(data['replyTo']['senderName'] ?? "User", style: TextStyle(color: isMe ? Colors.amber : navyBlue, fontWeight: FontWeight.bold, fontSize: 11)),
                                            Text(data['replyTo']['text'] ?? "", maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: isMe ? Colors.white70 : Colors.black54, fontSize: 12)),
                                          ],
                                        ),
                                      ),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (isDeletedForEveryone) ...[
                                          const Icon(Icons.block, size: 14, color: Colors.black54),
                                          const SizedBox(width: 5),
                                        ],
                                        Flexible(
                                          child: Text(
                                            data['text'] ?? "",
                                            style: TextStyle(
                                              color: isDeletedForEveryone
                                                  ? Colors.black54
                                                  : (isMe ? Colors.white : Colors.black87),
                                              fontSize: 15,
                                              fontStyle: isDeletedForEveryone ? FontStyle.italic : FontStyle.normal,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                                child: Text(_formatTime(ts), style: TextStyle(color: Colors.grey[600], fontSize: 10)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          if (_replyMessage != null && !_isCaseClosed) _buildReplyPreview(),
          if (!_isCaseClosed) _buildInputArea(navyBlue)
          else Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            width: double.infinity,
            child: const Text(
              "This case has been closed. You cannot send new messages.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReplyPreview() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: Colors.grey[200], border: const Border(left: BorderSide(color: Color(0xFF101D3D), width: 4))),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_replyMessage!['senderName'] ?? "User", style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF101D3D))),
                Text(_replyMessage!['text'] ?? "", maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => setState(() => _replyMessage = null)),
        ],
      ),
    );
  }

  Widget _buildInputArea(Color navyBlue) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)]),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                decoration: InputDecoration(
                  hintText: "Type a message...",
                  filled: true,
                  fillColor: Colors.grey[100],
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                ),
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: navyBlue,
              radius: 22,
              child: IconButton(
                icon: const Icon(Icons.send, color: Colors.white, size: 18),
                onPressed: _sendMessage,
              ),
            ),
          ],
        ),
      ),
    );
  }
}