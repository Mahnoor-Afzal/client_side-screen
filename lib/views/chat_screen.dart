import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../services/chat_service.dart';

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
  final ChatService _chatService = ChatService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String? _lawyerName;
  Map<String, dynamic>? _replyMessage;
  bool _isCaseClosed = false;
  StreamSubscription? _statusSubscription;

  String? get currentUserId => _chatService.currentUserId;

  bool get isGroupChat => widget.collectionPath != null && widget.collectionPath!.isNotEmpty;

  String get effectiveChatId => widget.consultationId.trim();

  CollectionReference<Map<String, dynamic>> get _messagesRef {
    String path = isGroupChat ? widget.collectionPath! : 'chat/$effectiveChatId/messages';
    return FirebaseFirestore.instance.collection(path);
  }

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _checkCaseStatus();
  }

  void _loadProfile() async {
    if (currentUserId == null) return;
    final profile = await _chatService.getUserProfile(currentUserId!);
    if (profile != null && mounted) {
      setState(() {
        _lawyerName = profile['fullName'] ?? profile['name'] ?? "Lawyer";
      });
    }
  }

  void _checkCaseStatus() {
    _statusSubscription?.cancel();
    _statusSubscription = _chatService
        .getCaseStatusStream(
          effectiveChatId,
          isGroupChat ? widget.collectionPath!.split('/')[0] : 'chat',
          requestId: widget.consultationId.trim(),
        )
        .listen((isClosed) {
      if (mounted) setState(() => _isCaseClosed = isClosed);
    });
  }

  @override
  void dispose() {
    _statusSubscription?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _closeChat() async {
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Close Chat?"),
        content: const Text("Once closed, no further messages can be sent by you or the client."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Close", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    ) ?? false;

    if (!confirm) return;
    await _chatService.closeCase(effectiveChatId, widget.consultationId.trim());
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Chat closed"), backgroundColor: Colors.redAccent));
    }
  }

  void _sendMessage() async {
    if (_isCaseClosed || _messageController.text.trim().isEmpty) return;

    final String text = _messageController.text.trim();
    final Map<String, dynamic>? replyData = _replyMessage;

    _messageController.clear();
    setState(() => _replyMessage = null);

    await _chatService.sendMessage(
      chatId: effectiveChatId,
      text: text,
      senderName: _lawyerName ?? "Lawyer",
      senderRole: "Lawyer",
      targetCollection: isGroupChat ? widget.collectionPath!.split('/')[0] : 'chat',
      receiverId: widget.clientId,
      replyTo: replyData != null ? {'text': replyData['text'], 'senderName': replyData['senderName']} : null,
      extraChatData: isGroupChat ? null : {
        'users': FieldValue.arrayUnion([currentUserId, widget.clientId]),
        'clientName': widget.clientName,
      },
    );
    _scrollToBottom();
  }

  void _deleteForMe(String messageId) async {
    await _chatService.deleteMessage(
      chatId: effectiveChatId,
      messageId: messageId,
      targetCollection: isGroupChat ? widget.collectionPath!.split('/')[0] : 'chat',
      forEveryone: false,
    );
  }

  void _deleteForEveryone(String messageId) async {
    await _chatService.deleteMessage(
      chatId: effectiveChatId,
      messageId: messageId,
      targetCollection: isGroupChat ? widget.collectionPath!.split('/')[0] : 'chat',
      forEveryone: true,
    );
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
              child: const Text("Delete from Everyone", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
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
        actions: [
          if (!_isCaseClosed)
            IconButton(
              icon: const Icon(Icons.close_fullscreen, color: Colors.white70),
              tooltip: "Close Consultation",
              onPressed: _closeChat,
            ),
        ],
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
                  _chatService.markAsRead(effectiveChatId, isGroupChat ? widget.collectionPath!.split('/')[0] : 'chat');
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