import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import '../services/chat_service.dart';
import '../services/coordination_service.dart';
import '../models/coordination_request.dart';
import '../models/lawyer_profile.dart';
import '../models/case_model.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher_string.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'dart:io';

const Color kNavyBlue = Color(0xFF101D3D);
const Color kGoldColor = Color(0xFFC5A358);

// Safe Date Parsing Helper
String safeFormatDate(dynamic dateVal) {
  if (dateVal == null) return 'N/A';
  if (dateVal is Timestamp) {
    DateTime dt = dateVal.toDate();
    return "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}";
  }
  return dateVal.toString();
}

// CROSS-PLATFORM DOWNLOAD & VIEW HELPER
// ==========================================
Future<void> downloadFile(BuildContext context, String fileUrl, String fileName) async {
  if (fileUrl.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("File URL is missing."), backgroundColor: Colors.orange),
    );
    return;
  }

  try {
    // 1. Get local path
    final directory = await getApplicationDocumentsDirectory();
    final safeFileName = fileName.replaceAll(RegExp(r'[^\w\s\.-]'), '_');
    final filePath = "${directory.path}/$safeFileName";
    final file = File(filePath);

    // 2. Check if already exists
    if (await file.exists()) {
      await OpenFilex.open(filePath);
      return;
    }

    // 3. Download if not exists
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Downloading $fileName..."), duration: const Duration(seconds: 1)),
      );
    }

    final response = await http.get(Uri.parse(fileUrl));
    if (response.statusCode == 200) {
      await file.writeAsBytes(response.bodyBytes);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Download complete!"), backgroundColor: Colors.green),
        );
      }
      await OpenFilex.open(filePath);
    } else {
      throw Exception("Failed to download file");
    }
  } catch (e) {
    debugPrint("Download Error: $e");
    // Fallback to URL launcher if download fails
    if (await canLaunchUrlString(fileUrl)) {
      await launchUrlString(fileUrl, mode: LaunchMode.externalApplication);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    }
  }
}

// Helper to check if file is already downloaded
Future<bool> isFileDownloaded(String fileName) async {
  final directory = await getApplicationDocumentsDirectory();
  final safeFileName = fileName.replaceAll(RegExp(r'[^\w\s\.-]'), '_');
  final file = File("${directory.path}/$safeFileName");
  return await file.exists();
}

class CoordinationScreen extends StatefulWidget {
  final int initialTab;
  const CoordinationScreen({super.key, this.initialTab = 0});

  @override
  State<CoordinationScreen> createState() => _CoordinationScreenState();
}

class _CoordinationScreenState extends State<CoordinationScreen> {
  final CoordinationService _coordinationService = CoordinationService();
  String searchQuery = "";
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String? uid = FirebaseAuth.instance.currentUser?.uid;

