import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';

import 'case_requet_screen.dart';
import 'pending_cases_screen.dart';
import 'login_selection_screen.dart';
import 'active_cases_screen.dart';
import 'consultation_screen.dart';
import 'documents_screen.dart';
import 'hearings_list_screen.dart';
import 'coordination_screen.dart';
import 'notification_screen.dart';
import 'messages_list_screen.dart';

class LawyerDashboard extends StatefulWidget {
  const LawyerDashboard({super.key});

  @override
  State<LawyerDashboard> createState() => _LawyerDashboardState();
}

class _LawyerDashboardState extends State<LawyerDashboard> {
  User? get currentUser => FirebaseAuth.instance.currentUser;

  static const Color navyBlue = Color(0xFF101D3D);
  static const Color goldColor = Color(0xFFC5A358);
  static const Color lightGrey = Color(0xFFF5F5F5);

  int _selectedIndex = 0;
  bool _isUploadingImage = false;

  @override
  void initState() {
    super.initState();
    _checkAccountStatus(); // Check if lawyer is blocked/suspended on entry
  }

  // --- Account Suspension / Block Check Logic ---
  Future<void> _checkAccountStatus() async {
    if (currentUser == null) return;

    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('verified_lawyers')
          .doc(currentUser!.uid)
          .get();

      if (doc.exists && doc.data() != null) {
        var data = doc.data() as Map<String, dynamic>;

        bool isBlocked = data['isBlocked'] ?? false;
        String status = (data['status'] ?? '').toString().toLowerCase().trim();
        String vStatus = (data['verificationStatus'] ?? '').toString().toLowerCase().trim();

        // Fetching block reason from Firestore fields
        String reason = data['blockReason'] ?? data['reason'] ?? 'Your account has been suspended or blocked by the admin due to policy violations.';

        // Condition if blocked or suspended
        if (isBlocked || status == 'suspended' || status == 'blocked' || vStatus == 'suspended' || vStatus == 'blocked') {
          if (!mounted) return;

          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.block, color: Colors.red),
                  SizedBox(width: 8),
                  Text("Account Restricted", style: TextStyle(color: Colors.red, fontSize: 18)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Your account has been blocked or suspended by the administration.",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  const Text("Reason:", style: TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      reason,
                      style: const TextStyle(color: navyBlue, fontStyle: FontStyle.italic),
                    ),
                  ),
                ],
              ),
              actions: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: navyBlue),
                  onPressed: () async {
                    await FirebaseAuth.instance.signOut();
                    if (!mounted) return;
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginSelectionScreen()),
                          (_) => false,
                    );
                  },
                  child: const Text("OK", style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("Error checking account status: $e");
    }
  }

  void _navigateTo(Widget screen) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen));

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
    final screens = [
      null,
      const MessagesListScreen(),
      const PendingCasesScreen(),
      const ActiveCasesScreen()
    ];
    if (screens[index] != null) _navigateTo(screens[index]!);
  }

  // Pending Total Stream (Case Requests + Consultation Requests) - For Bottom Nav 'Pending' Tab
  Stream<int> _getAllPendingRequestsCount() {
    if (currentUser == null) return Stream.value(0);
    final String uid = currentUser!.uid.trim();

    late StreamController<int> controller;
    StreamSubscription? sub1, sub2, sub3;
    QuerySnapshot? snap1, snap2, snap3;

    void updateCount() {
      if (!controller.isClosed) {
        int totalCount = 0;

        void countDocs(QuerySnapshot? snapshot) {
          if (snapshot == null) return;
          for (var doc in snapshot.docs) {
            var data = doc.data() as Map<String, dynamic>?;
            if (data == null) continue;

            String lawyer = (data['lawyerId'] ?? data['lawyerid'] ?? data['lawyerUID'] ?? '').toString().trim();
            String status = (data['status'] ?? 'pending').toString().toLowerCase().trim();

            if (lawyer == uid && (status == 'pending' || status.isEmpty)) {
              totalCount++;
            }
          }
        }

        countDocs(snap1);
        countDocs(snap2);
        countDocs(snap3);

        controller.add(totalCount);
      }
    }

    controller = StreamController<int>(
      onListen: () {
        sub1 = FirebaseFirestore.instance.collection('suit_a_file_request').snapshots().listen((s) { snap1 = s; updateCount(); });
        sub2 = FirebaseFirestore.instance.collection('Case request').snapshots().listen((s) { snap2 = s; updateCount(); });
        sub3 = FirebaseFirestore.instance.collection('consultation_request').snapshots().listen((s) { snap3 = s; updateCount(); });
      },
      onCancel: () {
        sub1?.cancel();
        sub2?.cancel();
        sub3?.cancel();
        controller.close();
      },
    );

    return controller.stream;
  }

  // Updated Unread Notifications Only Stream
  Stream<int> _getUnreadNotificationsCountOnly() {
    if (currentUser == null) return Stream.value(0);
    final String currentUid = currentUser!.uid.trim();

    return FirebaseFirestore.instance
        .collection('notifications')
        .snapshots()
        .map((snapshot) {
      int totalUnread = 0;

      for (var doc in snapshot.docs) {
        var data = doc.data();
        bool isRead = data['isRead'] ?? false;
        String notifUser = (data['userId'] ?? data['receiverId'] ?? data['lawyerId'] ?? data['toId'] ?? '').toString().trim();

        if (notifUser == currentUid && !isRead) {
          totalUnread += 1;
        }
      }

      return totalUnread;
    });
  }

  // Case Requests Only Stream (suit_a_file_request + Case request)
  Stream<int> _getCaseRequestsCountOnly() {
    if (currentUser == null) return Stream.value(0);
    final String uid = currentUser!.uid.trim();

    late StreamController<int> controller;
    StreamSubscription? sub1, sub2;
    QuerySnapshot? snap1, snap2;

    void updateCount() {
      if (!controller.isClosed) {
        int totalCount = 0;

        void countDocs(QuerySnapshot? snapshot) {
          if (snapshot == null) return;
          for (var doc in snapshot.docs) {
            var data = doc.data() as Map<String, dynamic>?;
            if (data == null) continue;

            String lawyer = (data['lawyerId'] ?? data['lawyerid'] ?? data['lawyerUID'] ?? '').toString().trim();
            String status = (data['status'] ?? 'pending').toString().toLowerCase().trim();

            if (lawyer == uid && (status == 'pending' || status.isEmpty)) {
              totalCount++;
            }
          }
        }

        countDocs(snap1);
        countDocs(snap2);

        controller.add(totalCount);
      }
    }

    controller = StreamController<int>(
      onListen: () {
        sub1 = FirebaseFirestore.instance.collection('suit_a_file_request').snapshots().listen((s) { snap1 = s; updateCount(); });
        sub2 = FirebaseFirestore.instance.collection('Case request').snapshots().listen((s) { snap2 = s; updateCount(); });
      },
      onCancel: () {
        sub1?.cancel();
        sub2?.cancel();
        controller.close();
      },
    );

    return controller.stream;
  }

  // Active Cases Stream
  Stream<int> _getActiveCasesCount() {
    if (currentUser == null) return Stream.value(0);
    final String uid = currentUser!.uid.trim();

    return FirebaseFirestore.instance
        .collection('suit_a_file_request')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.where((doc) {
        var data = doc.data();

        String lawyer = (data['lawyerid'] ?? data['lawyerId'] ?? data['lawyerUID'] ?? '').toString().trim();
        String status = (data['status'] ?? '').toString().toLowerCase().trim();
        List assigned = data['assignedLawyers'] ?? [];

        bool isMyLawyer = (lawyer == uid) || assigned.contains(uid);
        bool isActive = (status == 'accepted' || status == 'active');

        return isMyLawyer && isActive;
      }).length;
    });
  }

  // Profile Fetch Logic
  Future<Map<String, dynamic>> _fetchLawyerProfile() async {
    if (currentUser == null) return {};

    DocumentSnapshot doc = await FirebaseFirestore.instance
        .collection('verified_lawyers')
        .doc(currentUser!.uid)
        .get();

    if (doc.exists && doc.data() != null) {
      return doc.data() as Map<String, dynamic>;
    }

    if (currentUser?.email != null) {
      var query = await FirebaseFirestore.instance
          .collection('verified_lawyers')
          .where('email', isEqualTo: currentUser!.email)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        return query.docs.first.data();
      }
    }

    DocumentSnapshot lawyerDoc = await FirebaseFirestore.instance
        .collection('lawyers')
        .doc(currentUser!.uid)
        .get();

    if (lawyerDoc.exists && lawyerDoc.data() != null) {
      return lawyerDoc.data() as Map<String, dynamic>;
    }

    if (currentUser?.email != null) {
      var lawyerQuery = await FirebaseFirestore.instance
          .collection('lawyers')
          .where('email', isEqualTo: currentUser!.email)
          .limit(1)
          .get();

      if (lawyerQuery.docs.isNotEmpty) {
        return lawyerQuery.docs.first.data();
      }
    }

    return {};
  }

  // Profile Picture Handler
  Future<void> _pickAndUploadProfileImage() async {
    final image = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (image == null || currentUser == null) return;

    CroppedFile? croppedFile;
    try {
      croppedFile = await ImageCropper().cropImage(
        sourcePath: image.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Profile Picture',
            toolbarColor: navyBlue,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
          ),
          IOSUiSettings(title: 'Crop Profile Picture', aspectRatioLockEnabled: true),
          WebUiSettings(context: context),
        ],
      );
    } catch (e) {
      debugPrint("Cropper exception: $e");
    }

    final finalBytes = (croppedFile != null) ? await croppedFile.readAsBytes() : await image.readAsBytes();
    if (!mounted) return;
    setState(() => _isUploadingImage = true);

    try {
      final response = await http.post(
        Uri.parse("https://api.cloudinary.com/v1_1/gasafl8q/image/upload"),
        body: {'upload_preset': 'ml_default', 'file': 'data:image/jpeg;base64,${base64Encode(finalBytes)}'},
      );

      final responseData = jsonDecode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        final String imageUrl = responseData['secure_url'];

        await FirebaseFirestore.instance.collection('verified_lawyers').doc(currentUser!.uid).set(
          {'profileImageUrl': imageUrl},
          SetOptions(merge: true),
        );
        await FirebaseFirestore.instance.collection('lawyers').doc(currentUser!.uid).set(
          {'profileImageUrl': imageUrl},
          SetOptions(merge: true),
        );

        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Profile picture updated!")));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Upload failed: $e")));
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (currentUser == null) return const LoginSelectionScreen();

    return FutureBuilder<Map<String, dynamic>>(
      future: _fetchLawyerProfile(),
      builder: (context, snapshot) {
        final data = snapshot.data;

        final String lawyerName = data?['fullName'] ??
            data?['fullname'] ??
            data?['name'] ??
            data?['lawyerName'] ??
            currentUser?.displayName ??
            (currentUser?.email != null ? currentUser!.email!.split('@')[0] : "Lawyer");

        final profileImageUrl = data?['profileImageUrl'];

        return Scaffold(
          backgroundColor: lightGrey,
          appBar: AppBar(
            backgroundColor: navyBlue,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.white),
            title: const Text("Dashboard", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            actions: [_buildNotificationIcon(), const SizedBox(width: 10)],
          ),
          drawer: _buildDrawer(lawyerName, profileImageUrl),
          body: SingleChildScrollView(
            child: Column(
              children: [
                _buildHeader(lawyerName),
                Padding(
                  padding: const EdgeInsets.all(15.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle("Summary"),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _buildStatCard("Active Cases", Colors.blue, _getActiveCasesCount(), () => _navigateTo(const ActiveCasesScreen())),
                          const SizedBox(width: 15),
                          _buildStatCard("Case Requests", Colors.orange, _getCaseRequestsCountOnly(), () => _navigateTo(const CaseRequestsScreen())),
                        ],
                      ),
                      const SizedBox(height: 25),
                      _buildSectionTitle("Quick Actions"),
                      const SizedBox(height: 10),
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        mainAxisSpacing: 15,
                        crossAxisSpacing: 15,
                        children: [
                          _buildMenuTile(Icons.gavel, "Scheduled Hearings", Colors.indigo, () => _navigateTo(const HearingsListScreen())),
                          _buildMenuTile(Icons.group, "Coordination", Colors.deepPurple, () => _navigateTo(const CoordinationScreen())),
                          _buildMenuTile(Icons.folder_shared, "Documents", Colors.teal, () => _navigateTo(const DocumentsScreen())),
                          _buildMenuTile(Icons.forum, "Consultations", Colors.green, () => _navigateTo(const ConsultationScreen())),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: StreamBuilder<int>(
            stream: _getAllPendingRequestsCount(),
            builder: (context, pendingSnapshot) {
              final pendingCount = pendingSnapshot.data ?? 0;

              return BottomNavigationBar(
                currentIndex: _selectedIndex,
                selectedItemColor: goldColor,
                unselectedItemColor: Colors.grey,
                backgroundColor: navyBlue,
                type: BottomNavigationBarType.fixed,
                onTap: _onItemTapped,
                items: [
                  const BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
                  const BottomNavigationBarItem(icon: Icon(Icons.message), label: 'Messages'),
                  BottomNavigationBarItem(
                    icon: _buildBadgeIcon(Icons.hourglass_empty, pendingCount),
                    label: 'Pending',
                  ),
                  const BottomNavigationBarItem(icon: Icon(Icons.check_circle_outline), label: 'Accepted'),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildBadgeIcon(IconData iconData, int count) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(iconData),
        if (count > 0)
          Positioned(
            right: -6,
            top: -4,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(
                minWidth: 16,
                minHeight: 16,
              ),
              child: Center(
                child: Text(
                  '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) => Text(
    title,
    style: const TextStyle(color: navyBlue, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5),
  );

  Widget _buildNotificationIcon() => StreamBuilder<int>(
    stream: _getUnreadNotificationsCountOnly(),
    builder: (context, snapshot) {
      final count = snapshot.data ?? 0;
      return IconButton(
        onPressed: () => _navigateTo(const NotificationScreen()),
        icon: Stack(
          clipBehavior: Clip.none,
          children: [
            const Icon(Icons.notifications_none_rounded, color: Colors.white, size: 28),
            if (count > 0)
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  child: Center(child: Text('$count', style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold))),
                ),
              ),
          ],
        ),
      );
    },
  );

  Widget _buildHeader(String name) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: const BoxDecoration(
      color: navyBlue,
      borderRadius: BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Hello,", style: TextStyle(color: Colors.white70, fontSize: 16)),
        Row(
          children: [
            Flexible(child: Text(name, style: const TextStyle(color: goldColor, fontSize: 24, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 8),
            const Icon(Icons.verified, color: Colors.blue, size: 24)
          ],
        ),
      ],
    ),
  );

  Widget _buildStatCard(String label, Color color, Stream<int> countStream, VoidCallback onTap) => Expanded(
    child: Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              StreamBuilder<int>(
                stream: countStream,
                builder: (_, snapshot) => Text("${snapshot.data ?? 0}", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
              ),
              const SizedBox(height: 3),
              Icon(Icons.folder_open, size: 18, color: color.withOpacity(0.7)),
              const SizedBox(height: 3),
              Text(label, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w600, fontSize: 11)),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _buildMenuTile(IconData icon, String title, Color color, VoidCallback onTap) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(20),
    elevation: 2,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(backgroundColor: color.withOpacity(0.1), child: Icon(icon, color: color)),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: navyBlue), textAlign: TextAlign.center),
        ],
      ),
    ),
  );

  Widget _buildDrawer(String name, String? profileImageUrl) => Drawer(
    child: Container(
      color: navyBlue,
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(16, 30, 16, 20),
                      color: navyBlue,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GestureDetector(
                            onTap: _pickAndUploadProfileImage,
                            child: Stack(
                              children: [
                                CircleAvatar(
                                  radius: 36,
                                  backgroundColor: Colors.white24,
                                  backgroundImage: (profileImageUrl != null && profileImageUrl.isNotEmpty) ? NetworkImage(profileImageUrl) : null,
                                  child: (profileImageUrl == null || profileImageUrl.isEmpty) ? const Icon(Icons.person, color: Colors.white, size: 36) : null,
                                ),
                                if (_isUploadingImage)
                                  const Positioned.fill(child: CircularProgressIndicator(color: Colors.white))
                                else
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(color: goldColor, shape: BoxShape.circle),
                                      child: const Icon(Icons.camera_alt, color: navyBlue, size: 14),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(name, style: const TextStyle(fontWeight: FontWeight.bold, color: goldColor, fontSize: 18)),
                          const SizedBox(height: 4),
                          Text(currentUser?.email ?? "", style: const TextStyle(color: Colors.white70, fontSize: 13)),
                        ],
                      ),
                    ),
                    const Divider(color: Colors.white24, height: 1),
                    _buildDrawerItem(Icons.dashboard, "Dashboard", onTap: () => Navigator.pop(context)),
                    _buildDrawerItem(Icons.notifications, "Notifications", onTap: () => _navigateTo(const NotificationScreen())),
                    _buildDrawerItem(Icons.assignment_ind, "Case Requests", onTap: () => _navigateTo(const CaseRequestsScreen())),
                    _buildDrawerItem(Icons.folder_open, "Active Cases", onTap: () => _navigateTo(const ActiveCasesScreen())),
                    _buildDrawerItem(Icons.gavel, "Scheduled Hearings", onTap: () => _navigateTo(const HearingsListScreen())),
                  ],
                ),
              ),
            ),
            const Divider(color: Colors.white24, height: 1),
            _buildDrawerItem(Icons.logout, "Logout", isLogout: true, onTap: () async {
              await FirebaseAuth.instance.signOut();
              if (mounted) {
                Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginSelectionScreen()), (_) => false);
              }
            }),
            const SizedBox(height: 10),
          ],
        ),
      ),
    ),
  );

  Widget _buildDrawerItem(IconData icon, String title, {bool isLogout = false, required VoidCallback onTap}) => ListTile(
    leading: Icon(icon, color: isLogout ? Colors.redAccent : goldColor),
    title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500)),
    onTap: onTap,
  );
}