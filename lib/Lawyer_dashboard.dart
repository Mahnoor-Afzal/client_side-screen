import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'case_requet_screen.dart';
import 'login_selection_screen.dart';
import 'active_cases_screen.dart';
import 'consultation_screen.dart';
import 'documents_screen.dart';
import 'hearings_list_screen.dart';

class LawyerDashboard extends StatefulWidget {
  const LawyerDashboard({super.key});

  @override
  State<LawyerDashboard> createState() => _LawyerDashboardState();
}

class _LawyerDashboardState extends State<LawyerDashboard> {
  User? get currentUser => FirebaseAuth.instance.currentUser;
  StreamSubscription? _sub1;
  StreamSubscription? _sub2;
  final Set<String> _notifiedRequestIds = {}; 

  final Color navyBlue = const Color(0xFF101D3D);
  final Color goldColor = const Color(0xFFC5A358);
  final Color lightGrey = const Color(0xFFF5F5F5);

  @override
  void initState() {
    super.initState();
    _initNotificationListener();
  }

  @override
  void dispose() {
    _sub1?.cancel();
    _sub2?.cancel();
    super.dispose();
  }

  void _initNotificationListener() {
    final uid = currentUser?.uid;
    if (uid == null) return;
    
    _sub1 = FirebaseFirestore.instance
        .collection('Case request')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen((snapshot) {
      for (var doc in snapshot.docs) {
        var data = doc.data();
        String lId = (data['lawyerid'] ?? data['lawyerId'] ?? "").toString();
        if (lId == uid && !_notifiedRequestIds.contains(doc.id)) {
          _notifiedRequestIds.add(doc.id);
          _triggerPopUp(doc);
        }
      }
    });

    _sub2 = FirebaseFirestore.instance
        .collection('suit_a_file_request')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen((snapshot) {
      for (var doc in snapshot.docs) {
        if (!_notifiedRequestIds.contains(doc.id)) {
          _notifiedRequestIds.add(doc.id);
          _triggerPopUp(doc);
        }
      }
    });
  }

