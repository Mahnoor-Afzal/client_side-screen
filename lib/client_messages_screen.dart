import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:rxdart/rxdart.dart';
import 'client_chat_screen.dart';

class MessagesScreen extends StatefulWidget {
  final String initialCategory;
  const MessagesScreen({super.key, this.initialCategory = 'All'});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  late String _selectedCategory;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategory;
  }

  @override
  void didUpdateWidget(covariant MessagesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialCategory != widget.initialCategory) {
      setState(() {
        _selectedCategory = widget.initialCategory;
      });
    }
  }

  String _formatTime(dynamic timestamp) {
    if (timestamp == null) return "";
    try {
      DateTime? dateTime;
      if (timestamp is Timestamp) {
        dateTime = timestamp.toDate();
      } else if (timestamp is int) {
        dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      } else if (timestamp is String) {
        dateTime = DateTime.tryParse(timestamp);
      }
      
      if (dateTime == null) return "";
      return DateFormat('hh:mm a').format(dateTime);
    } catch (e) {
      return "";
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color navyBlue = Color(0xFF001F3F);
    final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? "";

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Column(
        children: [
          // Category Selector
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Row(
              children: [
                _buildCategoryChip("All"),
                const SizedBox(width: 8),
                _buildCategoryChip("Direct"),
                const SizedBox(width: 8),
                _buildCategoryChip("Groups"),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFEEEEEE)),
          Expanded(
            child: StreamBuilder<List<QuerySnapshot>>(
              stream: Rx.combineLatestList([
                FirebaseFirestore.instance.collection('coordination_requests').where('users', arrayContains: currentUserId).snapshots(),
                FirebaseFirestore.instance.collection('coordination_requests').where('clientId', isEqualTo: currentUserId).snapshots(),
                FirebaseFirestore.instance.collection('coordination_requests').where('clientIds', arrayContains: currentUserId).snapshots(),
                FirebaseFirestore.instance.collection('suit_a_file_request').where('clientId', isEqualTo: currentUserId).snapshots(),
              ]).switchMap((initialSnapshots) {
                var coordinationSnapshots = initialSnapshots.sublist(0, 3);
                var requestSnapshot = initialSnapshots[3];

                // Collect all caseIds from coordination requests to find associated group chats
                Set<String> caseIds = {};
                for (var qs in coordinationSnapshots) {
                  for (var doc in qs.docs) {
                    var data = doc.data() as Map<String, dynamic>;
                    dynamic cId = data['caseId'] ?? data['case_id'] ?? data['caseID'];
                    if (cId != null) {
                      caseIds.add(cId is DocumentReference ? cId.id : cId.toString());
                    }
                  }
                }

                // Base streams
                List<Stream<QuerySnapshot>> streams = [];
                for (var qs in coordinationSnapshots) {
                  streams.add(Stream.value(qs));
                }
                
                // Add the request snapshot so it's available in the final builder for status checking
                streams.add(Stream.value(requestSnapshot));

                streams.addAll([
                  FirebaseFirestore.instance
                      .collection('chat')
                      .where('users', arrayContains: currentUserId)
                      .snapshots(),
                  FirebaseFirestore.instance
                      .collection('group_chats')
                      .where('users', arrayContains: currentUserId)
                      .snapshots(),
                  FirebaseFirestore.instance
                      .collection('group_chats')
                      .where('clientId', isEqualTo: currentUserId)
                      .snapshots(),
                  FirebaseFirestore.instance
                      .collection('group_chats')
                      .where('clientIds', arrayContains: currentUserId)
                      .snapshots(),
                ]);

                // Dynamically add streams for group chats by caseId to ensure they appear even if participant list is incomplete
                if (caseIds.isNotEmpty) {
                  List<String> ids = caseIds.toList();
                  for (int i = 0; i < ids.length; i += 10) {
                    int end = (i + 10 < ids.length) ? i + 10 : ids.length;
                    streams.add(FirebaseFirestore.instance
                        .collection('group_chats')
                        .where('caseId', whereIn: ids.sublist(i, end))
                        .snapshots());
                  }
                }

                return Rx.combineLatestList(streams);
              }),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text("Error: ${snapshot.error}"));
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                // First, collect all request statuses to filter closed cases
                Map<String, String> requestStatuses = {};
                for (var qs in snapshot.data!) {
                  if (qs.docs.isNotEmpty && qs.docs.first.reference.parent.id == 'suit_a_file_request') {
                    for (var doc in qs.docs) {
                      var data = doc.data() as Map<String, dynamic>;
                      requestStatuses[doc.id] = (data['status'] ?? '').toString().toLowerCase();
                    }
                  }
                }

                Map<String, QueryDocumentSnapshot> uniqueChats = {};

                for (var qs in snapshot.data!) {
                  // Skip the requests collection as it's only for metadata
                  if (qs.docs.isNotEmpty && qs.docs.first.reference.parent.id == 'suit_a_file_request') {
                    continue;
                  }

                  for (var doc in qs.docs) {
                    var chatData = doc.data() as Map<String, dynamic>;
                    String collectionPath = doc.reference.parent.id.toLowerCase();

                    // Filter out closed/completed cases
                    String? rId = chatData['requestId']?.toString();
                    if (rId != null && requestStatuses.containsKey(rId)) {
                      String status = requestStatuses[rId]!;
                      if (status == 'closed' || status == 'completed') {
                        continue;
                      }
                    }

                    bool isParticipant = false;
                    List users = chatData['users'] ?? [];
                    List clientIds = chatData['clientIds'] ?? [];
                    
                    if (users.contains(currentUserId) ||
                        clientIds.contains(currentUserId) ||
                        chatData['clientId'] == currentUserId ||
                        chatData['client_id'] == currentUserId ||
                        chatData['userId'] == currentUserId ||
                        chatData['senderId'] == currentUserId ||
                        chatData['receiverId'] == currentUserId ||
                        chatData['lawyerId'] == currentUserId ||
                        chatData['lawyerid'] == currentUserId) {
                      isParticipant = true;
                    }

                    // For group chats found via caseId in coordination requests, mark as participant
                    if (!isParticipant && collectionPath.contains('group') && chatData['caseId'] != null) {
                      isParticipant = true;
                    }

                    if (!isParticipant) continue;

                    bool isGroup = (chatData['isGroup'] == true) ||
                        (collectionPath.contains('group')) ||
                        (collectionPath.contains('coordination') && chatData['isGroup'] == true) ||
                        (chatData.containsKey('groupName')) ||
                        (doc.id.startsWith('group_'));

                    // Coordination requests only show as Team Chat for client once accepted (isGroup: true)
                    if (collectionPath.contains('coordination') && chatData['isGroup'] != true) {
                      continue;
                    }

                    // Helper for robust time comparison during deduplication
                    DateTime getTime(Map<String, dynamic> data) {
                      dynamic ts = data['lastMessageTime'] ?? data['updatedAt'] ?? data['timestamp'] ?? data['createdAt'];
                      if (ts is Timestamp) return ts.toDate();
                      if (ts is int) return DateTime.fromMillisecondsSinceEpoch(ts);
                      if (ts is String) return DateTime.tryParse(ts) ?? DateTime.fromMillisecondsSinceEpoch(0);
                      return DateTime.fromMillisecondsSinceEpoch(0);
                    }

                    if (isGroup) {
                      String groupKey = "group_${doc.id}";
                      
                      // Case-based deduplication for group chats
                      dynamic cId = chatData['caseId'] ?? chatData['case_id'] ?? chatData['caseID'];
                      if (cId != null) {
                        String caseIdStr = cId is DocumentReference ? cId.id : cId.toString();
                        groupKey = "case_$caseIdStr";
                      }

                      if (!uniqueChats.containsKey(groupKey)) {
                        uniqueChats[groupKey] = doc;
                      } else {
                        var existingDoc = uniqueChats[groupKey]!;
                        var existingData = existingDoc.data() as Map<String, dynamic>;
                        String existingPath = existingDoc.reference.parent.id.toLowerCase();
                        
                        // Prioritize group_chats over coordination_requests for the same case
                        if (collectionPath.contains('group') && existingPath.contains('coordination')) {
                          uniqueChats[groupKey] = doc;
                        } else if (collectionPath.contains('coordination') && existingPath.contains('group')) {
                          // Keep the existing group_chat
                        } else {
                          // Standard time-based deduplication
                          if (getTime(chatData).isAfter(getTime(existingData))) {
                            uniqueChats[groupKey] = doc;
                          }
                        }
                      }
                    } else {
                      List users = chatData['users'] ?? [];
                      String otherUserId = users.firstWhere((id) => id != currentUserId, orElse: () => "");

                      if (otherUserId.isNotEmpty) {
                        if (!uniqueChats.containsKey(otherUserId)) {
                          uniqueChats[otherUserId] = doc;
                        } else {
                          var existingData = uniqueChats[otherUserId]!.data() as Map<String, dynamic>;
                          if (getTime(chatData).isAfter(getTime(existingData))) {
                            uniqueChats[otherUserId] = doc;
                          }
                        }
                      }
                    }
                  }
                }

                var filteredDocs = uniqueChats.values.toList();

                if (_selectedCategory == 'Direct') {
                  filteredDocs = filteredDocs.where((d) {
                    var data = d.data() as Map<String, dynamic>;
                    String path = d.reference.parent.id.toLowerCase();
                    return !(data['isGroup'] == true || path.contains('coordination') || path.contains('group'));
                  }).toList();
                } else if (_selectedCategory == 'Groups') {
                  filteredDocs = filteredDocs.where((d) {
                    var data = d.data() as Map<String, dynamic>;
                    String path = d.reference.parent.id.toLowerCase();
                    return (data['isGroup'] == true || path.contains('coordination') || path.contains('group'));
                  }).toList();
                }

                filteredDocs.sort((a, b) {
                  var dataA = a.data() as Map<String, dynamic>;
                  var dataB = b.data() as Map<String, dynamic>;
                  
                  DateTime getTime(Map<String, dynamic> data) {
                    dynamic ts = data['lastMessageTime'] ?? data['updatedAt'] ?? data['timestamp'] ?? data['createdAt'];
                    if (ts is Timestamp) return ts.toDate();
                    if (ts is int) return DateTime.fromMillisecondsSinceEpoch(ts);
                    if (ts is String) return DateTime.tryParse(ts) ?? DateTime.fromMillisecondsSinceEpoch(0);
                    return DateTime.fromMillisecondsSinceEpoch(0);
                  }

                  return getTime(dataB).compareTo(getTime(dataA));
                });

                if (filteredDocs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline, size: 80, color: navyBlue.withValues(alpha: 0.2)),
                        const SizedBox(height: 16),
                        Text(
                          "No ${_selectedCategory.toLowerCase()} chats yet",
                          style: const TextStyle(color: navyBlue, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    var chatDoc = filteredDocs[index];
                    var chatData = chatDoc.data() as Map<String, dynamic>;
                    String collectionPath = chatDoc.reference.parent.id;

                    bool isGroup = (chatData['isGroup'] == true) ||
                        (collectionPath.toLowerCase().contains('group')) ||
                        (collectionPath.toLowerCase().contains('coordination') && chatData['isGroup'] == true) ||
                        (chatData.containsKey('groupName')) ||
                        (chatDoc.id.startsWith('group_')) ||
                        (chatDoc.reference.parent.id == 'group_chats');

                    if (isGroup) {
                      String groupName = chatData['groupName'] ?? "Team Chat";
                      
                      // Robust name detection for Team Chats
                      if (groupName.toLowerCase().contains("coordination") || 
                          groupName == "Team Chat" || 
                          collectionPath.contains("coordination")) {

                        if (chatData['lawyerName'] != null && chatData['clientName'] != null) {
                          String lName = chatData['lawyerName'] ?? "Lawyer";
                          String cName = chatData['clientName'] ?? "Client";
                          groupName = "$lName & $cName (Team)";
                        } else if (chatData['lawyerName'] != null) {
                          groupName = "${chatData['lawyerName']} & Client (Team)";
                        } else {
                          groupName = "Team Chat";
                        }
                      }

                      String lawyerId = chatData['lawyerId'] ?? chatData['lawyerid'] ?? chatData['senderId'] ?? "";
                      String clientId = chatData['clientId'] ?? "";
                      List users = chatData['users'] ?? [];

                      String otherId = users.firstWhere(
                              (id) => id != currentUserId,
                          orElse: () => (currentUserId == lawyerId ? clientId : lawyerId)
                      );

                      return _buildChatTile(
                        context,
                        chatDoc,
                        chatData,
                        groupName,
                        otherId,
                        isGroup: true,
                      );
                    }

                    List users = chatData['users'] ?? [];
                    String otherUserId = users.firstWhere((id) => id != currentUserId, orElse: () => "");
                    if (otherUserId.isEmpty) return const SizedBox.shrink();

                    String lawyerId = chatData['lawyerid'] ?? "";
                    String fallbackName = (currentUserId == lawyerId)
                        ? (chatData['clientName'] ?? "Client")
                        : (chatData['lawyerName'] ?? "Lawyer");

                    return FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance
                          .collection('verified_lawyers')
                          .doc(otherUserId)
                          .get(const GetOptions(source: Source.serverAndCache))
                          .then((lawyerDoc) {
                        if (lawyerDoc.exists) return lawyerDoc;
                        return FirebaseFirestore.instance
                            .collection('users')
                            .doc(otherUserId)
                            .get(const GetOptions(source: Source.serverAndCache));
                      }),
                      builder: (context, userSnapshot) {
                        String userName = fallbackName;
                        if (userSnapshot.hasData && userSnapshot.data!.exists) {
                          var userData = userSnapshot.data?.data() as Map<String, dynamic>?;
                          userName = userData?['fullName'] ?? userData?['name'] ?? fallbackName;
                        }

                        return _buildChatTile(
                          context,
                          chatDoc,
                          chatData,
                          userName,
                          otherUserId,
                          isGroup: false,
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(String label) {
    const Color navyBlue = Color(0xFF001F3F);
    const Color gold = Color(0xFFD4AF37);
    bool isSelected = _selectedCategory == label;

    return GestureDetector(
      onTap: () => setState(() => _selectedCategory = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? navyBlue : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? gold : Colors.black54,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildChatTile(
      BuildContext context,
      QueryDocumentSnapshot chatDoc,
      Map<String, dynamic> chatData,
      String userName,
      String otherUserId, {
        required bool isGroup,
      }) {
    const Color navyBlue = Color(0xFF001F3F);
    const Color gold = Color(0xFFD4AF37);
    const Color whatsappGreen = Color(0xFF25D366);

    String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? "";
    String lastMessage = chatData['lastMessage'] ?? "No messages yet";

    // Safely parse unread count
    int unreadCount = 0;
    try {
      if (chatData.containsKey('unreadCount')) {
        var counts = chatData['unreadCount'];
        if (counts is Map) {
          var val = counts[currentUserId] ?? counts[currentUserId.toString()];
          if (val != null) {
            unreadCount = int.tryParse(val.toString()) ?? 0;
          }
        }
      }
    } catch (e) {
      unreadCount = 0;
    }

    bool hasUnread = unreadCount > 0;

    return Column(
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Stack(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: isGroup ? gold.withValues(alpha: 0.2) : navyBlue.withValues(alpha: 0.1),
                child: isGroup
                    ? const Icon(Icons.group, color: navyBlue, size: 28)
                    : Text(
                  userName.isNotEmpty ? userName[0] : "?",
                  style: const TextStyle(color: navyBlue, fontWeight: FontWeight.bold, fontSize: 20),
                ),
              ),
              if (hasUnread)
                Positioned(
                  right: 2,
                  bottom: 2,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: whatsappGreen,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
            ],
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  userName,
                  style: TextStyle(
                    fontWeight: hasUnread ? FontWeight.bold : FontWeight.w500,
                    color: navyBlue,
                    fontSize: 16,
                  ),
                ),
              ),
              if (isGroup)
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: navyBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    "GROUP",
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: navyBlue),
                  ),
                ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              lastMessage,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: hasUnread ? FontWeight.w700 : FontWeight.normal,
                color: hasUnread ? Colors.black87 : Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatTime(chatData['lastMessageTime']),
                style: TextStyle(
                  fontSize: 12,
                  color: hasUnread ? whatsappGreen : Colors.grey[600],
                  fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              const SizedBox(height: 8),
              if (hasUnread)
                Container(
                  padding: const EdgeInsets.all(6),
                  constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                  decoration: const BoxDecoration(
                    color: whatsappGreen,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      unreadCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                )
              else
                const SizedBox(height: 22),
            ],
          ),
          onTap: () {
            // Hamesha wo collection use karein jahan se data aa raha hai
            String path = chatDoc.reference.parent.id; 

            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ChatScreen(
                  receiverName: userName,
                  receiverId: otherUserId,
                  requestId: chatData['requestId'],
                  chatId: chatDoc.id,
                  collectionPath: path,
                ),
              ),
            );
          },
        ),
        const Divider(height: 1, indent: 85, endIndent: 16, color: Color(0xFFEEEEEE)),
      ],
    );
  }
}