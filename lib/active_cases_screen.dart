import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'Hearing_details.dart';
import 'chat_screen.dart';
import 'wakalatnama_form.dart';

class ActiveCasesScreen extends StatelessWidget {
  const ActiveCasesScreen({super.key});

  final Color navyBlue = const Color(0xFF101D3D);
  final Color goldColor = const Color(0xFFC5A358);

  @override
  Widget build(BuildContext context) {
    final String? uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text("Active Cases", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: navyBlue,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: uid == null
          ? const Center(child: Text("Please login to see your cases"))
          : StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('suit_a_file_request').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          List<DocumentSnapshot> allActive = [];
          if (snapshot.hasData) {
            allActive = snapshot.data!.docs.where((doc) {
              var data = doc.data() as Map<String, dynamic>;
              String status = (data['status'] ?? "").toString().toLowerCase().trim();
              String leadId = (data['lawyerid'] ?? data['lawyerId'] ?? "").toString().trim();

              List assigned = data['assignedLawyers'] ?? [];
              bool isAssigned = (leadId == uid.trim()) || assigned.contains(uid.trim());

              bool isActive = status == 'accepted' || status == 'active';
              return isActive && isAssigned;
            }).toList();
          }

          if (allActive.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.assignment_turned_in_outlined, size: 70, color: Colors.grey[300]),
                  const SizedBox(height: 10),
                  const Text("No active cases found", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: allActive.length,
            itemBuilder: (context, index) {
              var doc = allActive[index];
              var data = doc.data() as Map<String, dynamic>;
              String name = data['clientName'] ?? data['fullName'] ?? "Client";
              String type = data['caseType'] ?? data['title'] ?? "Active Matter";
              String clientId = data['clientId'] ?? data['userId'] ?? "";
              List teamNames = data['teamNames'] ?? [];

              return _buildCaseCard(context, doc.id, name, type, clientId, uid, teamNames);
            },
          );
        },
      ),
    );
  }

  Widget _buildCaseCard(
      BuildContext context,
      String id,
      String name,
      String type,
      String clientId,
      String currentLawyerId,
      List teamNames,
      ) {
    String lawyersText = teamNames.isEmpty ? "" : "Team: ${teamNames.join(', ')}";

    return Card(
      elevation: 4,
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
                Expanded(
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: navyBlue,
                        radius: 22,
                        child: const Icon(Icons.person, color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name, style: TextStyle(fontWeight: FontWeight.bold, color: navyBlue, fontSize: 18)),
                            Text(type, style: const TextStyle(fontSize: 13, color: Colors.black54)),
                            const SizedBox(height: 4),
                            InkWell(
                              onTap: () {
                                Clipboard.setData(ClipboardData(text: id));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("Case ID Copied!"), duration: Duration(seconds: 1)),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: navyBlue.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text("Case ID: $id", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: navyBlue)),
                                    const SizedBox(width: 4),
                                    Icon(Icons.copy_rounded, size: 12, color: navyBlue),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.group_add_rounded, color: goldColor, size: 28),
                  onPressed: () => _showAddLawyerDialog(context, id, name, type, clientId),
                ),
              ],
            ),
            if (lawyersText.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(lawyersText, style: TextStyle(color: goldColor, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            const SizedBox(height: 12),
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('chat').doc(id).snapshots(),
              builder: (context, chatSnap) {
                String lastMsg = "Communication active...";
                if (chatSnap.hasData && chatSnap.data!.exists) {
                  var cData = chatSnap.data!.data() as Map<String, dynamic>;
                  lastMsg = cData['lastMessage'] ?? lastMsg;
                }
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(10)),
                  child: Row(
                    children: [
                      const Icon(Icons.chat_bubble_outline, size: 14, color: Colors.blue),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          lastMsg,
                          style: const TextStyle(fontSize: 12, color: Colors.blueGrey, fontStyle: FontStyle.italic),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider(height: 1)),
            Wrap(
              spacing: 8,
              runSpacing: 10,
              children: [
                _buildActionChip(context, Icons.chat_outlined, "Chat", Colors.blue, () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => ChatScreen(consultationId: id, clientName: name, clientId: clientId)));
                }),
                _buildActionChip(context, Icons.gavel, "Hearings", goldColor, () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => HearingDetailsScreen(caseId: id, clientName: name, clientId: clientId)));
                }),
                _buildActionChip(context, Icons.assignment_outlined, "Vakalatnama", Colors.teal, () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => WakalatnamaForm(clientId: clientId, clientName: name, requestId: id)));
                }),
                _buildActionChip(context, Icons.check_circle_outline, "Close Case", Colors.red, () {
                  _showCloseCaseDialog(context, id);
                }),
              ],
            )
          ],
        ),
      ),
    );
  }

  // Lawyer closes case -> Updates fields in 'suit_a_file_request' for client tracking
  void _showCloseCaseDialog(BuildContext context, String caseId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Close Case"),
        content: const Text("Are you sure you want to close this case? This will notify the client to rate your services."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("CANCEL"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              try {
                DocumentReference caseRef = FirebaseFirestore.instance.collection('suit_a_file_request').doc(caseId);

                // Proper fields initialized for client rating workflow
                await caseRef.update({
                  'status': 'closed',
                  'closedBy': 'lawyer',
                  'closedAt': FieldValue.serverTimestamp(),
                  'isRated': false,
                  'rating': 0.0,
                  'review': '',
                });

                await FirebaseFirestore.instance.collection('coordination').doc(caseId).set({
                  'status': 'closed',
                  'updatedAt': FieldValue.serverTimestamp(),
                }, SetOptions(merge: true));

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Case closed successfully. Client can now rate."), backgroundColor: Colors.green),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Error closing case: $e")),
                  );
                }
              }
            },
            child: const Text("CONFIRM", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showAddLawyerDialog(BuildContext context, String caseId, String clientName, String caseType, String clientId) {
    final TextEditingController emailController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Add Team Member"),
        content: TextField(
          controller: emailController,
          decoration: const InputDecoration(hintText: "Enter Lawyer's Email"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: navyBlue),
            onPressed: () async {
              String email = emailController.text.trim();
              if (email.isEmpty) return;
              try {
                var lawyerQuery = await FirebaseFirestore.instance.collection('lawyers').where('email', isEqualTo: email).limit(1).get();
                if (lawyerQuery.docs.isNotEmpty) {
                  String associateId = lawyerQuery.docs.first.id;
                  String associateName = lawyerQuery.docs.first.get('fullName') ?? "Lawyer";

                  WriteBatch batch = FirebaseFirestore.instance.batch();
                  DocumentReference caseRef = FirebaseFirestore.instance.collection('suit_a_file_request').doc(caseId);

                  batch.update(caseRef, {
                    'assignedLawyers': FieldValue.arrayUnion([associateId]),
                    'teamNames': FieldValue.arrayUnion([associateName])
                  });

                  DocumentReference chatRef = FirebaseFirestore.instance.collection('chat').doc(caseId);
                  batch.set(chatRef, {
                    'users': FieldValue.arrayUnion([associateId])
                  }, SetOptions(merge: true));

                  DocumentReference coordRef = FirebaseFirestore.instance.collection('coordination').doc(caseId);
                  batch.set(coordRef, {
                    'requestId': caseId,
                    'clientId': clientId,
                    'clientName': clientName,
                    'caseType': caseType,
                    'assignedLawyers': FieldValue.arrayUnion([associateId]),
                    'updatedAt': FieldValue.serverTimestamp(),
                    'status': 'active'
                  }, SetOptions(merge: true));

                  await batch.commit();

                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Team member added successfully."), backgroundColor: Colors.green),
                    );
                  }
                } else {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lawyer not found.")));
                  }
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
                }
              }
            },
            child: const Text("ADD"),
          ),
        ],
      ),
    );
  }

  Widget _buildActionChip(BuildContext context, IconData icon,String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}