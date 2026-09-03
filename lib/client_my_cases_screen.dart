import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'client_chat_screen.dart';
import 'client_lawyer_profile_screen.dart';
import 'client_notification_helper.dart';

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
        'status': 'closed', // Changed from 'Completed' to 'closed' to match your database screenshot
        'completedAt': FieldValue.serverTimestamp(),
        'needsRating': true,
        'isRated': false,
      });

      // Send notification to client
      try {
        var caseDoc = await FirebaseFirestore.instance.collection(collectionName).doc(docId).get();
        if (caseDoc.exists) {
          var caseData = caseDoc.data() as Map<String, dynamic>;
          String clientId = caseData['clientId'];
          String lawyerName = caseData['lawyerName'] ?? 'Your lawyer';

          await FirebaseFirestore.instance.collection('notifications').add({
            'userId': clientId,
            'title': 'Case Closed',
            'body': '$lawyerName has closed your case. Please rate the service.',
            'type': 'case_completed',
            'createdAt': FieldValue.serverTimestamp(),
            'isRead': false,
            'requestId': docId,
            'collectionName': collectionName,
            'lawyerId': caseData['lawyerId'],
            'senderId': caseData['lawyerId'],
            'senderName': lawyerName,
          });

          // Update Hearings collection as well
          await FirebaseFirestore.instance.collection('Hearings').doc(docId).set({
            'status': 'closed',
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

          // Send Push Notification
          DocumentSnapshot clientDoc = await FirebaseFirestore.instance.collection('users').doc(clientId).get();
          if (clientDoc.exists) {
            String? token = (clientDoc.data() as Map<String, dynamic>?)?['fcmToken'];
            if (token != null && token.isNotEmpty) {
              await NotificationHelper.sendGlobalPushNotification(
                token: token,
                title: "Case Completed",
                body: "$lawyerName has marked your case as completed. Please rate the service.",
                data: {
                  'click_action': 'FLUTTER_NOTIFICATION_CLICK',
                  'type': 'case_completed',
                  'requestId': docId,
                  'collectionName': collectionName,
                  'lawyerId': caseData['lawyerId'],
                  'senderId': caseData['lawyerId'],
                  'senderName': lawyerName,
                },
              );
            }
          }
        }
      } catch (e) {
        debugPrint("Error sending completion notification: $e");
      }

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
                  'hearingDescription': detailsController.text,
                  'hearingDetails': detailsController.text,
                });

                // Client ko notification bhejein
                try {
                  var caseDoc = await FirebaseFirestore.instance.collection(collectionName).doc(docId).get();
                  if (caseDoc.exists) {
                    var caseData = caseDoc.data() as Map<String, dynamic>;
                    String clientId = caseData['clientId'];

                    await FirebaseFirestore.instance.collection('notifications').add({
                      'userId': clientId,
                      'title': 'Hearing Update',
                      'body': 'Your lawyer has set a new hearing date: ${dateController.text}',
                      'type': 'hearing_update',
                      'createdAt': FieldValue.serverTimestamp(),
                      'isRead': false,
                      'requestId': docId,
                      'senderId': caseData['lawyerId'],
                      'senderName': caseData['lawyerName'] ?? 'Your Lawyer',
                      'hearing_date': dateController.text,
                    });

                    // Update Hearings collection immediately to maintain history
                    DocumentReference hearingRef = FirebaseFirestore.instance.collection('Hearings').doc(docId);
                    await FirebaseFirestore.instance.runTransaction((transaction) async {
                      DocumentSnapshot hSnap = await transaction.get(hearingRef);
                      Map<String, dynamic> updateData = {
                        'clientId': clientId,
                        'case_type': caseData['type'] ?? (collectionName == 'consultation_request' ? 'Consultation' : 'File a Suit'),
                        'hearing_date': dateController.text,
                        'status': 'Upcoming',
                        'hearingDescription': detailsController.text,
                        'details': detailsController.text,
                        'lawyerId': caseData['lawyerId'],
                        'lawyerName': caseData['lawyerName'],
                        'updatedAt': FieldValue.serverTimestamp(),
                      };

                      if (hSnap.exists) {
                        Map<String, dynamic> existing = hSnap.data() as Map<String, dynamic>;
                        List<dynamic> history = List.from(existing['previous_hearings'] ?? []);
                        var currentHDate = existing['hearing_date'];
                        
                        if (currentHDate != null && currentHDate.toString() != dateController.text) {
                          // Check if this date already exists in history to avoid duplicates
                          bool alreadyInHistory = history.any((h) => 
                            (h['hearing_date'] ?? h['date']).toString() == currentHDate.toString());

                          if (!alreadyInHistory) {
                            history.add({
                              'hearing_date': currentHDate,
                              'status': existing['status'] ?? 'Completed',
                              'court_location': existing['court_location'] ?? 'N/A',
                              'date': currentHDate,
                              'details': existing['details'] ?? '',
                              'hearingDescription': existing['hearingDescription'] ?? existing['details'] ?? '',
                              'archivedAt': FieldValue.serverTimestamp(),
                            });
                          }
                        }
                        updateData['previous_hearings'] = history;
                        
                        // Also add to History subcollection for extra durability
                        transaction.set(
                          hearingRef.collection('History').doc(),
                          {
                            'hearing_date': currentHDate ?? dateController.text,
                            'status': existing['status'] ?? 'Completed',
                            'court_location': existing['court_location'] ?? 'N/A',
                            'details': existing['details'] ?? '',
                            'updatedAt': FieldValue.serverTimestamp(),
                          }
                        );
                      }
                      transaction.set(hearingRef, updateData, SetOptions(merge: true));
                    });

                    // Send Push Notification
                    DocumentSnapshot clientDoc = await FirebaseFirestore.instance.collection('users').doc(clientId).get();
                    if (clientDoc.exists) {
                      String? token = (clientDoc.data() as Map<String, dynamic>?)?['fcmToken'];
                      if (token != null && token.isNotEmpty) {
                        await NotificationHelper.sendGlobalPushNotification(
                          token: token,
                          title: "Hearing Update",
                          body: "Your lawyer has set a new hearing date: ${dateController.text}",
                          data: {
                            'click_action': 'FLUTTER_NOTIFICATION_CLICK',
                            'type': 'hearing_update',
                            'requestId': docId,
                            'senderId': caseData['lawyerId'],
                            'senderName': caseData['lawyerName'] ?? 'Your Lawyer',
                            'hearing_date': dateController.text,
                          },
                        );
                      }
                    }
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
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: navyBlue,
        elevation: 0,
        title: Text(title, style: const TextStyle(color: gold, fontWeight: FontWeight.bold)),
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
                    case 'completed':
                    case 'closed': statusColor = Colors.teal; break;
                    case 'rejected': statusColor = Colors.red; break;
                    default: statusColor = Colors.orange;
                  }

                  bool canChat = ['accepted', 'active', 'in progress', 'completed', 'closed'].contains(status.toLowerCase());
                  bool isLawyerActive = (['active', 'accepted', 'in progress'].contains(status.toLowerCase())) && _userRole == 'lawyer';
                  bool canResolve = (['active', 'accepted', 'in progress'].contains(status.toLowerCase())) && _userRole == 'lawyer';
                  bool canRate = _userRole == 'client' && 
                                (status.toLowerCase() == 'completed' || status.toLowerCase() == 'closed') && 
                                (caseData['isRated'] == false || caseData['isRated'] == null);
                  Map<String, dynamic>? aiAnalysis = caseData['aiAnalysis'];

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
                                : "Lawyer: ${caseData['lawyerName'] ?? 'Searching for Expert'}"),
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
                        if (canRate)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(15, 0, 15, 15),
                            child: SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () => _showRatingDialog(context, caseData['lawyerId'], doc.id, collectionName),
                                icon: const Icon(Icons.star_half_rounded, size: 18),
                                label: const Text("Rate Lawyer"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: gold,
                                  foregroundColor: navyBlue,
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

  void _showRatingDialog(BuildContext context, String? lawyerId, String? requestId, String? collectionName) {
    if (lawyerId == null) return;
    double selectedRating = 5.0;
    const Color navyBlue = Color(0xFF001F3F);
    const Color gold = Color(0xFFD4AF37);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("Rate your Lawyer", style: TextStyle(color: navyBlue, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("How was your experience?"),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return IconButton(
                    icon: Icon(
                      index < selectedRating ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                      size: 32,
                    ),
                    onPressed: () => setDialogState(() => selectedRating = index + 1.0),
                  );
                }),
              ),
              Text("$selectedRating / 5.0", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("LATER")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: navyBlue, foregroundColor: gold),
              onPressed: () async {
                await _submitRating(lawyerId, selectedRating, requestId, collectionName);
                if (!context.mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Thank you for your feedback!")));
              },
              child: const Text("SUBMIT"),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitRating(String lawyerId, double rating, String? requestId, String? collectionName) async {
    try {
      DocumentReference lawyerRef = FirebaseFirestore.instance.collection('verified_lawyers').doc(lawyerId);
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        DocumentSnapshot snapshot = await transaction.get(lawyerRef);
        if (!snapshot.exists) return;
        Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;
        double currentRating = double.tryParse((data['rating'] ?? '0').toString()) ?? 0.0;
        int reviewCount = int.tryParse((data['reviewCount'] ?? '0').toString()) ?? 0;
        double newRating = ((currentRating * reviewCount) + rating) / (reviewCount + 1);
        transaction.update(lawyerRef, {'rating': newRating, 'reviewCount': reviewCount + 1});
      });

      if (requestId != null && collectionName != null) {
        await FirebaseFirestore.instance.collection(collectionName).doc(requestId).update({
          'needsRating': false,
          'isRated': true,
          'clientRating': rating,
        });

        // Mark notification as read after rating
        final String? uid = FirebaseAuth.instance.currentUser?.uid;
        var notifs = await FirebaseFirestore.instance.collection('notifications')
            .where('requestId', isEqualTo: requestId)
            .where('type', isEqualTo: 'case_completed')
            .where('userId', isEqualTo: uid)
            .get();
        for (var doc in notifs.docs) {
          await doc.reference.update({'isRead': true});
        }
      }
    } catch (e) {
      debugPrint("Rating Error: $e");
    }
  }

  void _showStatusNotice(BuildContext context, String status) {
    String message = "Chat will be available once the request is Accepted.";
    if (status.toLowerCase() == 'rejected') message = "This request was rejected.";
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: const Color(0xFF001F3F)));
  }
}
