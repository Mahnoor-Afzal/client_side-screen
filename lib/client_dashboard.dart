import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'login_screen.dart';
import 'profile_screen.dart';
import 'create_case_screen.dart';
import 'my_lawyers_screen.dart';
import 'my_cases_screen.dart';
import 'complaint_screen.dart';
import 'messages_screen.dart';
import 'notifications_screen.dart';
import 'lawyer_requests_screen.dart';
import 'documents_screen.dart';
import 'chatbot_screen.dart';
import 'hearing_list_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  String _userName = "User";
  String _userEmail = "...";
  String _userRole = "client";
  String? _profilePictureBase64;
  bool _isLoading = true;
  int _unreadNotifications = 0;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
    _listenToNotifications();
  }

  void _listenToNotifications() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      FirebaseFirestore.instance
          .collection('notifications')
          .where('userId', isEqualTo: user.uid)
          .where('isRead', isEqualTo: false)
          .snapshots()
          .listen((snapshot) {
        if (mounted) {
          setState(() {
            _unreadNotifications = snapshot.docs.length;
          });
        }
      });
    }
  }

  Future<void> _loadDashboardData() async {
    try {
      // 1. Pehle user data fetch karein taake role pata chale (Lawyer ya Client)
      await _fetchUserData().timeout(const Duration(seconds: 5));
      
      // 2. Phir notifications setup karein (ab role sahi milega)
      await _setupPushNotifications();
    } catch (e) {
      debugPrint("Data loading error: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _setupPushNotifications() async {
    try {
      FirebaseMessaging messaging = FirebaseMessaging.instance;

      // 1. Request Permissions
      NotificationSettings settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        // 2. Get Token and Update Firestore for Personal Notifications
        String? token = await messaging.getToken();
        final user = FirebaseAuth.instance.currentUser;

        if (token != null && user != null) {
          // Update token in the correct collection based on role
          String collection = (_userRole == 'lawyer') ? 'verified_lawyers' : 'users';
          await FirebaseFirestore.instance
              .collection(collection)
              .doc(user.uid)
              .set({'fcmToken': token}, SetOptions(merge: true));
          
          debugPrint("FCM Token updated in $collection for $_userRole");
        }

        // --- Topic Subscription ---
        if (_userRole == 'lawyer') {
          await messaging.subscribeToTopic('all_lawyers');
          debugPrint("Lawyer subscribed to all_lawyers topic");
        } else {
          await messaging.unsubscribeFromTopic('all_lawyers');
        }

        // 3. Listen for Foreground Messages
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("${message.notification?.title}: ${message.notification?.body}"),
                backgroundColor: const Color(0xFF001F3F),
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 4),
              ),
            );
          }
        });
      }
    } catch (e) {
      debugPrint("Notification Setup Error: $e");
    }
  }

  Future<void> _fetchUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (mounted) {
      setState(() {
        _userEmail = user.email ?? "";
      });
    }

    try {
      // Pehle 'users' collection check karein
      var doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists && mounted) {
        setState(() {
          _userName = doc.data()?['name'] ?? doc.data()?['fullName'] ?? "User";
          _userRole = doc.data()?['role'] ?? "client";
          _profilePictureBase64 = doc.data()?['profilePicture'];
        });
        return;
      }

      // Agar nahi mila toh 'verified_lawyers' check karein
      var lawyerDoc = await FirebaseFirestore.instance.collection('verified_lawyers').doc(user.uid).get();
      if (lawyerDoc.exists && mounted) {
        setState(() {
          _userName = lawyerDoc.data()?['fullName'] ?? lawyerDoc.data()?['name'] ?? "Lawyer";
          _userRole = 'lawyer';
          _profilePictureBase64 = lawyerDoc.data()?['profilePicture'];
        });
      }
    } catch (e) {
      debugPrint("Error fetching user data: $e");
    }
  }

  void _navigateToProfile() {
    Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const ProfileScreen())
    ).then((_) => _fetchUserData());
  }

  @override
  Widget build(BuildContext context) {
    const Color navyBlue = Color(0xFF001F3F);
    const Color gold = Color(0xFFD4AF37);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: navyBlue,
        elevation: 0,
        title: const Text("Dashboard", style: TextStyle(color: gold, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: gold),
        actions: [
          GestureDetector(
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const NotificationsScreen()));
            },
            child: Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications_active_outlined, color: gold, size: 28),
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const NotificationsScreen()));
                  },
                ),
                if (_unreadNotifications > 0)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        '$_unreadNotifications',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          GestureDetector(
            onTap: _navigateToProfile,
            child: Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: CircleAvatar(
                backgroundColor: gold,
                radius: 18,
                backgroundImage: (_profilePictureBase64 != null && _profilePictureBase64!.isNotEmpty)
                    ? MemoryImage(base64Decode(_profilePictureBase64!))
                    : null,
                child: (_profilePictureBase64 == null || _profilePictureBase64!.isEmpty)
                    ? const Icon(Icons.person, color: navyBlue, size: 20)
                    : null,
              ),
            ),
          ),
        ],
      ),
      drawer: Drawer(
        child: Container(
          color: navyBlue,
          child: Column(
            children: [
              UserAccountsDrawerHeader(
                decoration: const BoxDecoration(color: Color(0xFF00152B)),
                currentAccountPicture: GestureDetector(
                  onTap: _navigateToProfile,
                  child: CircleAvatar(
                    backgroundColor: gold,
                    backgroundImage: (_profilePictureBase64 != null && _profilePictureBase64!.isNotEmpty)
                        ? MemoryImage(base64Decode(_profilePictureBase64!))
                        : null,
                    child: (_profilePictureBase64 == null || _profilePictureBase64!.isEmpty)
                        ? const Icon(Icons.person, size: 40, color: navyBlue)
                        : null,
                  ),
                ),
                accountName: Text(_userName, style: const TextStyle(color: gold, fontWeight: FontWeight.bold)),
                accountEmail: Text(_userEmail, style: const TextStyle(color: Colors.white70)),
              ),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    _drawerItem(Icons.message, "Messages", gold, () {
                      Navigator.pop(context);
                      setState(() => _selectedIndex = 2);
                    }),
                    if (_userRole == 'lawyer')
                      _drawerItem(Icons.assignment_ind, "Case Requests", gold, () {
                        Navigator.pop(context);
                        Navigator.push(context, MaterialPageRoute(builder: (context) => const LawyerRequestsScreen()));
                      }),
                    _drawerItem(Icons.pending_actions, "Pending Requests", gold, () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const MyCasesScreen(filterStatus: 'Pending')));
                    }),
                    _drawerItem(Icons.cancel_presentation_outlined, "Rejected Requests", gold, () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const MyCasesScreen(filterStatus: 'Rejected')));
                    }),
                    _drawerItem(Icons.notifications_none_rounded, "Notifications", gold, () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const NotificationsScreen()));
                    }),
                    _drawerItem(Icons.report_problem, "Complaints", gold, () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const ComplaintScreen()));
                    }),
                  ],
                ),
              ),
              const Divider(color: Colors.white24),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.redAccent),
                title: const Text("Logout", style: TextStyle(color: Colors.white)),
                onTap: _logout,
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() => _selectedIndex = index);
        },
        backgroundColor: navyBlue,
        selectedItemColor: gold,
        unselectedItemColor: Colors.white54,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.gavel_rounded), label: 'Cases'),
          BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_rounded), label: 'Messages'),
          BottomNavigationBarItem(icon: Icon(Icons.smart_toy_outlined), label: 'Chatbot'),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: navyBlue))
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0: return _buildDashboard();
      case 1: return const MyCasesScreen();
      case 2: return const MessagesScreen();
      case 3: return const ChatbotScreen();
      default: return _buildDashboard();
    }
  }

  Widget _buildDashboard() {
    const Color navyBlue = Color(0xFF001F3F);
    const Color gold = Color(0xFFD4AF37);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(25),
            decoration: const BoxDecoration(
              color: navyBlue,
              borderRadius: BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Welcome back,", style: TextStyle(color: Colors.white, fontSize: 16)),
                const SizedBox(height: 5),
                Text(_userName, style: const TextStyle(color: gold, fontSize: 26, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          
          if (_userRole == 'lawyer') _buildSignedVakalatnamas(),

          Padding(
            padding: const EdgeInsets.all(20.0),
            child: GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 15,
              mainAxisSpacing: 15,
              children: [
                if (_userRole == 'lawyer')
                  _dashboardCard("Case Requests", Icons.assignment_late_rounded, navyBlue, onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const LawyerRequestsScreen()));
                  }),
                _dashboardCard("Create Case", Icons.add_box_rounded, navyBlue, onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const CreateCaseScreen()));
                }),
                _dashboardCard("Documents", Icons.description_rounded, navyBlue, onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const DocumentsScreen()));
                }),
                _dashboardCard("My Cases", Icons.folder_shared, navyBlue, onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const MyCasesScreen(filterType: 'File a Suit')));
                }),
                if (_userRole != 'lawyer')
                  _dashboardCard("My Lawyers", Icons.person_search, navyBlue, onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const MyLawyersScreen()));
                  }),
                _dashboardCard("Consultation", Icons.handshake_outlined, navyBlue, onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const MyCasesScreen(filterType: 'Consultation')));
                }),
                _dashboardCard("Hearing Detail", Icons.gavel_rounded, navyBlue, onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const HearingListScreen()),
                  );
                }),
                if (_userRole == 'lawyer')
                  _dashboardCard("My Lawyers", Icons.person_search, navyBlue, onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const MyLawyersScreen()));
                  }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  Widget _drawerItem(IconData icon, String title, Color color, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 16)),
      onTap: onTap,
    );
  }

  Widget _dashboardCard(String title, IconData icon, Color bg, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.grey.withValues(alpha: 0.15), blurRadius: 12, spreadRadius: 2)],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: bg.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: Icon(icon, size: 35, color: bg),
            ),
            const SizedBox(height: 12),
            Text(title, style: TextStyle(color: bg, fontWeight: FontWeight.w600, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _buildSignedVakalatnamas() {
    const Color navyBlue = Color(0xFF001F3F);
    const Color gold = Color(0xFFD4AF37);
    final String? uid = FirebaseAuth.instance.currentUser?.uid;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 20.0, top: 20.0, bottom: 10.0),
          child: Text(
            "Signed Vakalatnamas",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: navyBlue),
          ),
        ),
        SizedBox(
          height: 110,
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('documents')
                .where('lawyerId', isEqualTo: uid)
                .where('category', isEqualTo: 'Vakalatnama')
                .where('status', isEqualTo: 'Signed')
                .orderBy('signedAt', descending: true)
                .limit(5)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: gold));
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Text("No recently signed Vakalatnamas", style: TextStyle(color: Colors.grey, fontSize: 13)),
                );
              }

              return ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 15),
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  var doc = snapshot.data!.docs[index];
                  var data = doc.data() as Map<String, dynamic>;
                  String clientName = data['clientName'] ?? "Client";

                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const DocumentsScreen(initialCategory: 'Vakalatnama'),
                        ),
                      );
                    },
                    child: Container(
                      width: 140,
                      margin: const EdgeInsets.only(right: 12, bottom: 5, top: 5),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: gold.withValues(alpha: 0.3)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 5,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.history_edu, color: gold, size: 28),
                          const SizedBox(height: 5),
                          Text(
                            clientName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: navyBlue),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const Text("Signed", style: TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}