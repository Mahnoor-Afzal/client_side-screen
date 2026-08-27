import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher_string.dart';

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

// ==========================================
// CLOUDINARY UPLOAD HELPER FUNCTION
// ==========================================
Future<String?> uploadToCloudinary(PlatformFile file) async {
  const String cloudName = "gasafl8q";
  const String uploadPreset = "ml_default";

  try {
    final uri = Uri.parse("https://api.cloudinary.com/v1_1/$cloudName/auto/upload");

    var request = http.MultipartRequest("POST", uri);
    request.fields['upload_preset'] = uploadPreset;

    if (kIsWeb) {
      if (file.bytes == null) return null;
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          file.bytes!,
          filename: file.name,
        ),
      );
    } else {
      if (file.path == null) return null;
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          file.path!,
        ),
      );
    }

    var response = await request.send();
    if (response.statusCode == 200) {
      var responseData = await response.stream.toBytes();
      var responseString = String.fromCharCodes(responseData);
      var jsonMap = jsonDecode(responseString);
      return jsonMap['secure_url'];
    } else {
      var responseData = await response.stream.toBytes();
      debugPrint("Cloudinary Upload Failed: ${String.fromCharCodes(responseData)}");
      return null;
    }
  } catch (e) {
    debugPrint("Cloudinary Upload Error: $e");
    return null;
  }
}

// ==========================================
// CROSS-PLATFORM DOWNLOAD HELPER
// ==========================================
Future<void> downloadFile(BuildContext context, String fileUrl, String fileName) async {
  if (fileUrl.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("File URL is missing."),
        backgroundColor: Colors.orange,
      ),
    );
    return;
  }

  try {
    if (kIsWeb) {
      final Uri uri = Uri.parse(fileUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, webOnlyWindowName: '_blank');
      }
    } else {
      if (await canLaunchUrlString(fileUrl)) {
        await launchUrlString(fileUrl, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Could not launch file download link."), backgroundColor: Colors.red),
          );
        }
      }
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error downloading file: $e"), backgroundColor: Colors.red),
      );
    }
  }
}

class CoordinationScreen extends StatelessWidget {
  const CoordinationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final String? uid = FirebaseAuth.instance.currentUser?.uid;

