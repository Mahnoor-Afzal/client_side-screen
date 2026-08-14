import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;

// Screens imports
import 'view_lawyer_profile_screen.dart';
import 'chat_screen.dart';

const Color kNavyBlue = Color(0xFF101D3D);
const Color kGoldColor = Color(0xFFC5A358);

// ==========================================
// CLOUDINARY UPLOAD HELPER FUNCTION
// ==========================================
Future<String?> uploadToCloudinary(PlatformFile file) async {
  // Verified Cloudinary Credentials
  const String cloudName = "gasafl8q";
  const String uploadPreset = "ml_default";

  try {
    final uri = Uri.parse("https://api.cloudinary.com/v1_1/$cloudName/auto/upload");

    var request = http.MultipartRequest("POST", uri);
    request.fields['upload_preset'] = uploadPreset;

    if (kIsWeb) {
      // Web support using raw bytes
      if (file.bytes == null) return null;
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          file.bytes!,
          filename: file.name,
        ),
      );
    } else {
      // Mobile / Desktop support using local path
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
      return jsonMap['secure_url']; // Cloudinary HTTPS link
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

// Universal function: Open documents/links on Web and Mobile
Future<void> openDocumentUrl(BuildContext context, String fileUrl) async {
  if (fileUrl.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("File URL is missing or file was not uploaded properly."),
        backgroundColor: Colors.orange,
      ),
    );
    return;
  }

  try {
    final Uri uri = Uri.parse(fileUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Could not open the file link."), backgroundColor: Colors.red),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error opening file: $e"), backgroundColor: Colors.red),
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
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        appBar: AppBar(
          title: const Text("Lawyer Coordination", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          backgroundColor: kNavyBlue,
          iconTheme: const IconThemeData(color: Colors.white),
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(text: "My Teams", icon: Icon(Icons.group)),
              Tab(text: "Verified Lawyers", icon: Icon(Icons.verified_user)),
            ],
          ),
        ),
        body: uid == null
            ? const Center(child: Text("Please login to see coordination data"))
            : TabBarView(
          children: [
            _MyTeamsTab(uid: uid),
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
          return assigned.contains(uid);
        }).toList();

        if (myCases.isEmpty) return _buildEmptyState();

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: myCases.length,
          itemBuilder: (context, index) {
            var doc = myCases[index];
            return CoordinationCard(caseId: doc.id, data: doc.data() as Map<String, dynamic>);
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
          const Text("No active coordination found", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

// ==========================================
// 2. VERIFIED LAWYERS TAB WIDGET
// ==========================================
class _VerifiedLawyersTab extends StatelessWidget {
  final String currentUid;
  const _VerifiedLawyersTab({required this.currentUid});

  void _showCaseSelectionDialog(BuildContext context, String targetLawyerId, String targetLawyerName) async {
    try {
      var casesSnapshot = await FirebaseFirestore.instance.collection('cases').get();

      List<QueryDocumentSnapshot> activeCases = casesSnapshot.docs.where((doc) {
        var data = doc.data() as Map<String, dynamic>;
        String lawyerId = data['lawyerId'] ?? data['leadLawyerId'] ?? '';
        List assigned = data['assignedLawyers'] ?? [];
        String createdBy = data['created_by'] ?? data['clientId'] ?? '';
        String status = (data['status'] ?? 'active').toString().toLowerCase();

        bool isMyCase = (lawyerId == currentUid) || assigned.contains(currentUid) || (createdBy == currentUid);
        bool isActive = status == 'active' || (status != 'completed' && status != 'cancelled' && status != 'rejected' && status != 'inactive');

        return isMyCase && isActive;
      }).toList();

      if (!context.mounted) return;

      if (activeCases.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No Active Cases found for your account."), backgroundColor: Colors.orange),
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
      stream: FirebaseFirestore.instance.collection('lawyers').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("No lawyers found", style: TextStyle(color: Colors.grey)));
        }

        var lawyers = snapshot.data!.docs.where((doc) => doc.id != currentUid).toList();

        if (lawyers.isEmpty) {
          return const Center(child: Text("No other lawyers found", style: TextStyle(color: Colors.grey)));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: lawyers.length,
          itemBuilder: (context, index) {
            var doc = lawyers[index];
            var data = doc.data() as Map<String, dynamic>;

            String val(dynamic v, String def) => (v == null) ? def : (v is List ? v.join(", ") : v.toString());

            String name = val(data['fullName'] ?? data['name'], "Lawyer");
            String? profileImg = data['profileImageUrl'];
            String category = val(data['category'] ?? data['specialization'], "Legal Expert");
            String barCouncil = val(data['barCouncil'], "Bar Council Name");
            String location = val(data['location'], "Location");
            String court = val(data['court'], "Supreme Court");
            String experience = val(data['experience'], "N/A");
            String bio = val(data['bio'] ?? data['about'], "I am a professional lawyer.");

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
                    const SizedBox(height: 8),

                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.grey.shade300),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => ViewLawyerProfileScreen(lawyerData: data)),
                          );
                        },
                        child: const Text("View Full Profile", style: TextStyle(color: kNavyBlue, fontWeight: FontWeight.bold)),
                      ),
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
// 3. COORDINATION CARD WIDGET
// ==========================================
class CoordinationCard extends StatelessWidget {
  final String caseId;
  final Map<String, dynamic> data;

  const CoordinationCard({super.key, required this.caseId, required this.data});

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
                  const Text("Shared Documents & Case Notes", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: kNavyBlue)),
                  const SizedBox(height: 15),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('cases')
                          .doc(caseId)
                          .collection('shared_documents')
                          .orderBy('createdAt', descending: true)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return const Center(child: Text("No shared files or notes yet."));
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
                                onTap: () => openDocumentUrl(context, fileUrl),
                                leading: CircleAvatar(
                                  backgroundColor: kNavyBlue.withValues(alpha: 0.1),
                                  child: const Icon(Icons.description, color: kNavyBlue),
                                ),
                                title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text(
                                  "${fileName.isNotEmpty ? 'File: $fileName\n' : ''}${notes.isNotEmpty ? 'Notes: $notes' : ''}",
                                  style: const TextStyle(fontSize: 12),
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.file_download, color: Colors.grey),
                                  onPressed: () => openDocumentUrl(context, fileUrl),
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

  @override
  Widget build(BuildContext context) {
    String clientName = data['clientName'] ?? data['client_name'] ?? data['userName'] ?? data['name'] ?? "Ali";
    String caseType = data['caseType'] ?? data['category'] ?? "Legal Matter";
    String clientId = data['clientId'] ?? data['created_by'] ?? caseId;
    List assignedLawyersIds = data['assignedLawyers'] ?? [];

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
                  .collection('lawyers')
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

                    return Chip(
                      avatar: const CircleAvatar(backgroundColor: kNavyBlue, child: Icon(Icons.gavel, size: 12, color: Colors.white)),
                      label: Text(lName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      backgroundColor: Colors.grey.shade100,
                      side: BorderSide(color: Colors.grey.shade300),
                    );
                  }).toList(),
                );
              },
            ),

            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
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
                icon: Icon(Icons.note_add_outlined, size: 18, color: Colors.deepPurple.shade700),
                label: Text("Share Doc / File", style: TextStyle(color: Colors.deepPurple.shade700, fontWeight: FontWeight.w600)),
              ),
            ),

            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _showSharedFilesBottomSheet(context),
                icon: Icon(Icons.folder_open, size: 16, color: Colors.deepPurple.shade700),
                label: Text("View Shared Files & Notes", style: TextStyle(color: Colors.deepPurple.shade700, fontSize: 13, fontWeight: FontWeight.bold)),
              ),
            ),

            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: kNavyBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(
                        consultationId: clientId,
                        clientName: clientName,
                        clientId: clientId,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.forum_outlined, size: 18),
                label: const Text("Team Chat", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 4. CASE SELECTION DIALOG
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
      var currentLawyerDoc = await FirebaseFirestore.instance.collection('lawyers').doc(currentUid).get();
      String senderName = "Lawyer";
      if (currentLawyerDoc.exists) {
        var data = currentLawyerDoc.data();
        senderName = data?['fullName'] ?? data?['name'] ?? "Lawyer";
      }

      await FirebaseFirestore.instance.collection('coordination_requests').add({
        'senderId': currentUid,
        'senderName': senderName,
        'receiverId': targetLawyerId,
        'receiverName': targetLawyerName,
        'caseId': caseId,
        'clientName': clientName,
        'status': 'Pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      await FirebaseFirestore.instance.collection('cases').doc(caseId).update({
        'assignedLawyers': FieldValue.arrayUnion([currentUid, targetLawyerId])
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

            String clientName = caseData['clientName'] ?? caseData['client_name'] ?? caseData['userName'] ?? caseData['name'] ?? "Ali";
            String caseType = caseData['caseType'] ?? caseData['category'] ?? "Active Matter";
            String caseId = caseDoc.id;

            return Card(
              elevation: 1,
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ListTile(
                leading: const CircleAvatar(backgroundColor: kNavyBlue, child: Icon(Icons.person, color: Colors.white, size: 20)),
                title: Text(clientName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                subtitle: Text("$caseType • ID: $caseId", style: const TextStyle(fontSize: 12, color: Colors.black54)),
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
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(color: Colors.red))),
      ],
    );
  }
}

// ==========================================
// 5. SHARE DOC DIALOG (With Working Cloudinary Logic)
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
      title: const Text("Share Case Document / Update", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
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
              decoration: const InputDecoration(labelText: "Notes / Details (Optional)", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 15),

            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: kNavyBlue),
                minimumSize: const Size(double.infinity, 45),
              ),
              onPressed: () async {
                FilePickerResult? result = await FilePicker.platform.pickFiles(
                  withData: true, // Crucial for Flutter Web to load bytes
                );

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

              // Upload file to Cloudinary if selected
              if (pickedFile != null) {
                String? uploadedUrl = await uploadToCloudinary(pickedFile!);
                if (uploadedUrl != null && uploadedUrl.isNotEmpty) {
                  fileUrl = uploadedUrl;
                } else {
                  throw Exception("Cloudinary upload failed. Please try again.");
                }
              }

              // Save record in Firestore
              await FirebaseFirestore.instance
                  .collection('cases')
                  .doc(widget.caseId)
                  .collection('shared_documents')
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
                    content: Text("Document Shared Successfully!"),
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
              : const Text("Share Document", style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}