  void _triggerPopUp(DocumentSnapshot doc) {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showRequestDialog(doc);
    });
  }

  void _showRequestDialog(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    String clientName = data['clientName'] ?? data['fullName'] ?? 'New Request';
    String type = data['caseType'] ?? data['title'] ?? 'Legal Matter';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: navyBlue,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.notifications_active, color: goldColor),
            const SizedBox(width: 10),
            const Text("New Request!", style: TextStyle(color: Colors.white, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Client: $clientName", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),
            Text("Case: $type", style: const TextStyle(color: Colors.white70)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => _updateStatus(doc, 'rejected', context),
            child: const Text("REJECT", style: TextStyle(color: Colors.redAccent)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: goldColor),
            onPressed: () => _updateStatus(doc, 'accepted', context),
            child: Text("ACCEPT", style: TextStyle(color: navyBlue, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _updateStatus(DocumentSnapshot doc, String status, BuildContext dialogContext) async {
    try {
      final String lawyerId = currentUser?.uid ?? "";
      await doc.reference.set({
        'status': status,
        'lawyerid': lawyerId, 
      }, SetOptions(merge: true));

      if (status == 'accepted') {
        var data = doc.data() as Map<String, dynamic>;
        String clientId = data['clientId'] ?? data['userId'] ?? "";
        String clientName = data['clientName'] ?? data['fullName'] ?? "Client";

        // Using 'chat' collection as per requirement
        await FirebaseFirestore.instance.collection('chat').doc(doc.id).set({
          'requestId': doc.id,
          'lawyerid': lawyerId,
          'clientId': clientId,
          'clientName': clientName,
          'topic': data['caseType'] ?? data['title'] ?? 'Legal Matter',
          'status': 'ongoing',
          'lastMessage': 'Case accepted. Chat started.',
          'lastMessageTime': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'date': DateFormat('dd MMM yyyy').format(DateTime.now()),
        }, SetOptions(merge: true));

        if (clientId.isNotEmpty) {
          await FirebaseFirestore.instance.collection('notifications').add({
            'userId': clientId,
            'title': 'Case Accepted!',
            'body': 'Your lawyer has accepted the case. You can start chatting.',
            'type': 'chat_enabled',
            'requestId': doc.id,
            'timestamp': FieldValue.serverTimestamp(),
            'isRead': false,
          });
        }
      }

      if (mounted) Navigator.pop(dialogContext);
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightGrey,
      appBar: AppBar(
        backgroundColor: navyBlue,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text("Dashboard", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      drawer: Drawer(
        child: Container(
          color: navyBlue,
          child: Column(
            children: [
              UserAccountsDrawerHeader(
                decoration: BoxDecoration(color: goldColor),
                currentAccountPicture: const CircleAvatar(
                  backgroundColor: Colors.white,
                  child: Icon(Icons.person, size: 50, color: Color(0xFF101D3D)),
                ),
                accountName: StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance.collection('lawyers').doc(currentUser?.uid).snapshots(),
                  builder: (context, snapshot) {
                    String name = "Lawyer";
                    bool verified = false;
                    if (snapshot.hasData && snapshot.data!.exists) {
                      var data = snapshot.data!.data() as Map<String, dynamic>?;
                      name = data?['fullName'] ?? "Lawyer";
                      verified = data?['isVerified'] ?? false;
                    }
                    return Row(
                      children: [
                        Flexible(child: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white), overflow: TextOverflow.ellipsis)),
                        if (verified) ...[const SizedBox(width: 5), const Icon(Icons.verified, color: Colors.blue, size: 18)]
                      ],
                    );
                  },
                ),
                accountEmail: Text(currentUser?.email ?? "", style: const TextStyle(color: Colors.white70)),
              ),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    _buildDrawerItem(Icons.dashboard, "Dashboard", onTap: () => Navigator.pop(context)),
                    _buildDrawerItem(Icons.assignment_ind, "New Requests", onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CaseRequestsScreen()))),
                    _buildDrawerItem(Icons.check_circle, "Active Cases", onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ActiveCasesScreen()))),
                    _buildDrawerItem(Icons.gavel, "Hearings", onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const HearingsListScreen()))),
                    _buildDrawerItem(Icons.forum, "Consultations", onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ConsultationScreen()))),
                    const Divider(color: Colors.white24),
                    _buildDrawerItem(Icons.logout, "Logout", isLogout: true, onTap: () async {
                      await FirebaseAuth.instance.signOut();
                      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const LoginSelectionScreen()), (route) => false);
                    }),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: navyBlue,
                borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
              ),
              child: StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance.collection('lawyers').doc(currentUser?.uid).snapshots(),
                builder: (context, snapshot) {
                  String name = "Lawyer";
                  bool verified = false;
                  if (snapshot.hasData && snapshot.data!.exists) {
                    var data = snapshot.data!.data() as Map<String, dynamic>?;
                    name = data?['fullName'] ?? "Lawyer";
                    verified = data?['isVerified'] ?? false;
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Hello,", style: TextStyle(color: Colors.white70, fontSize: 16)),
                      Row(
                        children: [
                          Flexible(child: Text(name, style: TextStyle(color: goldColor, fontSize: 24, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                          if (verified) ...[const SizedBox(width: 8), const Icon(Icons.verified, color: Colors.blue, size: 24)]
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(15.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      _buildDynamicStatCard("Active", "accepted", Colors.blue, () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => const ActiveCasesScreen()));
                      }),
                      const SizedBox(width: 15),
                      _buildDynamicStatCard("Pending", "pending", Colors.orange, () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => const CaseRequestsScreen()));
                      }),
                    ],
                  ),
                  const SizedBox(height: 25),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    mainAxisSpacing: 15,
                    crossAxisSpacing: 15,
                    children: [
                      _buildMenuTile(icon: Icons.assignment_ind, title: "Case Requests", color: Colors.indigo, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CaseRequestsScreen()))),
                      _buildMenuTile(icon: Icons.folder_shared, title: "Documents", color: Colors.teal, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const DocumentsScreen()))),
                      _buildMenuTile(icon: Icons.gavel, title: "Hearings", color: Colors.amber[900]!, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const HearingsListScreen()))),
                      _buildMenuTile(icon: Icons.forum, title: "Consultations", color: Colors.green, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ConsultationScreen()))),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuTile({required IconData icon, required String title, required Color color, required VoidCallback onTap}) {
    return Material(
      color: Colors.white, borderRadius: BorderRadius.circular(20), elevation: 2,
      child: InkWell(
        onTap: onTap, borderRadius: BorderRadius.circular(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(backgroundColor: color.withOpacity(0.1), child: Icon(icon, color: color)),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF101D3D)), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildDynamicStatCard(String label, String status, Color color, VoidCallback onTap) {
    return Expanded(
      child: Material(
        color: Colors.white, borderRadius: BorderRadius.circular(15), elevation: 2,
        child: InkWell(
          onTap: onTap, borderRadius: BorderRadius.circular(15),
          child: StreamBuilder<List<QuerySnapshot>>(
            stream: _getCombinedCountsStream(),
            builder: (context, snapshot) {
              int count = 0;
              if (snapshot.hasData) {
                for (var snap in snapshot.data!) {
                  count += snap.docs.where((doc) {
                    var data = doc.data() as Map<String, dynamic>;
                    String s = (data['status'] ?? "pending").toString().toLowerCase().trim();
                    String lId = (data['lawyerid'] ?? data['lawyerId'] ?? "").toString().trim();
                    if (doc.reference.parent.id == 'suit_a_file_request') return s == status;
                    return s == status && lId == currentUser?.uid;
                  }).length;
                }
              }
              return Container(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(count.toString(), style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: color)),
                    const SizedBox(height: 5),
                    Text("$label Cases", style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w500)),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Stream<List<QuerySnapshot>> _getCombinedCountsStream() {
    StreamController<List<QuerySnapshot>> controller = StreamController();
    StreamSubscription? s1; StreamSubscription? s2;
    QuerySnapshot? q1; QuerySnapshot? q2;
    void update() {
      if (!controller.isClosed) {
        List<QuerySnapshot> res = [];
        if (q1 != null) res.add(q1!); if (q2 != null) res.add(q2!);
        if (res.isNotEmpty) controller.add(res);
      }
    }
    s1 = FirebaseFirestore.instance.collection('Case request').snapshots().listen((s) { q1 = s; update(); });
    s2 = FirebaseFirestore.instance.collection('suit_a_file_request').snapshots().listen((s) { q2 = s; update(); });
    controller.onCancel = () { s1?.cancel(); s2?.cancel(); controller.close(); };
    return controller.stream;
  }

  Widget _buildDrawerItem(IconData icon, String title, {bool isLogout = false, required VoidCallback onTap}) {
    return ListTile(
      leading: Icon(icon, color: isLogout ? Colors.redAccent : goldColor),
      title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 16)),
      onTap: onTap,
    );
  }
}