    return DefaultTabController(
      length: 4,
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
            : TabBarView(
          children: [
            _MyTeamsTab(uid: uid),
            _CoordinatedCasesTab(uid: uid),
            _RequestsTab(currentUid: uid),
            _VerifiedLawyersTab(currentUid: uid),
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
  const _MyTeamsTab({required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('cases').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState();
        }

        var myCases = snapshot.data!.docs.where((doc) {
          var data = doc.data() as Map<String, dynamic>;
          List assigned = data['assignedLawyers'] ?? [];
          String leadLawyer = (data['lawyerid'] ?? data['lawyerId'] ?? data['leadLawyerId'] ?? '').toString().trim();

          bool isAssigned = assigned.contains(uid) || leadLawyer == uid;
          bool hasTeam = assigned.length > 1;
          return isAssigned && hasTeam;
        }).toList();

        if (myCases.isEmpty) return _buildEmptyState();

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: myCases.length,
          itemBuilder: (context, index) {
            var doc = myCases[index];
            return CoordinationCard(
              caseId: doc.id,
              data: doc.data() as Map<String, dynamic>,
              currentUid: uid,
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
          const Text("No active team coordination found", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
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
  String _currentUserName = "Lawyer";
  Map<String, dynamic>? _replyingToMessage;

  @override
  void initState() {
    super.initState();
    _fetchCurrentUserName();
  }

  Future<void> _fetchCurrentUserName() async {
    try {
      var doc = await FirebaseFirestore.instance.collection('verified_lawyers').doc(widget.currentUid).get();
      if (doc.exists) {
        setState(() {
          _currentUserName = doc.data()?['fullName'] ?? doc.data()?['name'] ?? "Lawyer";
        });
      } else {
        var userDoc = await FirebaseFirestore.instance.collection('users').doc(widget.currentUid).get();
        if (userDoc.exists) {
          setState(() {
            _currentUserName = userDoc.data()?['fullName'] ?? userDoc.data()?['name'] ?? "Client";
          });
        }
      }
    } catch (_) {}
  }

  void _sendMessage() async {
    String text = _msgController.text.trim();
    if (text.isEmpty) return;

    _msgController.clear();
    var replyData = _replyingToMessage;
    setState(() {
      _replyingToMessage = null;
    });

    Map<String, dynamic> messageData = {
      'senderId': widget.currentUid,
      'senderName': _currentUserName,
      'message': text,
      'timestamp': FieldValue.serverTimestamp(),
      'deletedFor': [],
    };

    if (replyData != null) {
      messageData['replyToMessage'] = replyData['message'];
      messageData['replyToSender'] = replyData['senderName'];
    }

    await FirebaseFirestore.instance
        .collection('cases')
        .doc(widget.caseId)
        .collection('team_chats')
        .add(messageData);
  }

  void _deleteMessage(String docId, String senderId, bool deleteForEveryone) async {
    if (deleteForEveryone && senderId == widget.currentUid) {
      await FirebaseFirestore.instance
          .collection('cases')
          .doc(widget.caseId)
          .collection('team_chats')
          .doc(docId)
          .update({
        'message': 'This message was deleted',
        'isDeleted': true,
      });
    } else {
      await FirebaseFirestore.instance
          .collection('cases')
          .doc(widget.caseId)
          .collection('team_chats')
          .doc(docId)
          .update({
        'deletedFor': FieldValue.arrayUnion([widget.currentUid])
      });
    }
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
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('cases')
                  .doc(widget.caseId)
                  .collection('team_chats')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
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
                    String senderName = data['senderName'] ?? 'Lawyer';
                    bool isDeleted = data['isDeleted'] == true;
                    String messageText = data['message'] ?? '';
                    String? replyText = data['replyToMessage'];
                    String? replySender = data['replyToSender'];

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
                              Text(
                                isMe ? "You" : senderName,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isMe ? kGoldColor : Colors.deepPurple,
                                ),
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
          Container(
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, -2))
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
          )
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
  const _CoordinatedCasesTab({required this.uid});

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
                          color: Colors.white.withOpacity(0.1),
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
                  color: kGoldColor.withOpacity(0.2),
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
    String clientId = caseData['clientId'] ?? caseData['created_by'] ?? caseData['userId'] ?? '';
    String leadLawyerId = caseData['lawyerid'] ?? caseData['lawyerId'] ?? caseData['leadLawyerId'] ?? '';

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
          child: StreamBuilder<QuerySnapshot>(
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
                      'sender': 'Case Initial File',
                      'type': 'primary'
                    });
                  }

                  if (caseData['vakalatnamaUrl'] != null && caseData['vakalatnamaUrl'].toString().isNotEmpty) {
                    allDocuments.add({
                      'title': "Vakalatnama (Signed Power of Attorney)",
                      'url': caseData['vakalatnamaUrl'],
                      'sender': 'Legal Agreement',
                      'type': 'vakalatnama'
                    });
                  }

                  if (subDocSnap.hasData) {
                    for (var d in subDocSnap.data!.docs) {
                      var data = d.data() as Map<String, dynamic>;
                      allDocuments.add({
                        'title': data['fileName'] ?? data['title'] ?? data['name'] ?? 'Shared Document',
                        'url': data['fileUrl'] ?? data['url'] ?? data['path'] ?? '',
                        'sender': data['uploadedBy'] ?? data['senderName'] ?? data['uploadedByRole'] ?? 'Supporting Lawyer',
                        'status': data['status'] ?? '',
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
                          allDocuments.add({
                            'title': data['fileName'] ?? data['title'] ?? data['name'] ?? 'Document Vault File',
                            'url': url,
                            'sender': data['uploadedBy'] ?? data['senderName'] ?? data['from'] ?? 'Documents Vault',
                            'status': data['status'] ?? '',
                          });
                        }
                      }
                    }
                  }

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

                      bool isVakalatnama = item['type'] == 'vakalatnama' || title.toLowerCase().contains('vakalatnama');

                      return Card(
                        elevation: 1,
                        margin: const EdgeInsets.only(bottom: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isVakalatnama ? Colors.green.shade50 : kNavyBlue.withOpacity(0.1),
                            child: Icon(
                              isVakalatnama ? Icons.verified : Icons.insert_drive_file,
                              color: isVakalatnama ? Colors.green : kNavyBlue,
                            ),
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), overflow: TextOverflow.ellipsis),
                              ),
                              if (status.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: Colors.green.shade100, borderRadius: BorderRadius.circular(4)),
                                  child: Text(status.toUpperCase(), style: const TextStyle(fontSize: 9, color: Colors.green, fontWeight: FontWeight.bold)),
                                ),
                            ],
                          ),
                          subtitle: Text("Uploaded By: $sender", style: const TextStyle(fontSize: 11, color: Colors.grey)),
                          trailing: IconButton(
                            icon: const Icon(Icons.file_download, color: Colors.green),
                            tooltip: "Download File",
                            onPressed: () => downloadFile(context, url, title),
                          ),
                        ),
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

  void _showUploadDialog(BuildContext context, String caseId, String uid) {
    showDialog(
      context: context,
      builder: (_) => SupportingLawyerUploadDialog(caseId: caseId, uid: uid),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('cases').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("No coordinated cases found.", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)));
        }

        var coordinatedCases = snapshot.data!.docs.where((doc) {
          var data = doc.data() as Map<String, dynamic>;
          List assigned = data['assignedLawyers'] ?? [];
          String leadLawyer = (data['lawyerid'] ?? data['lawyerId'] ?? data['leadLawyerId'] ?? '').toString().trim();

          return assigned.contains(uid) && leadLawyer != uid;
        }).toList();

        if (coordinatedCases.isEmpty) {
          return const Center(child: Text("You have not been added as a supporting lawyer to any cases.", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: coordinatedCases.length,
          itemBuilder: (context, index) {
            var caseDoc = coordinatedCases[index];
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
                          decoration: BoxDecoration(color: kGoldColor.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                          child: const Text("Supporting Lawyer", style: TextStyle(color: kNavyBlue, fontWeight: FontWeight.bold, fontSize: 11)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text("Type: $caseType", style: const TextStyle(color: Colors.grey, fontSize: 13)),
                    Text("Main Lawyer: $leadName", style: const TextStyle(color: Colors.black87, fontSize: 12, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: kNavyBlue, foregroundColor: Colors.white),
                            onPressed: () => _showHearingsDialog(context, caseDoc.id, clientName),
                            icon: const Icon(Icons.event, size: 16),
                            label: const Text("Hearings", style: TextStyle(fontSize: 12)),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: kGoldColor, foregroundColor: Colors.white),
                            onPressed: () => _showDocumentsDialog(context, caseDoc.id, data),
                            icon: const Icon(Icons.folder, size: 16),
                            label: const Text("Docs", style: TextStyle(fontSize: 12)),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                            onPressed: () => _showUploadDialog(context, caseDoc.id, uid),
                            icon: const Icon(Icons.cloud_upload, size: 16),
                            label: const Text("Upload", style: TextStyle(fontSize: 12)),
                          ),
                        ),
                      ],
                    )
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
              String? fileUrl = await uploadToCloudinary(selectedFile!);

              if (fileUrl != null && fileUrl.isNotEmpty) {
                // 1. Fetch supporting lawyer name
                var lawyerDoc = await FirebaseFirestore.instance.collection('verified_lawyers').doc(widget.uid).get();
                String lawyerName = lawyerDoc.data()?['fullName'] ?? lawyerDoc.data()?['name'] ?? "Supporting Lawyer";

                // 2. Fetch case details to get main lawyer ID (lawyerId) and client ID (clientId)
                var caseDoc = await FirebaseFirestore.instance.collection('cases').doc(widget.caseId).get();
                String mainLawyerId = "";
                String clientId = "";
                String clientName = "Client";
                String caseType = titleController.text.trim();

                if (caseDoc.exists && caseDoc.data() != null) {
                  var caseData = caseDoc.data()!;
                  mainLawyerId = (caseData['lawyerId'] ?? caseData['lawyerid'] ?? caseData['mainLawyerId'] ?? "").toString();
                  clientId = (caseData['clientId'] ?? caseData['clientid'] ?? caseData['userId'] ?? "").toString();
                  clientName = (caseData['clientName'] ?? caseData['userName'] ?? "Client").toString();
                  caseType = caseData['type'] ?? caseData['caseType'] ?? titleController.text.trim();
                }

                // Fallback if not found in cases collection, check coordination_requests
                if (mainLawyerId.isEmpty || clientId.isEmpty) {
                  var coordQuery = await FirebaseFirestore.instance
                      .collection('coordination_requests')
                      .where('caseId', isEqualTo: widget.caseId)
                      .limit(1)
                      .get();
                  if (coordQuery.docs.isNotEmpty) {
                    var coordData = coordQuery.docs.first.data();
                    if (mainLawyerId.isEmpty) {
                      mainLawyerId = (coordData['senderId'] ?? coordData['mainLawyerId'] ?? "").toString();
                    }
                    if (clientId.isEmpty) {
                      clientId = (coordData['clientId'] ?? coordData['clientid'] ?? "").toString();
                    }
                  }
                }

                // 3. Save inside cases subcollection
                await FirebaseFirestore.instance
                    .collection('cases')
                    .doc(widget.caseId)
                    .collection('documents')
                    .add({
                  'title': titleController.text.trim(),
                  'fileName': selectedFile!.name,
                  'fileUrl': fileUrl,
                  'uploadedBy': lawyerName,
                  'uploadedById': widget.uid,
                  'uploadedByRole': 'Supporting Lawyer',
                  'createdAt': FieldValue.serverTimestamp(),
                });

                // 4. Save inside root 'documents' collection so Main Lawyer & Client can see it in Documents Vault
                await FirebaseFirestore.instance.collection('documents').add({
                  'lawyerId': mainLawyerId.isNotEmpty ? mainLawyerId : widget.uid,
                  'senderId': widget.uid,
                  'clientId': clientId,
                  'receiverId': clientId,
                  'clientName': clientName,
                  'caseId': widget.caseId,
                  'type': caseType,
                  'title': titleController.text.trim(),
                  'fileName': selectedFile!.name,
                  'fileUrl': fileUrl,
                  'senderType': 'supporting_lawyer',
                  'date': DateTime.now().toString().split(' ')[0],
                  'timestamp': FieldValue.serverTimestamp(),
                  'status': 'uploaded',
                  'isDownloaded': false,
                });

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Document uploaded successfully!"), backgroundColor: Colors.green),
                  );
                }
              } else {
                throw Exception("Failed to upload file to Cloudinary.");
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

// ==========================================
// 3. INCOMING REQUESTS TAB WIDGET
// ==========================================
class _RequestsTab extends StatelessWidget {
  final String currentUid;
  const _RequestsTab({required this.currentUid});

  Future<void> _handleRequest(BuildContext context, String reqId, String caseId, String senderId, bool accept) async {
    try {
      if (accept) {
        await FirebaseFirestore.instance.collection('coordination_requests').doc(reqId).update({
          'status': 'Accepted'
        });

        await FirebaseFirestore.instance.collection('cases').doc(caseId).update({
          'assignedLawyers': FieldValue.arrayUnion([currentUid, senderId])
        });

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Coordination Request Accepted! You are now part of this case team."), backgroundColor: Colors.green),
          );
        }
      } else {
        await FirebaseFirestore.instance.collection('coordination_requests').doc(reqId).update({
          'status': 'Rejected'
        });

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Request Declined"), backgroundColor: Colors.orange),
          );
        }
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
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('coordination_requests')
          .where('receiverId', isEqualTo: currentUid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text("No incoming coordination requests.", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          );
        }

        var requests = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: requests.length,
          itemBuilder: (context, index) {
            var doc = requests[index];
            var data = doc.data() as Map<String, dynamic>;

            String reqId = doc.id;
            String senderName = data['senderName'] ?? "Lawyer";
            String clientName = data['clientName'] ?? "Client";
            String status = data['status'] ?? "Pending";
            String caseId = data['caseId'] ?? "";
            String senderId = data['senderId'] ?? "";

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
                            "Request from $senderName",
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: kNavyBlue),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: status == 'Pending' ? Colors.amber.shade100 : (status == 'Accepted' ? Colors.green.shade100 : Colors.red.shade100),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            status,
                            style: TextStyle(
                              color: status == 'Pending' ? Colors.amber.shade900 : (status == 'Accepted' ? Colors.green.shade900 : Colors.red.shade900),
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text("Client Name: $clientName", style: const TextStyle(fontSize: 13, color: Colors.black87)),
                    Text("Case Reference ID: $caseId", style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    const SizedBox(height: 12),

                    if (status == 'Pending')
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                              onPressed: () => _handleRequest(context, reqId, caseId, senderId, true),
                              icon: const Icon(Icons.check, size: 18),
                              label: const Text("Accept"),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                              onPressed: () => _handleRequest(context, reqId, caseId, senderId, false),
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

// ==========================================
// 4. VERIFIED LAWYERS TAB WIDGET
// ==========================================
class _VerifiedLawyersTab extends StatelessWidget {
  final String currentUid;
  const _VerifiedLawyersTab({required this.currentUid});

  void _showCaseSelectionDialog(BuildContext context, String targetLawyerId, String targetLawyerName) async {
    try {
      var casesSnapshot = await FirebaseFirestore.instance.collection('suit_a_file_request').get();

      List<QueryDocumentSnapshot> activeCases = casesSnapshot.docs.where((doc) {
        var data = doc.data() as Map<String, dynamic>;

        String lawyerId = (data['lawyerid'] ?? data['lawyerId'] ?? data['leadLawyerId'] ?? '').toString().trim();
        List assigned = data['assignedLawyers'] ?? [];
        String status = (data['status'] ?? 'active').toString().toLowerCase().trim();

        bool isMyCase = (lawyerId == currentUid) || assigned.contains(currentUid);
        bool isActive = status == 'active' || status == 'accepted';

        return isMyCase && isActive;
      }).toList();

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
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('verified_lawyers').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("No verified lawyers found", style: TextStyle(color: Colors.grey)));
        }

        var lawyers = snapshot.data!.docs.where((doc) {
          if (doc.id == currentUid) return false;

          var data = doc.data() as Map<String, dynamic>;
          bool isApproved = (data['isApproved'] == true) ||
              (data['isVerified'] == true) ||
              (data['verified'] == true) ||
              (!data.containsKey('isApproved') && !data.containsKey('isVerified'));

          return isApproved;
        }).toList();

        if (lawyers.isEmpty) {
          return const Center(child: Text("No verified lawyers available", style: TextStyle(color: Colors.grey)));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: lawyers.length,
          itemBuilder: (context, index) {
            var doc = lawyers[index];
            var data = doc.data() as Map<String, dynamic>;

            String val(dynamic v, String def) => (v == null) ? def : (v is List ? v.join(", ") : v.toString());

            String name = val(data['fullName'] ?? data['name'], "Lawyer");
            String? profileImg = data['profileImageUrl'] ?? data['profilePic'] ?? data['cnicFrontUrl'];
            String category = val(data['category'] ?? data['specialization'] ?? data['area'], "Legal Expert");
            String barCouncil = val(data['barCouncil'], "Bar Council Name");
            String location = val(data['location'] ?? data['city'] ?? data['area'], "Location");
            String court = val(data['court'], "Supreme Court");
            String experience = val(data['experience'], "N/A");
            String bio = val(data['description'] ?? data['bio'] ?? data['about'], "I am a professional lawyer.");

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
                          backgroundImage: (profileImg != null && profileImg.isNotEmpty) ? NetworkImage(profileImg) : null,
                          child: (profileImg == null || profileImg.isEmpty) ? const Icon(Icons.person, size: 40, color: kNavyBlue) : null,
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(child: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: kNavyBlue), overflow: TextOverflow.ellipsis)),
                                  const SizedBox(width: 5),
                                  const Icon(Icons.verified, color: Colors.blue, size: 18),
                                ],
                              ),
                              Text(category, style: const TextStyle(color: kGoldColor, fontWeight: FontWeight.w600, fontSize: 14)),
                              Text(barCouncil, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(Icons.gavel_rounded, size: 14, color: Colors.grey[600]),
                                  const SizedBox(width: 4),
                                  Expanded(child: Text(court, style: TextStyle(color: Colors.grey[600], fontSize: 11), overflow: TextOverflow.ellipsis)),
                                ],
                              ),
                              Row(
                                children: [
                                  Icon(Icons.location_on, size: 14, color: Colors.grey[600]),
                                  const SizedBox(width: 4),
                                  Text(location, style: TextStyle(color: Colors.grey[600], fontSize: 11)),
                                  const SizedBox(width: 10),
                                  Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                                  const SizedBox(width: 4),
                                  Text("$experience Exp", style: TextStyle(color: Colors.grey[600], fontSize: 11)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(bio, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: Colors.black87)),
                    const SizedBox(height: 15),
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance.collection('coordination_requests').snapshots(),
                      builder: (context, reqSnapshot) {
                        bool isPending = false;
                        if (reqSnapshot.hasData) {
                          isPending = reqSnapshot.data!.docs.any((rDoc) {
                            var rData = rDoc.data() as Map<String, dynamic>;
                            return rData['senderId'] == currentUid && rData['receiverId'] == doc.id && rData['status'] == 'Pending';
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
                            onPressed: isPending ? null : () => _showCaseSelectionDialog(context, doc.id, name),
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

  const CoordinationCard({
    super.key,
    required this.caseId,
    required this.data,
    required this.currentUid,
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
                      stream: FirebaseFirestore.instance
                          .collection('cases')
                          .doc(caseId)
                          .collection('lawyer_private_documents')
                          .orderBy('createdAt', descending: true)
                          .snapshots(),
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
                                  backgroundColor: kNavyBlue.withOpacity(0.1),
                                  child: const Icon(Icons.lock_outline, color: kNavyBlue),
                                ),
                                title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text(
                                  "${fileName.isNotEmpty ? 'File: $fileName\n' : ''}${notes.isNotEmpty ? 'Notes: $notes' : ''}",
                                  style: const TextStyle(fontSize: 12),
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.file_download, color: Colors.green),
                                  tooltip: "Download File",
                                  onPressed: () => downloadFile(context, fileUrl, title),
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
                await FirebaseFirestore.instance.collection('cases').doc(caseId).update({
                  'assignedLawyers': FieldValue.arrayRemove([lawyerIdToRemove])
                });

                var reqQuery = await FirebaseFirestore.instance
                    .collection('coordination_requests')
                    .where('caseId', isEqualTo: caseId)
                    .get();

                for (var doc in reqQuery.docs) {
                  await doc.reference.delete();
                }

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
                      avatar: const CircleAvatar(backgroundColor: kNavyBlue, child: Icon(Icons.gavel, size: 12, color: Colors.white)),
                      label: Text(displayName, style: TextStyle(fontSize: 12, fontWeight: isMe ? FontWeight.bold : FontWeight.w600, color: isMe ? kNavyBlue : Colors.black87)),
                      backgroundColor: isMe ? kGoldColor.withOpacity(0.2) : Colors.grey.shade100,
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
                      builder: (_) => ShareDocDialog(caseId: caseId),
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
  final List<QueryDocumentSnapshot> activeCases;
  final String targetLawyerId;
  final String targetLawyerName;
  final String currentUid;

  const CaseSelectionDialog({
    super.key,
    required this.activeCases,
    required this.targetLawyerId,
    required this.targetLawyerName,
    required this.currentUid,
  });

  void _sendCoordinationRequest(BuildContext context, String caseId, String clientName) async {
    try {
      var currentLawyerDoc = await FirebaseFirestore.instance.collection('verified_lawyers').doc(currentUid).get();
      String senderName = "Lawyer";
      if (currentLawyerDoc.exists) {
        var data = currentLawyerDoc.data();
        senderName = data?['fullName'] ?? data?['name'] ?? "Lawyer";
      }

      List<String> teamMembers = [currentUid, targetLawyerId];
      var caseDoc = await FirebaseFirestore.instance.collection('cases').doc(caseId).get();
      if (caseDoc.exists) {
        String clientId = caseDoc.data()?['created_by'] ?? caseDoc.data()?['clientId'] ?? '';
        if (clientId.isNotEmpty && !teamMembers.contains(clientId)) {
          teamMembers.add(clientId);
        }
      }

      await FirebaseFirestore.instance.collection('coordination_requests').add({
        'senderId': currentUid,
        'senderName': senderName,
        'receiverId': targetLawyerId,
        'receiverName': targetLawyerName,
        'caseId': caseId,
        'clientName': clientName,
        'status': 'Pending',
        'isGroup': true,
        'users': teamMembers,
        'createdAt': FieldValue.serverTimestamp(),
      });

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
            var caseDoc = activeCases[index];
            var caseData = caseDoc.data() as Map<String, dynamic>;

            String clientName = caseData['clientName'] ?? caseData['client_name'] ?? caseData['userName'] ?? "Client";
            String caseType = caseData['caseType'] ?? caseData['category'] ?? "Active Matter";
            String clientId = caseData['clientId'] ?? caseData['created_by'] ?? caseData['userId'] ?? "N/A";
            String caseId = caseDoc.id;

            return Card(
              elevation: 1,
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: kNavyBlue,
                  child: Icon(Icons.person, color: Colors.white, size: 20),
                ),
                title: Text(clientName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                subtitle: Text("$caseType • Client ID: $clientId", style: const TextStyle(fontSize: 12, color: Colors.black54)),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                onTap: () {
                  Navigator.pop(context);
                  _sendCoordinationRequest(context, caseId, clientName);
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
  const ShareDocDialog({super.key, required this.caseId});

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
              String fileUrl = '';
              if (pickedFile != null) {
                String? uploadedUrl = await uploadToCloudinary(pickedFile!);
                if (uploadedUrl != null && uploadedUrl.isNotEmpty) {
                  fileUrl = uploadedUrl;
                } else {
                  throw Exception("Cloudinary upload failed. Please try again.");
                }
              }

              await FirebaseFirestore.instance
                  .collection('cases')
                  .doc(widget.caseId)
                  .collection('lawyer_private_documents')
                  .add({
                'title': titleController.text.trim(),
                'notes': notesController.text.trim(),
                'fileName': pickedFile?.name ?? 'No File Attached',
                'fileSize': pickedFile != null ? '${(pickedFile!.size / 1024).toStringAsFixed(1)} KB' : '',
                'fileUrl': fileUrl,
                'sharedBy': FirebaseAuth.instance.currentUser?.uid,
                'createdAt': FieldValue.serverTimestamp(),
              });

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