    return DefaultTabController(
      length: 4,
      initialIndex: widget.initialTab,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        appBar: AppBar(
          title: const Text("Lawyer Coordination", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          backgroundColor: kNavyBlue,
          iconTheme: const IconThemeData(color: Colors.white),
          bottom: const TabBar(
            indicatorColor: kGoldColor,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            isScrollable: true,
            tabs: [
              Tab(text: "My Teams", icon: Icon(Icons.group)),
              Tab(text: "Coordinated Cases", icon: Icon(Icons.folder_shared)),
              Tab(text: "Requests", icon: Icon(Icons.mark_email_unread_outlined)),
              Tab(text: "Verified Lawyers", icon: Icon(Icons.verified_user)),
            ],
          ),
        ),
        body: uid == null
            ? const Center(child: Text("Please login to see coordination data"))
            : Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  setState(() {
                    searchQuery = value.toLowerCase();
                  });
                },
                decoration: InputDecoration(
                  hintText: "Search by name",
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                ),
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _MyTeamsTab(uid: uid, searchQuery: searchQuery, service: _coordinationService),
                  _CoordinatedCasesTab(uid: uid, searchQuery: searchQuery),
                  _RequestsTab(currentUid: uid, searchQuery: searchQuery, service: _coordinationService),
                  _VerifiedLawyersTab(currentUid: uid, searchQuery: searchQuery, service: _coordinationService),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 1. MY TEAMS TAB WIDGET
// ==========================================
class _MyTeamsTab extends StatelessWidget {
  final String uid;
  final String searchQuery;
  final CoordinationService service;
  const _MyTeamsTab({required this.uid, required this.searchQuery, required this.service});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<CoordinationRequest>>(
      stream: service.getAcceptedRequests(uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptyState();
        }

        var myCoordinationDocs = snapshot.data!.where((req) {
          String senderId = (req.senderId ?? '').trim();
          String receiverId = (req.receiverId ?? '').trim();
          String clientName = (req.clientName ?? '').toLowerCase();
          String caseId = (req.caseId ?? '').toLowerCase();

          // Show for Main Lawyer (Sender) OR Supporting Lawyer (Receiver/Team)
          bool isIncluded = senderId == uid || receiverId == uid || (req.users?.contains(uid) ?? false);

          if (!isIncluded) return false;

          return clientName.contains(searchQuery) || caseId.contains(searchQuery);
        }).toList();

        if (myCoordinationDocs.isEmpty) return _buildEmptyState();

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: myCoordinationDocs.length,
          itemBuilder: (context, index) {
            var req = myCoordinationDocs[index];
            String caseId = req.caseId ?? '';

            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('suit_a_file_request').doc(caseId).get(),
              builder: (context, caseSnapshot) {
                Map<String, dynamic> caseData = {};
                if (caseSnapshot.hasData && caseSnapshot.data!.exists) {
                  caseData = caseSnapshot.data!.data() as Map<String, dynamic>;
                } else {
                  // Fallback to 'cases' collection
                  return FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance.collection('cases').doc(caseId).get(),
                    builder: (context, fallbackSnap) {
                      Map<String, dynamic> fallbackData = {};
                      if (fallbackSnap.hasData && fallbackSnap.data!.exists) {
                        fallbackData = fallbackSnap.data!.data() as Map<String, dynamic>;
                      }
                      fallbackData['clientName'] = fallbackData['clientName'] ?? req.clientName;

                      return CoordinationCard(
                        caseId: caseId,
                        data: fallbackData,
                        currentUid: uid,
                        service: service,
                      );
                    },
                  );
                }
                caseData['clientName'] = caseData['clientName'] ?? req.clientName;

                return CoordinationCard(
                  caseId: caseId,
                  data: caseData,
                  currentUid: uid,
                  service: service,
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.group_off_outlined, size: 70, color: Colors.grey[300]),
          const SizedBox(height: 10),
          Text(
            searchQuery.isEmpty ? "No active team coordination found" : "No results for \"$searchQuery\"",
            style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// TEAM CHAT FULL SCREEN SCREEN
// ==========================================
class TeamChatScreen extends StatefulWidget {
  final String caseId;
  final String clientName;
  final String currentUid;

  const TeamChatScreen({
    super.key,
    required this.caseId,
    required this.clientName,
    required this.currentUid,
  });

  @override
  State<TeamChatScreen> createState() => _TeamChatScreenState();
}

class _TeamChatScreenState extends State<TeamChatScreen> {
  final TextEditingController _msgController = TextEditingController();
  final ChatService _chatService = ChatService();
  String _currentUserName = "User";
  String _currentUserRole = "Client";
  Map<String, dynamic>? _replyingToMessage;
  String? _groupChatDocId;

  @override
  void initState() {
    super.initState();
    _fetchCurrentUserName();
    _initializeChat();
  }

  Future<void> _initializeChat() async {
    final id = await _chatService.getOrCreateGroupChatId(widget.caseId, widget.clientName);
    if (mounted) {
      setState(() {
        _groupChatDocId = id;
      });
    }
  }

  Future<void> _fetchCurrentUserName() async {
    final profile = await _chatService.getUserProfile(widget.currentUid);
    if (profile != null && mounted) {
      setState(() {
        _currentUserName = profile['fullName'] ?? profile['name'] ?? "User";
        _currentUserRole = profile['role'] ?? (profile['isLawyer'] == true ? "Lawyer" : "Client");
      });
    }
  }

  void _sendMessage() async {
    String text = _msgController.text.trim();
    if (text.isEmpty || _groupChatDocId == null) return;

    _msgController.clear();
    var replyData = _replyingToMessage;
    setState(() {
      _replyingToMessage = null;
    });

    Map<String, dynamic>? replyTo;
    if (replyData != null) {
      replyTo = {
        'replyToMessage': replyData['message'],
        'replyToSender': replyData['senderName'],
      };
    }

    await _chatService.sendMessage(
      chatId: _groupChatDocId!,
      text: text,
      senderName: _currentUserName,
      senderRole: _currentUserRole,
      targetCollection: 'group_chats',
      replyTo: replyTo,
    );
  }

  void _deleteMessage(String docId, String senderId, bool deleteForEveryone) async {
    if (_groupChatDocId == null) return;
    await _chatService.deleteMessage(
      chatId: _groupChatDocId!,
      messageId: docId,
      targetCollection: 'group_chats',
      forEveryone: deleteForEveryone,
    );
  }

  void _showDeleteOptions(BuildContext context, String docId, String senderId) {
    bool isMyMessage = (senderId == widget.currentUid);

    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text("Delete for Me"),
              onTap: () {
                Navigator.pop(ctx);
                _deleteMessage(docId, senderId, false);
              },
            ),
            if (isMyMessage)
              ListTile(
                leading: const Icon(Icons.delete_forever, color: Colors.red),
                title: const Text("Delete for Everyone"),
                onTap: () {
                  Navigator.pop(ctx);
                  _deleteMessage(docId, senderId, true);
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: kNavyBlue,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Row(
          children: [
            const Icon(Icons.forum, color: kGoldColor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                "Team Chat - ${widget.clientName}",
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _groupChatDocId == null
                ? const Center(child: CircularProgressIndicator())
                : StreamBuilder<QuerySnapshot>(
                    stream: _chatService.getMessagesStream(_groupChatDocId!, 'group_chats'),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const Center(
                          child: Text("No messages yet. Start team discussion!", style: TextStyle(color: Colors.grey)),
                        );
                      }

                      var messages = snapshot.data!.docs;

                      return ListView.builder(
                        reverse: true,
                        padding: const EdgeInsets.all(12),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          var doc = messages[index];
                          var data = doc.data() as Map<String, dynamic>;

                          List deletedFor = data['deletedFor'] ?? [];
                          if (deletedFor.contains(widget.currentUid)) {
                            return const SizedBox.shrink();
                          }

                          bool isMe = data['senderId'] == widget.currentUid;
                          String senderName = data['senderName'] ?? 'User';
                          String senderRole = (data['senderRole'] ?? 'Client').toString().toUpperCase();
                          bool isLawyer = senderRole == 'LAWYER';

                          bool isDeleted = data['isDeleted'] == true || data['isDeletedForEveryone'] == true;
                          String messageText = data['message'] ?? data['text'] ?? '';
                          
                          Map<String, dynamic>? replyTo = data['replyTo'];
                          String? replyText = replyTo?['replyToMessage'] ?? data['replyToMessage'];
                          String? replySender = replyTo?['replyToSender'] ?? data['replyToSender'];

                        Widget messageWidget = Align(
                          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                          child: GestureDetector(
                            onLongPress: () => _showDeleteOptions(context, doc.id, data['senderId']),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: isMe ? kNavyBlue : Colors.grey.shade200,
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(12),
                                  topRight: const Radius.circular(12),
                                  bottomLeft: isMe ? const Radius.circular(12) : Radius.zero,
                                  bottomRight: isMe ? Radius.zero : const Radius.circular(12),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: isLawyer ? Colors.green.shade100 : Colors.blue.shade100,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          senderRole,
                                          style: TextStyle(
                                            fontSize: 8,
                                            fontWeight: FontWeight.bold,
                                            color: isLawyer ? Colors.green.shade900 : Colors.blue.shade900,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        isMe ? "You" : senderName,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: isMe ? kGoldColor : Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  if (replyText != null && replyText.isNotEmpty) ...[
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      margin: const EdgeInsets.only(bottom: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.black12,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border(left: BorderSide(color: isMe ? kGoldColor : kNavyBlue, width: 3)),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(replySender ?? '', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isMe ? kGoldColor : kNavyBlue)),
                                          Text(replyText, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: isMe ? Colors.white70 : Colors.black54)),
                                        ],
                                      ),
                                    ),
                                  ],
                                  Text(
                                    messageText,
                                    style: TextStyle(
                                      color: isMe ? Colors.white : Colors.black87,
                                      fontSize: 14,
                                      fontStyle: isDeleted ? FontStyle.italic : FontStyle.normal,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );

                        return Dismissible(
                          key: Key(doc.id),
                          direction: DismissDirection.startToEnd,
                          confirmDismiss: (_) async {
                            setState(() {
                              _replyingToMessage = {
                                'message': messageText,
                                'senderName': isMe ? 'You' : senderName,
                              };
                            });
                            return false;
                          },
                          background: Container(
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.only(left: 20),
                            color: Colors.transparent,
                            child: const Icon(Icons.reply, color: kNavyBlue, size: 24),
                          ),
                          child: messageWidget,
                        );
                      },
                    );
                  },
                ),
          ),
          if (_replyingToMessage != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: Colors.grey.shade200,
              child: Row(
                children: [
                  const Icon(Icons.reply, size: 16, color: kNavyBlue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Replying to ${_replyingToMessage!['senderName']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: kNavyBlue)),
                        Text(_replyingToMessage!['message'], maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: () => setState(() => _replyingToMessage = null),
                  ),
                ],
              ),
            ),
          StreamBuilder<bool>(
            stream: _chatService.getCaseStatusStream(widget.caseId, 'suit_a_file_request'),
            builder: (context, statusSnap) {
              bool isClosed = statusSnap.data ?? false;

              if (isClosed) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    border: Border(top: BorderSide(color: Colors.red.shade100)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lock_clock_outlined, color: Colors.red, size: 20),
                      SizedBox(width: 10),
                      Text(
                        "This case is closed. New messages are disabled.",
                        style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                );
              }

              return Container(
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, -2))
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _msgController,
                        maxLines: null,
                        keyboardType: TextInputType.multiline,
                        decoration: const InputDecoration(
                          hintText: "Type message...",
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.send, color: kNavyBlue),
                      onPressed: _sendMessage,
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 2. COORDINATED CASES TAB
// ==========================================
class _CoordinatedCasesTab extends StatelessWidget {
  final String uid;
  final String searchQuery;
  const _CoordinatedCasesTab({required this.uid, required this.searchQuery});

  void _showHearingHistory(BuildContext context, String caseId, String clientName) {
    showModalBottomSheet(
      context: context,
      backgroundColor: kNavyBlue,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "History: $clientName",
                    style: const TextStyle(color: kGoldColor, fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(color: Colors.white24),
              const SizedBox(height: 10),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('Hearings')
                      .doc(caseId)
                      .collection('history')
                      .orderBy('createdTimeStamp', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: Colors.white));
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(
                        child: Text("No hearing history records found.", style: TextStyle(color: Colors.white54)),
                      );
                    }

                    var historyDocs = snapshot.data!.docs;

                    return ListView.builder(
                      itemCount: historyDocs.length,
                      itemBuilder: (context, index) {
                        var hData = historyDocs[index].data() as Map<String, dynamic>;
                        String historyDate = safeFormatDate(hData['hearingDate'] ?? hData['hearing_date']);

                        return Card(
                          color: Colors.white.withValues(alpha: 0.1),
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            leading: const Icon(Icons.event_available, color: kGoldColor),
                            title: Text(
                              "Date: $historyDate",
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              "Time: ${hData['hearingTime'] ?? hData['hearing_time'] ?? 'N/A'}\nLocation: ${hData['courtLocation'] ?? hData['court_location'] ?? 'N/A'}",
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showHearingsDialog(BuildContext context, String caseId, String clientName) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("Scheduled Hearings", style: TextStyle(fontWeight: FontWeight.bold, color: kNavyBlue, fontSize: 16)),
            InkWell(
              onTap: () => _showHearingHistory(context, caseId, clientName),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: kGoldColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: kGoldColor),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.history, size: 12, color: kNavyBlue),
                    SizedBox(width: 4),
                    Text("History", style: TextStyle(color: kNavyBlue, fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('Hearings').doc(caseId).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || !snapshot.data!.exists) {
                return const Center(
                  child: Text("No scheduled hearing details found for this case.", style: TextStyle(color: Colors.grey), textAlign: TextAlign.center),
                );
              }

              var hData = snapshot.data!.data() as Map<String, dynamic>;

              if (hData['isSaved'] != true) {
                return const Center(
                  child: Text("No saved hearing details available.", style: TextStyle(color: Colors.grey), textAlign: TextAlign.center),
                );
              }

              String hearingDate = safeFormatDate(hData['hearing_date'] ?? hData['hearingDate']);
              String hearingTime = (hData['hearing_time'] ?? hData['hearingTime'] ?? "N/A").toString();
              String courtLocation = (hData['court_location'] ?? hData['courtLocation'] ?? "Not Set").toString();

              return SingleChildScrollView(
                child: Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(14.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(clientName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: kNavyBlue)),
                        const SizedBox(height: 6),
                        Text("Date: $hearingDate", style: const TextStyle(color: kGoldColor, fontWeight: FontWeight.bold)),
                        const Divider(height: 15),
                        Row(
                          children: [
                            const Icon(Icons.access_time, size: 16, color: Colors.grey),
                            const SizedBox(width: 6),
                            Text(hearingTime, style: const TextStyle(color: Colors.black87, fontSize: 13)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.location_on, size: 16, color: Colors.grey),
                            const SizedBox(width: 6),
                            Expanded(child: Text(courtLocation, style: const TextStyle(color: Colors.black87, fontSize: 13), overflow: TextOverflow.ellipsis)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close")),
        ],
      ),
    );
  }

  void _showDocumentsDialog(BuildContext context, String caseId, Map<String, dynamic> caseData) {
    String clientId = caseData['clientId'] ?? caseData['clientid'] ?? caseData['userId'] ?? '';
    String leadLawyerId = caseData['lawyerid'] ?? caseData['lawyerId'] ?? caseData['leadLawyerId'] ?? '';
    String clientName = caseData['clientName'] ?? caseData['client_name'] ?? caseData['userName'] ?? 'Client';
    String leadLawyerName = caseData['leadLawyerName'] ?? dataLeadNameCheck(caseData) ?? 'Lead Lawyer';

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Case Documents Vault", style: TextStyle(fontWeight: FontWeight.bold, color: kNavyBlue, fontSize: 16)),
            SizedBox(height: 4),
            Text("Shared documents between Client & Lawyers", style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 420,
          child: FutureBuilder<DocumentSnapshot>(
            future: leadLawyerId.isNotEmpty
                ? FirebaseFirestore.instance.collection('verified_lawyers').doc(leadLawyerId).get()
                : null,
            builder: (context, lawyerNameSnap) {
              if (lawyerNameSnap.hasData && lawyerNameSnap.data != null && lawyerNameSnap.data!.exists) {
                var lData = lawyerNameSnap.data!.data() as Map<String, dynamic>?;
                if (lData != null) {
                  leadLawyerName = lData['fullName'] ?? lData['name'] ?? leadLawyerName;
                }
              }

              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('cases')
                    .doc(caseId)
                    .collection('documents')
                    .snapshots(),
                builder: (context, subDocSnap) {
                  return StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('documents').snapshots(),
                    builder: (context, rootDocSnap) {
                      if (subDocSnap.connectionState == ConnectionState.waiting && rootDocSnap.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      List<Map<String, dynamic>> allDocuments = [];

                      if (caseData['fileUrl'] != null && caseData['fileUrl'].toString().isNotEmpty) {
                        allDocuments.add({
                          'title': caseData['fileName'] ?? caseData['documentTitle'] ?? "Primary Case Petition",
                          'url': caseData['fileUrl'],
                          'sender': clientName,
                          'type': 'primary',
                          'createdAt': caseData['createdAt'] ?? caseData['timestamp'],
                        });
                      }

                      if (caseData['vakalatnamaUrl'] != null && caseData['vakalatnamaUrl'].toString().isNotEmpty) {
                        allDocuments.add({
                          'title': "Vakalatnama (Signed Power of Attorney)",
                          'url': caseData['vakalatnamaUrl'],
                          'sender': leadLawyerName,
                          'type': 'vakalatnama',
                          'createdAt': caseData['vakalatnamaCreatedAt'] ?? caseData['createdAt'] ?? caseData['timestamp'],
                        });
                      }

                      if (subDocSnap.hasData) {
                        for (var d in subDocSnap.data!.docs) {
                          var data = d.data() as Map<String, dynamic>;
                          String uploaderName = data['uploadedBy'] ?? leadLawyerName;
                          String uploaderRole = data['uploadedByRole'] ?? '';

                          if (uploaderRole == 'Lead Lawyer' || data['uploadedById'] == leadLawyerId || uploaderName == 'User' || uploaderName == leadLawyerId) {
                            uploaderName = leadLawyerName;
                          }

                          allDocuments.add({
                            'title': data['fileName'] ?? data['title'] ?? data['name'] ?? 'Shared Document',
                            'url': data['fileUrl'] ?? data['url'] ?? data['path'] ?? '',
                            'sender': uploaderName,
                            'status': data['status'] ?? '',
                            'createdAt': data['createdAt'] ?? data['timestamp'],
                          });
                        }
                      }

                      if (rootDocSnap.hasData) {
                        for (var d in rootDocSnap.data!.docs) {
                          var data = d.data() as Map<String, dynamic>;
                          String docCaseId = (data['caseId'] ?? data['consultationId'] ?? '').toString();
                          String docClientId = (data['clientId'] ?? data['senderId'] ?? '').toString();
                          String docLawyerId = (data['lawyerId'] ?? data['receiverId'] ?? '').toString();

                          bool isMatchingCase = (docCaseId == caseId) ||
                              (clientId.isNotEmpty && docClientId == clientId && leadLawyerId.isNotEmpty && docLawyerId == leadLawyerId);

                          if (isMatchingCase) {
                            String url = data['fileUrl'] ?? data['url'] ?? data['path'] ?? '';
                            if (url.isNotEmpty && !allDocuments.any((element) => element['url'] == url)) {
                              String uploaderName = data['uploadedBy'] ?? data['senderName'] ?? leadLawyerName;
                              String uploaderRole = data['uploadedByRole'] ?? '';

                              if (uploaderRole == 'Lead Lawyer' || data['uploadedById'] == leadLawyerId || uploaderName == 'User' || uploaderName == leadLawyerId) {
                                uploaderName = leadLawyerName;
                              }

                              allDocuments.add({
                                'title': data['fileName'] ?? data['title'] ?? data['name'] ?? 'Document Vault File',
                                'url': url,
                                'sender': uploaderName,
                                'status': data['status'] ?? '',
                                'createdAt': data['createdAt'] ?? data['timestamp'],
                              });
                            }
                          }
                        }
                      }

                      allDocuments.sort((a, b) {
                        var timeA = a['createdAt'];
                        var timeB = b['createdAt'];
                        if (timeA is Timestamp && timeB is Timestamp) {
                          return timeB.compareTo(timeA);
                        }
                        return 0;
                      });

                      if (allDocuments.isEmpty) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Text("No documents found in Vault for this case.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                          ),
                        );
                      }

                      return ListView.builder(
                        itemCount: allDocuments.length,
                        itemBuilder: (context, index) {
                          var item = allDocuments[index];
                          String title = item['title'];
                          String url = item['url'];
                          String sender = item['sender'];
                          String status = item['status'] ?? '';
                          var rawDate = item['createdAt'];
                          String formattedDate = rawDate is Timestamp ? safeFormatDate(rawDate) : "N/A";

                          bool isVakalatnama = item['type'] == 'vakalatnama' || title.toLowerCase().contains('vakalatnama');

                          return Card(
                            elevation: 1,
                            margin: const EdgeInsets.only(bottom: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: isVakalatnama ? Colors.green.shade50 : kNavyBlue.withValues(alpha: 0.1),
                                child: Icon(
                                  isVakalatnama ? Icons.verified : Icons.insert_drive_file,
                                  color: isVakalatnama ? Colors.green : kNavyBlue,
                                ),
                              ),
                              title: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis),
                                  ),
                                  if (status.isNotEmpty)
                                    Flexible(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                        decoration: BoxDecoration(color: Colors.green.shade100, borderRadius: BorderRadius.circular(4)),
                                        child: Text(
                                          status.toUpperCase(),
                                          style: const TextStyle(fontSize: 8, color: Colors.green, fontWeight: FontWeight.bold),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              subtitle: Text("From: $sender\nDate: $formattedDate", style: const TextStyle(fontSize: 11, color: Colors.grey)),
                              isThreeLine: true,
                              trailing: FutureBuilder<bool>(
                                future: isFileDownloaded(title),
                                builder: (context, snapshot) {
                                  bool exists = snapshot.data ?? false;
                                  return IconButton(
                                    icon: Icon(
                                      exists ? Icons.visibility : Icons.file_download,
                                      color: exists ? kNavyBlue : Colors.green,
                                    ),
                                    tooltip: exists ? "View Document" : "Download File",
                                    onPressed: () async {
                                      await downloadFile(context, url, title);
                                      // Trigger rebuild to update icon
                                      (context as Element).markNeedsBuild();
                                    },
                                  );
                                },
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close")),
        ],
      ),
    );
  }

  String? dataLeadNameCheck(Map<String, dynamic> data) {
    return data['leadLawyerName'] ?? data['lawyerName'];
  }

  void _showUploadDialog(BuildContext context, String caseId, String uid) {
    showDialog(
      context: context,
      builder: (_) => SupportingLawyerUploadDialog(caseId: caseId, uid: uid),
    );
  }

  Widget _buildResponsiveActionButton({
    required double width,
    required Color color,
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: width,
      height: 36,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: 1,
        ),
        onPressed: onPressed,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12),
            const SizedBox(width: 2),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('coordination_requests').where('status', isEqualTo: 'Accepted').snapshots(),
      builder: (context, coordSnapshot) {
        if (coordSnapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

        if (!coordSnapshot.hasData || coordSnapshot.data!.docs.isEmpty) {
          return Center(child: Text(searchQuery.isEmpty ? "No coordinated cases found." : "No results for \"$searchQuery\"", style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)));
        }

        List<String> acceptedCaseIds = coordSnapshot.data!.docs.where((doc) {
          var data = doc.data() as Map<String, dynamic>;
          String senderId = (data['senderId'] ?? '').toString().trim();
          String receiverId = (data['receiverId'] ?? '').toString().trim();
          List users = data['users'] ?? [];

          // Only show for Supporting Lawyers (Receiver or Team Member)
          // AND exclude if the user is the Main Lawyer (Sender)
          return (receiverId == uid || users.contains(uid)) && senderId != uid;
        }).map((doc) {
          var data = doc.data() as Map<String, dynamic>;
          return (data['caseId'] ?? '').toString();
        }).where((id) => id.isNotEmpty).toList();

        if (acceptedCaseIds.isEmpty) {
          return Center(child: Text(searchQuery.isEmpty ? "No coordinated cases found." : "No results for \"$searchQuery\"", style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)));
        }

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('suit_a_file_request').snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

            var caseDocs = snapshot.data?.docs ?? [];

            var coordinatedCases = caseDocs.where((doc) {
              if (!acceptedCaseIds.contains(doc.id)) return false;

              var data = doc.data() as Map<String, dynamic>;
              String clientName = (data['clientName'] ?? data['client_name'] ?? data['userName'] ?? "Client").toString().toLowerCase();
              String caseType = (data['caseType'] ?? data['category'] ?? "Assigned Case").toString().toLowerCase();
              String leadName = (data['leadLawyerName'] ?? data['lawyerName'] ?? "Lead Lawyer").toString().toLowerCase();

              return clientName.contains(searchQuery) || caseType.contains(searchQuery) || leadName.contains(searchQuery);
            }).toList();

            if (coordinatedCases.isEmpty) {
              // Try fallback to 'cases' collection if not found in suit_a_file_request
              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('cases').snapshots(),
                builder: (context, fallbackSnapshot) {
                  if (fallbackSnapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

                  var fallbackDocs = fallbackSnapshot.data?.docs ?? [];
                  var fallbackCoordinated = fallbackDocs.where((doc) {
                    if (!acceptedCaseIds.contains(doc.id)) return false;
                    var data = doc.data() as Map<String, dynamic>;
                    String clientName = (data['clientName'] ?? data['client_name'] ?? data['userName'] ?? "Client").toString().toLowerCase();
                    return clientName.contains(searchQuery);
                  }).toList();

                  if (fallbackCoordinated.isEmpty) {
                    return Center(child: Text(searchQuery.isEmpty ? "You have not been added as a supporting lawyer to any cases." : "No results for \"$searchQuery\"", style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)));
                  }

                  return _buildCaseList(fallbackCoordinated, context);
                },
              );
            }

            return _buildCaseList(coordinatedCases, context);
          },
        );
      },
    );
  }

  Widget _buildCaseList(List<DocumentSnapshot> cases, BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: cases.length,
      itemBuilder: (context, index) {
        var caseDoc = cases[index];
        var data = caseDoc.data() as Map<String, dynamic>;

        String clientName = data['clientName'] ?? data['client_name'] ?? data['userName'] ?? "Client";
        String caseType = data['caseType'] ?? data['category'] ?? "Assigned Case";
        String leadName = data['leadLawyerName'] ?? data['lawyerName'] ?? "Lead Lawyer";

        return Card(
          elevation: 3,
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
                    Text(clientName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: kNavyBlue)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: kGoldColor.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                      child: const Text("Supporting Lawyer", style: TextStyle(color: kNavyBlue, fontWeight: FontWeight.bold, fontSize: 11)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text("Type: $caseType", style: const TextStyle(color: Colors.grey, fontSize: 13)),
                Text("Main Lawyer: $leadName", style: const TextStyle(color: Colors.black87, fontSize: 12, fontWeight: FontWeight.w500)),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) {
                    double spacing = 4.0;
                    double buttonWidth = (constraints.maxWidth - (spacing * 2)) / 3;

                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildResponsiveActionButton(
                          width: buttonWidth,
                          color: kNavyBlue,
                          icon: Icons.event,
                          label: "Hearings",
                          onPressed: () => _showHearingsDialog(context, caseDoc.id, clientName),
                        ),
                        SizedBox(width: spacing),
                        _buildResponsiveActionButton(
                          width: buttonWidth,
                          color: kGoldColor,
                          icon: Icons.folder,
                          label: "Docs",
                          onPressed: () => _showDocumentsDialog(context, caseDoc.id, data),
                        ),
                        SizedBox(width: spacing),
                        _buildResponsiveActionButton(
                          width: buttonWidth,
                          color: Colors.teal,
                          icon: Icons.cloud_upload,
                          label: "Upload",
                          onPressed: () => _showUploadDialog(context, caseDoc.id, uid),
                        ),
                      ],
                    );
                  },
                )
              ],
            ),
          ),
        );
      },
    );
  }
}

// ==========================================
// SUPPORTING LAWYER DOCUMENT UPLOAD DIALOG
// ==========================================
class SupportingLawyerUploadDialog extends StatefulWidget {
  final String caseId;
  final String uid;

  const SupportingLawyerUploadDialog({super.key, required this.caseId, required this.uid});

  @override
  State<SupportingLawyerUploadDialog> createState() => _SupportingLawyerUploadDialogState();
}

class _SupportingLawyerUploadDialogState extends State<SupportingLawyerUploadDialog> {
  final TextEditingController titleController = TextEditingController();
  PlatformFile? selectedFile;
  bool isUploading = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      title: const Text("Upload Case Document", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: kNavyBlue)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: titleController,
            decoration: const InputDecoration(labelText: "Document Title / Name", border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: kNavyBlue),
              minimumSize: const Size(double.infinity, 45),
            ),
            onPressed: () async {
              FilePickerResult? result = await FilePicker.platform.pickFiles(withData: true);
              if (result != null && result.files.isNotEmpty) {
                setState(() {
                  selectedFile = result.files.first;
                });
              }
            },
            icon: const Icon(Icons.attach_file, color: kNavyBlue),
            label: Text(
              selectedFile != null ? selectedFile!.name : "Select File (PDF / Image)",
              style: const TextStyle(color: kNavyBlue, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel", style: TextStyle(color: Colors.red)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: kNavyBlue),
          onPressed: isUploading
              ? null
              : () async {
            if (titleController.text.trim().isEmpty || selectedFile == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Please provide document title and select a file.")),
              );
              return;
            }

            setState(() {
              isUploading = true;
            });

            try {
              final CoordinationService coordinationService = CoordinationService();
              await coordinationService.uploadCaseDocument(
                caseId: widget.caseId,
                title: titleController.text.trim(),
                file: selectedFile!,
              );

              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Document uploaded successfully!"), backgroundColor: Colors.green),
                );
              }
            } catch (e) {
              if (context.mounted) {
                setState(() {
                  isUploading = false;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
                );
              }
            }
          },
          child: isUploading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text("Upload Document", style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}

// 3. INCOMING REQUESTS TAB WIDGET
// ==========================================
class _RequestsTab extends StatelessWidget {
  final String currentUid;
  final String searchQuery;
  final CoordinationService service;
  const _RequestsTab({required this.currentUid, required this.searchQuery, required this.service});

  Future<void> _handleRequest(BuildContext context, CoordinationRequest request, bool accept) async {
    try {
      await service.handleRequest(request, accept);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(accept ? "Coordination Request Accepted! Team Chat is now active." : "Request Declined"),
            backgroundColor: accept ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error updating request: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<CoordinationRequest>>(
      stream: service.getIncomingRequests(currentUid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
            child: Text("No incoming coordination requests.", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          );
        }

        var requests = snapshot.data!.where((req) {
          String senderName = (req.senderName).toLowerCase();
          String clientName = (req.clientName).toLowerCase();
          return senderName.contains(searchQuery) || clientName.contains(searchQuery);
        }).toList();

        if (requests.isEmpty) {
          return Center(child: Text(searchQuery.isEmpty ? "No incoming coordination requests." : "No results for \"$searchQuery\"", style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: requests.length,
          itemBuilder: (context, index) {
            var req = requests[index];

            return Card(
              elevation: 3,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            "Request from ${req.senderName}",
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: kNavyBlue),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: req.status == 'Pending' ? Colors.amber.shade100 : (req.status == 'Accepted' ? Colors.green.shade100 : Colors.red.shade100),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            req.status,
                            style: TextStyle(
                              color: req.status == 'Pending' ? Colors.amber.shade900 : (req.status == 'Accepted' ? Colors.green.shade900 : Colors.red.shade900),
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text("Client Name: ${req.clientName}", style: const TextStyle(fontSize: 13, color: Colors.black87)),
                    Text("Case Reference ID: ${req.caseId}", style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    const SizedBox(height: 12),

                    if (req.status == 'Pending')
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                              onPressed: () => _handleRequest(context, req, true),
                              icon: const Icon(Icons.check, size: 18),
                              label: const Text("Accept"),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                              onPressed: () => _handleRequest(context, req, false),
                              icon: const Icon(Icons.close, size: 18),
                              label: const Text("Decline"),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// 4. VERIFIED LAWYERS TAB WIDGET
// ==========================================
class _VerifiedLawyersTab extends StatelessWidget {
  final String currentUid;
  final String searchQuery;
  final CoordinationService service;
  const _VerifiedLawyersTab({required this.currentUid, required this.searchQuery, required this.service});

  void _showCaseSelectionDialog(BuildContext context, String targetLawyerId, String targetLawyerName) async {
    try {
      var activeCases = await service.getActiveCasesForCurrentLawyer();
      if (!context.mounted) return;

      if (activeCases.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No Active Cases found assigned to your lawyer account."), backgroundColor: Colors.orange),
        );
        return;
      }

      showDialog(
        context: context,
        builder: (_) => CaseSelectionDialog(
          activeCases: activeCases,
          targetLawyerId: targetLawyerId,
          targetLawyerName: targetLawyerName,
          currentUid: currentUid,
          service: service,
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error fetching cases: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<LawyerProfile>>(
      stream: service.getVerifiedLawyers(currentUid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text("No verified lawyers found", style: TextStyle(color: Colors.grey)));
        }

        var lawyers = snapshot.data!.where((profile) {
          String name = profile.fullName.toLowerCase();
          String category = profile.category.toLowerCase();
          String location = profile.location.toLowerCase();

          return name.contains(searchQuery) || category.contains(searchQuery) || location.contains(searchQuery);
        }).toList();

        if (lawyers.isEmpty) {
          return Center(child: Text(searchQuery.isEmpty ? "No verified lawyers available" : "No results for \"$searchQuery\"", style: const TextStyle(color: Colors.grey)));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: lawyers.length,
          itemBuilder: (context, index) {
            var profile = lawyers[index];

            return Card(
              elevation: 3,
              margin: const EdgeInsets.only(bottom: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: Padding(
                padding: const EdgeInsets.all(15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 35,
                          backgroundColor: Colors.grey[200],
                          backgroundImage: (profile.profileImageUrl != null && profile.profileImageUrl!.isNotEmpty) ? NetworkImage(profile.profileImageUrl!) : null,
                          child: (profile.profileImageUrl == null || profile.profileImageUrl!.isEmpty) ? const Icon(Icons.person, size: 40, color: kNavyBlue) : null,
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(child: Text(profile.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: kNavyBlue), overflow: TextOverflow.ellipsis)),
                                  const SizedBox(width: 5),
                                  const Icon(Icons.verified, color: Colors.blue, size: 18),
                                ],
                              ),
                              Text(profile.category, style: const TextStyle(color: kGoldColor, fontWeight: FontWeight.w600, fontSize: 14)),
                              Text(profile.barCouncil, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(Icons.gavel_rounded, size: 14, color: Colors.grey[600]),
                                  const SizedBox(width: 4),
                                  Expanded(child: Text(profile.court, style: TextStyle(color: Colors.grey[600], fontSize: 11), overflow: TextOverflow.ellipsis)),
                                ],
                              ),
                              Row(
                                children: [
                                  Icon(Icons.location_on, size: 14, color: Colors.grey[600]),
                                  const SizedBox(width: 4),
                                  Text(profile.location, style: TextStyle(color: Colors.grey[600], fontSize: 11)),
                                  const SizedBox(width: 10),
                                  Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                                  const SizedBox(width: 4),
                                  Text("${profile.experience} Exp", style: TextStyle(color: Colors.grey[600], fontSize: 11)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(profile.bio, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: Colors.black87)),
                    const SizedBox(height: 15),
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance.collection('coordination_requests').snapshots(),
                      builder: (context, reqSnapshot) {
                        bool isPending = false;
                        if (reqSnapshot.hasData) {
                          isPending = reqSnapshot.data!.docs.any((rDoc) {
                            var rData = rDoc.data() as Map<String, dynamic>;
                            return rData['senderId'] == currentUid && rData['receiverId'] == profile.id && rData['status'] == 'Pending';
                          });
                        }

                        return SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isPending ? Colors.grey : kNavyBlue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: isPending ? null : () => _showCaseSelectionDialog(context, profile.id, profile.fullName),
                            icon: Icon(isPending ? Icons.hourglass_top : Icons.handshake_outlined, size: 18),
                            label: Text(
                              isPending ? "Request Pending" : "Request Coordination",
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ==========================================
// 5. COORDINATION CARD WIDGET
// ==========================================
class CoordinationCard extends StatelessWidget {
  final String caseId;
  final Map<String, dynamic> data;
  final String currentUid;
  final CoordinationService service;

  const CoordinationCard({
    super.key,
    required this.caseId,
    required this.data,
    required this.currentUid,
    required this.service,
  });

  void _showSharedFilesBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 15),
                  const Text("Lawyer Private Files & Notes", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: kNavyBlue)),
                  const SizedBox(height: 15),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: service.getPrivateLawyerDocumentsStream(caseId),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return const Center(child: Text("No confidential files or notes yet."));
                        }

                        var docs = snapshot.data!.docs;

                        return ListView.builder(
                          controller: scrollController,
                          itemCount: docs.length,
                          itemBuilder: (context, index) {
                            var item = docs[index].data() as Map<String, dynamic>;
                            String title = item['title'] ?? 'Untitled Document';
                            String fileName = item['fileName'] ?? '';
                            String notes = item['notes'] ?? '';
                            String fileUrl = item['fileUrl'] ?? item['url'] ?? item['path'] ?? '';

                            return Card(
                              elevation: 1,
                              margin: const EdgeInsets.symmetric(vertical: 6),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: kNavyBlue.withValues(alpha: 0.1),
                                  child: const Icon(Icons.lock_outline, color: kNavyBlue),
                                ),
                                title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text(
                                  "${fileName.isNotEmpty ? 'File: $fileName\n' : ''}${notes.isNotEmpty ? 'Notes: $notes' : ''}",
                                  style: const TextStyle(fontSize: 12),
                                ),
                                trailing: FutureBuilder<bool>(
                                  future: isFileDownloaded(title),
                                  builder: (context, snapshot) {
                                    bool exists = snapshot.data ?? false;
                                    return IconButton(
                                      icon: Icon(
                                        exists ? Icons.visibility : Icons.file_download,
                                        color: exists ? kNavyBlue : Colors.green,
                                      ),
                                      tooltip: exists ? "View Document" : "Download File",
                                      onPressed: () async {
                                        await downloadFile(context, fileUrl, title);
                                        // Force rebuild to update icon
                                        (context as Element).markNeedsBuild();
                                      },
                                    );
                                  },
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _removeLawyerFromTeam(BuildContext context, String lawyerIdToRemove, String lawyerName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Remove Lawyer"),
        content: Text("Are you sure you want to remove $lawyerName from this team coordination?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await service.removeLawyerFromTeam(caseId, lawyerIdToRemove, lawyerName);

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("$lawyerName removed from team successfully"), backgroundColor: Colors.orange),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Failed to remove lawyer: $e"), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text("Remove", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String clientName = data['clientName'] ?? data['client_name'] ?? data['userName'] ?? data['name'] ?? "Client";
    String caseType = data['caseType'] ?? data['category'] ?? "Legal Matter";
    String leadLawyerId = data['lawyerid'] ?? data['lawyerId'] ?? data['leadLawyerId'] ?? '';
    List assignedLawyersIds = data['assignedLawyers'] ?? [];

    bool isLeadLawyer = (leadLawyerId == currentUid);

    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 16),
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
                    Text(clientName, style: const TextStyle(fontWeight: FontWeight.bold, color: kNavyBlue, fontSize: 18)),
                    Text(caseType, style: const TextStyle(fontSize: 13, color: Colors.grey)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(12)),
                  child: const Text("Collaborating", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 11)),
                )
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),
            const Text("Assigned Team Lawyers:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black54)),
            const SizedBox(height: 6),
            FutureBuilder<QuerySnapshot>(
              future: FirebaseFirestore.instance
                  .collection('verified_lawyers')
                  .where(FieldPath.documentId, whereIn: assignedLawyersIds.isNotEmpty ? assignedLawyersIds : ['none'])
                  .get(),
              builder: (context, lawyerSnap) {
                if (!lawyerSnap.hasData) {
                  return const Text("Loading team lawyers...", style: TextStyle(fontSize: 12, color: Colors.grey));
                }

                return Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: lawyerSnap.data!.docs.map((lDoc) {
                    var lData = lDoc.data() as Map<String, dynamic>;
                    String lName = lData['fullName'] ?? lData['name'] ?? "Lawyer";
                    bool isMe = (lDoc.id == currentUid);

                    String displayName = isMe ? "You" : lName;

                    return Chip(
                      avatar: CircleAvatar(backgroundColor: isMe ? kNavyBlue : Colors.grey.shade400, child: const Icon(Icons.gavel, size: 12, color: Colors.white)),
                      label: Text(displayName, style: TextStyle(fontSize: 12, fontWeight: isMe ? FontWeight.bold : FontWeight.w600, color: isMe ? kNavyBlue : Colors.black87)),
                      backgroundColor: isMe ? kGoldColor.withValues(alpha: 0.2) : Colors.grey.shade100,
                      side: BorderSide(color: isMe ? kGoldColor : Colors.grey.shade300),
                      onDeleted: (isLeadLawyer && !isMe)
                          ? () => _removeLawyerFromTeam(context, lDoc.id, lName)
                          : null,
                      deleteIcon: (isLeadLawyer && !isMe) ? const Icon(Icons.cancel, size: 16, color: Colors.red) : null,
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: BorderSide(color: Colors.deepPurple.shade300),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TeamChatScreen(
                            caseId: caseId,
                            clientName: clientName,
                            currentUid: currentUid,
                          ),
                        ),
                      );
                    },
                    icon: Icon(Icons.chat_bubble_outline, size: 18, color: Colors.deepPurple.shade700),
                    label: Text("Team Chat", style: TextStyle(color: Colors.deepPurple.shade700, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: BorderSide(color: Colors.deepPurple.shade300),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                    ),
                    onPressed: () => showDialog(
                      context: context,
                      builder: (_) => ShareDocDialog(caseId: caseId, service: service),
                    ),
                    icon: Icon(Icons.security, size: 18, color: Colors.deepPurple.shade700),
                    label: Text("Confidential Doc", style: TextStyle(color: Colors.deepPurple.shade700, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _showSharedFilesBottomSheet(context),
                icon: Icon(Icons.folder_special, size: 16, color: Colors.deepPurple.shade700),
                label: Text("View Private Lawyer Files", style: TextStyle(color: Colors.deepPurple.shade700, fontSize: 13, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 6. CASE SELECTION DIALOG
// ==========================================
class CaseSelectionDialog extends StatelessWidget {
  final List<CaseModel> activeCases;
  final String targetLawyerId;
  final String targetLawyerName;
  final String currentUid;
  final CoordinationService service;

  const CaseSelectionDialog({
    super.key,
    required this.activeCases,
    required this.targetLawyerId,
    required this.targetLawyerName,
    required this.currentUid,
    required this.service,
  });

  void _sendCoordinationRequest(BuildContext context, String caseId, String clientName) async {
    try {
      await service.sendCoordinationRequest(
        targetLawyerId: targetLawyerId,
        targetLawyerName: targetLawyerName,
        caseId: caseId,
        clientName: clientName,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Coordination request sent to $targetLawyerName"), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to send request: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      title: const Text("Select Active Case", style: TextStyle(fontWeight: FontWeight.bold)),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: activeCases.length,
          itemBuilder: (context, index) {
            var caseModel = activeCases[index];

            return Card(
              elevation: 1,
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: kNavyBlue,
                  child: Icon(Icons.person, color: Colors.white, size: 20),
                ),
                title: Text(caseModel.clientName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                subtitle: Text("${caseModel.caseType} • Case ID: ${caseModel.id}", style: const TextStyle(fontSize: 12, color: Colors.black54)),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                onTap: () {
                  Navigator.pop(context);
                  _sendCoordinationRequest(context, caseModel.id, caseModel.clientName);
                },
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel", style: TextStyle(color: Colors.red)),
        ),
      ],
    );
  }
}

// ==========================================
// 7. SHARE DOC DIALOG
// ==========================================
class ShareDocDialog extends StatefulWidget {
  final String caseId;
  final CoordinationService service;
  const ShareDocDialog({super.key, required this.caseId, required this.service});

  @override
  State<ShareDocDialog> createState() => _ShareDocDialogState();
}

class _ShareDocDialogState extends State<ShareDocDialog> {
  final TextEditingController titleController = TextEditingController();
  final TextEditingController notesController = TextEditingController();
  PlatformFile? pickedFile;
  bool isUploading = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      title: const Text("Share Private Lawyer Document", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: "Document / Title", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notesController,
              maxLines: 2,
              decoration: const InputDecoration(labelText: "Confidential Notes / Details (Optional)", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 15),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: kNavyBlue),
                minimumSize: const Size(double.infinity, 45),
              ),
              onPressed: () async {
                FilePickerResult? result = await FilePicker.platform.pickFiles(withData: true);
                if (result != null && result.files.isNotEmpty) {
                  setState(() {
                    pickedFile = result.files.first;
                  });
                }
              },
              icon: const Icon(Icons.attach_file, color: kNavyBlue),
              label: Text(
                pickedFile != null ? "Selected: ${pickedFile!.name}" : "Attach Document File",
                style: const TextStyle(color: kNavyBlue, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (pickedFile != null) ...[
              const SizedBox(height: 6),
              Text(
                "File Size: ${(pickedFile!.size / 1024).toStringAsFixed(1)} KB",
                style: const TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.bold),
              ),
            ]
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel", style: TextStyle(color: Colors.red)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: kNavyBlue,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: isUploading
              ? null
              : () async {
            if (titleController.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Please enter document title")),
              );
              return;
            }

            setState(() {
              isUploading = true;
            });

            try {
              await widget.service.uploadPrivateLawyerDocument(
                caseId: widget.caseId,
                title: titleController.text.trim(),
                notes: notesController.text.trim(),
                file: pickedFile,
              );

              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Confidential Document Shared Successfully!"),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            } catch (e) {
              if (context.mounted) {
                setState(() {
                  isUploading = false;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Error sharing document: $e"), backgroundColor: Colors.red),
                );
              }
            }
          },
          child: isUploading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text("Share Privately", style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}