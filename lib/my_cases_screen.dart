import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_screen.dart';
import 'vakalatnama_screen.dart';
import 'lawyer_profile_screen.dart';

class MyCasesScreen extends StatefulWidget {
  final String? filterStatus;
  final String? filterType;
  const MyCasesScreen({super.key, this.filterStatus, this.filterType});

  @override
  State<MyCasesScreen> createState() => _MyCasesScreenState();
}

class _MyCasesScreenState extends State<MyCasesScreen> {
  String _userRole = 'client';

  @override
  void initState() {
    super.initState();
    _fetchUserRole();
  }

  Future<void> _fetchUserRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        var doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists && mounted) {
          setState(() {
            _userRole = doc.data()?['role'] ?? 'client';
          });
          return;
        }

        var lawyerDoc = await FirebaseFirestore.instance.collection('verified_lawyers').doc(user.uid).get();
        if (lawyerDoc.exists && mounted) {
          setState(() {
            _userRole = 'lawyer';
          });
        }
      } catch (e) {
        debugPrint("Error fetching user role: $e");
      }
    }
  }

  Future<void> _markAsResolved(String docId, String collectionName) async {
    try {
      await FirebaseFirestore.instance.collection(collectionName).doc(docId).update({
        'status': 'Completed',
        'completedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Case marked as Completed!"),
          backgroundColor: Colors.teal,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Error: $e"),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  void _showHearingDialog(BuildContext context, String docId, String collectionName) {
    final dateController = TextEditingController();
    final detailsController = TextEditingController();
    const Color navyBlue = Color(0xFF001F3F);
    const Color gold = Color(0xFFD4AF37);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Update Hearing Detail", style: TextStyle(color: navyBlue, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: dateController,
              decoration: const InputDecoration(
                labelText: "Hearing Date (e.g. 25 Oct 2023)",
                hintText: "Enter date",
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: detailsController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: "Hearing Details / Instructions",
                hintText: "What should the client know?",
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: navyBlue, foregroundColor: gold),
            onPressed: () async {
              if (dateController.text.isNotEmpty) {
                await FirebaseFirestore.instance.collection(collectionName).doc(docId).update({
                  'hearingDate': dateController.text,
                  'hearingDetails': detailsController.text,
                });

                // Client ko notification bhejein
                try {
                  var caseDoc = await FirebaseFirestore.instance.collection(collectionName).doc(docId).get();
                  if (caseDoc.exists) {
                    var caseData = caseDoc.data() as Map<String, dynamic>;
                    await FirebaseFirestore.instance.collection('notifications').add({
                      'userId': caseData['clientId'],
                      'title': 'Hearing Update',
                      'body': 'Your lawyer has set a new hearing date: ${dateController.text}',
                      'type': 'hearing_update',
                      'createdAt': FieldValue.serverTimestamp(),
                      'isRead': false,
                      'requestId': docId,
                    });
                  }
                } catch (e) {
                  debugPrint("Error sending hearing notification: $e");
                }

                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color navyBlue = Color(0xFF001F3F);
    const Color gold = Color(0xFFD4AF37);

    String title = "My Cases";
    if (widget.filterType != null) {
      title = widget.filterType == 'File a Suit' ? "Legal Suits" : "Consultations";
    } else if (widget.filterStatus != null) {
      title = "${widget.filterStatus} Requests";
    }

    String idField = _userRole == 'lawyer' ? 'lawyerId' : 'clientId';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: navyBlue,
        title: Text(title, style: const TextStyle(color: gold)),
        iconTheme: const IconThemeData(color: gold),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('consultation_request')
            .where(idField, isEqualTo: FirebaseAuth.instance.currentUser?.uid)
            .snapshots(),
        builder: (context, consultSnapshot) {
          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('suit_a_file_request')
                .where(idField, isEqualTo: FirebaseAuth.instance.currentUser?.uid)
                .snapshots(),
            builder: (context, suitSnapshot) {
              if (consultSnapshot.connectionState == ConnectionState.waiting ||
                  suitSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: navyBlue));
              }

              List<QueryDocumentSnapshot> allDocs = [];
              if (consultSnapshot.hasData) allDocs.addAll(consultSnapshot.data!.docs);
              if (suitSnapshot.hasData) allDocs.addAll(suitSnapshot.data!.docs);

              final docs = allDocs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final status = data['status'] ?? 'Pending';
                final type = data['type'] ?? (doc.reference.parent.id == 'consultation_request' ? 'Consultation' : 'File a Suit');

                bool matchesStatus = widget.filterStatus == null ||
                    status.toString().toLowerCase() == widget.filterStatus!.toLowerCase();

                bool matchesType = widget.filterType == null ||
                    type.toString().toLowerCase() == widget.filterType!.toLowerCase();

                return matchesStatus && matchesType;
              }).toList();

              docs.sort((a, b) {
                Timestamp t1 = (a.data() as Map<String, dynamic>)['createdAt'] ?? Timestamp.now();
                Timestamp t2 = (b.data() as Map<String, dynamic>)['createdAt'] ?? Timestamp.now();
                return t2.compareTo(t1);
              });

              if (docs.isEmpty) {
                return const Center(child: Text("No matching requests found."));
              }

              return ListView.builder(
                padding: const EdgeInsets.all(15),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  var doc = docs[index];
                  var caseData = doc.data() as Map<String, dynamic>;
                  String status = caseData['status'] ?? 'Pending';
                  String collectionName = doc.reference.parent.id;
                  String type = caseData['type'] ?? (collectionName == 'consultation_request' ? 'Consultation' : 'File a Suit');

                  Color statusColor;
                  switch (status.toLowerCase()) {
                    case 'active': statusColor = Colors.green; break;
                    case 'accepted': statusColor = Colors.blue; break;
                    case 'completed': statusColor = Colors.teal; break;
                    case 'rejected': statusColor = Colors.red; break;
                    default: statusColor = Colors.orange;
                  }

                  bool canChat = ['accepted', 'active', 'in progress', 'completed'].contains(status.toLowerCase());
                  bool needsVakalatnama = status.toLowerCase() == 'accepted' && type == 'File a Suit' && _userRole == 'client';
                  bool isLawyerActive = (status.toLowerCase() == 'active' || status.toLowerCase() == 'accepted') && _userRole == 'lawyer';
                  bool canResolve = (status.toLowerCase() == 'active' || status.toLowerCase() == 'accepted') && _userRole == 'lawyer';
                  Map<String, dynamic>? aiAnalysis = caseData['aiAnalysis'];

                  return Card(
                    elevation: 3,
                    margin: const EdgeInsets.only(bottom: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    child: Column(
                      children: [
                        ListTile(
                          contentPadding: const EdgeInsets.all(15),
                          leading: CircleAvatar(
                            backgroundColor: navyBlue.withValues(alpha: 0.1),
                            child: Icon(
                              type == 'Consultation' ? Icons.chat_bubble_outline : Icons.gavel,
                              color: navyBlue,
                            ),
                          ),
                          title: Text(type, style: const TextStyle(fontWeight: FontWeight.bold, color: navyBlue)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 5),
                              Text(_userRole == 'lawyer' 
                                ? "Client: ${caseData['clientName'] ?? 'Unknown'}"
                                : "Lawyer: ${caseData['lawyerName'] ?? 'Unknown'}"),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(status, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12)),
                              ),
                            ],
                          ),
                          trailing: const Icon(Icons.arrow_forward_ios, color: gold, size: 18),
                          onTap: () async {
                            String otherPartyId = _userRole == 'lawyer' ? (caseData['clientId'] ?? '') : (caseData['lawyerId'] ?? '');
                            String otherPartyName = _userRole == 'lawyer' ? (caseData['clientName'] ?? 'Client') : (caseData['lawyerName'] ?? 'Lawyer');

                            if (canChat && otherPartyId.isNotEmpty) {
                              if (_userRole == 'client') {
                                // Client ke liye lawyer ki profile kholien
                                try {
                                  // Pehle verified_lawyers mein check karein
                                  DocumentSnapshot lawyerDoc = await FirebaseFirestore.instance
                                      .collection('verified_lawyers')
                                      .doc(otherPartyId)
                                      .get();
                                  
                                  // Agar wahan nahi hai toh users collection mein check karein
                                  if (!lawyerDoc.exists) {
                                    lawyerDoc = await FirebaseFirestore.instance
                                        .collection('users')
                                        .doc(otherPartyId)
                                        .get();
                                  }

                                  if (lawyerDoc.exists && context.mounted) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => LawyerProfileScreen(
                                          lawyer: lawyerDoc.data() as Map<String, dynamic>,
                                          lawyerId: otherPartyId,
                                        ),
                                      ),
                                    );
                                    return;
                                  }
                                } catch (e) {
                                  debugPrint("Error fetching lawyer profile: $e");
                                }
                                
                                // Fallback agar profile na miley
                                if (context.mounted) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ChatScreen(
                                        receiverName: otherPartyName,
                                        receiverId: otherPartyId,
                                        requestId: doc.id, // Sahi requestId pass karna
                                      ),
                                    ),
                                  );
                                }
                              } else {
                                // Lawyer ke liye seedha chat
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ChatScreen(
                                      receiverName: otherPartyName,
                                      receiverId: otherPartyId,
                                      requestId: doc.id, // Sahi requestId pass karna
                                    ),
                                  ),
                                );
                              }
                            } else {
                              _showStatusNotice(context, status);
                            }
                          },
                        ),
                        if (aiAnalysis != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 15),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.blue.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.blue.withValues(alpha: 0.1)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(Icons.auto_awesome, size: 14, color: Colors.blue),
                                      SizedBox(width: 5),
                                      Text("AI Case Analysis", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 12)),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text("Analysis: ${aiAnalysis['reason'] ?? 'N/A'}", style: const TextStyle(fontSize: 11)),
                                ],
                              ),
                            ),
                          ),
                        const SizedBox(height: 10),
                        if (isLawyerActive)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(15, 0, 15, 15),
                            child: SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () => _showHearingDialog(context, doc.id, collectionName),
                                icon: const Icon(Icons.edit_calendar_rounded, size: 18),
                                label: const Text("Update Hearing Detail"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: navyBlue,
                                  foregroundColor: gold,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            ),
                          ),
                        if (canResolve)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(15, 0, 15, 15),
                            child: SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () => _markAsResolved(doc.id, collectionName),
                                icon: const Icon(Icons.check_circle_outline, size: 18),
                                label: const Text("Mark as Resolved / Completed"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.teal,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  void _showStatusNotice(BuildContext context, String status) {
    String message = "Chat will be available once the request is Accepted.";
    if (status.toLowerCase() == 'rejected') message = "This request was rejected.";
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: const Color(0xFF001F3F)));
  }
}