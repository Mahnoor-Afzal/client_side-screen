import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'main.dart';
import 'client_login_screen.dart';
import 'client_profile_screen.dart';
import 'client_create_case_screen.dart';
import 'client_my_lawyers_screen.dart';
import 'client_my_cases_screen.dart';
import 'client_complaint_screen.dart';
import 'client_messages_screen.dart';
import 'client_notifications_screen.dart';
import 'client_lawyer_requests_screen.dart';
import 'client_documents_screen.dart';
import 'client_chatbot_screen.dart';
import 'client_group_chat_list_screen.dart';
import 'client_hearing_list_screen.dart';
import 'client_hearing_details_screen.dart';
import 'client_chat_screen.dart';

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
  String _messagesInitialCategory = 'All';

  StreamSubscription<QuerySnapshot>? _notificationSubscription;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
    _listenToNotifications();
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    super.dispose();
  }

  void _listenToNotifications() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _notificationSubscription = FirebaseFirestore.instance
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
      // 2. Local Notifications click initialization
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
      );
      
      await flutterLocalNotificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          if (response.payload != null) {
            try {
              Map<String, dynamic> data = jsonDecode(response.payload!);
              // Ensure all values are strings for RemoteMessage data
              Map<String, String> stringData = data.map((key, value) => MapEntry(key, value.toString()));
              _handleNotificationNavigation(RemoteMessage(data: stringData));
            } catch (e) {
              debugPrint("Error parsing notification payload: $e");
            }
          }
        },
      );

      // 3. Get Token and Update Firestore for Personal Notifications
        String? token = await messaging.getToken();
        final user = FirebaseAuth.instance.currentUser;

        if (token != null && user != null) {
          await _updateFcmToken(token);
        }

        // Listen for token refresh
        messaging.onTokenRefresh.listen((newToken) {
          if (user != null) {
            _updateFcmToken(newToken);
          }
        });

        // --- Topic Subscription ---
        if (_userRole == 'lawyer') {
          await messaging.subscribeToTopic('all_lawyers');
          debugPrint("Lawyer subscribed to all_lawyers topic");
        } else {
          await messaging.unsubscribeFromTopic('all_lawyers');
        }

        // 3. Handle Initial Message (App launched from terminated state)
        RemoteMessage? initialMessage = await messaging.getInitialMessage();
        if (initialMessage != null) {
          _handleNotificationNavigation(initialMessage);
        }

        // 4. Handle Notification clicks when app is in background but not terminated
        FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
          _handleNotificationNavigation(message);
        });

        // 5. Listen for Foreground Messages (Show real notification)
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          RemoteNotification? notification = message.notification;

          if (notification != null && mounted) {
            flutterLocalNotificationsPlugin.show(
              notification.hashCode,
              notification.title,
              notification.body,
              NotificationDetails(
                android: AndroidNotificationDetails(
                  channel.id,
                  channel.name,
                  channelDescription: channel.description,
                  icon: '@mipmap/ic_launcher', // Standard icon use karein
                  importance: Importance.max,
                  priority: Priority.high,
                  showWhen: true,
                ),
              ),
              payload: jsonEncode(message.data),
            );

            // SnackBar for visibility
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("${notification.title}"),
                backgroundColor: const Color(0xFF001F3F),
                behavior: SnackBarBehavior.floating,
                action: SnackBarAction(
                  label: "VIEW",
                  textColor: const Color(0xFFD4AF37),
                  onPressed: () => _handleNotificationNavigation(message),
                ),
              ),
            );
          }
        });
      }
    } catch (e) {
      debugPrint("Notification Setup Error: $e");
    }
  }

  void _handleNotificationNavigation(RemoteMessage message) {
    if (!mounted) return;

    final data = message.data;
    final String type = (data['type'] ?? '').toString().toLowerCase();

    debugPrint("Navigating for notification type: $type");

    if (type == 'chat_message') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            receiverName: data['groupName'] ?? data['senderName'] ?? "Chat",
            receiverId: data['senderId'] ?? "",
            requestId: data['requestId'],
            chatId: data['chatId'],
            collectionPath: data['collectionPath'] ?? 'chat',
          ),
        ),
      );
    } else if (type == 'request_received') {
      Navigator.push(context, MaterialPageRoute(builder: (context) => const LawyerRequestsScreen()));
    } else if (type == 'request_accepted') {
      Navigator.push(context, MaterialPageRoute(builder: (context) => const MyCasesScreen()));
    } else if (type.contains('hearing') || type.contains('case_update') || type.contains('manual')) {
      String? hearingId = data['hearingId'] ?? 
                         data['caseId'] ?? 
                         data['case_id'] ?? 
                         data['requestId'] ?? 
                         data['docId'];
      if (hearingId != null && hearingId.isNotEmpty) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => HearingDetailsScreen(
              hearingId: hearingId,
              hearingData: data,
            ),
          ),
        );
      } else {
        Navigator.push(context, MaterialPageRoute(builder: (context) => const HearingListScreen()));
      }
    } else if (type.contains('document') || type.contains('vakalatnama')) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DocumentsScreen(
            initialCategory: type.contains('vakalatnama') ? 'Vakalatnama' : 'All',
            initialTab: type == 'document_sent' ? 1 : 0,
            initialDocId: data['docId'],
          ),
        ),
      );
    } else if (type == 'case_completed') {
      // Direct notification se rating screen open karna
      Navigator.push(context, MaterialPageRoute(builder: (context) => const NotificationsScreen()));
    } else {
      // Default behavior
      Navigator.push(context, MaterialPageRoute(builder: (context) => const NotificationsScreen()));
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
      Map<String, dynamic>? data;
      String role = "client";

      if (doc.exists) {
        data = doc.data();
        role = data?['role'] ?? "client";
      } else {
        // Agar nahi mila toh 'verified_lawyers' check karein
        var lawyerDoc = await FirebaseFirestore.instance.collection('verified_lawyers').doc(user.uid).get();
        if (lawyerDoc.exists) {
          data = lawyerDoc.data();
          role = 'lawyer';
        }
      }

      if (data != null && mounted) {
        // Check if blocked
        bool isBlocked = data['isBlocked'] == true || data['status'] == 'Blocked' || data['status'] == 'blocked';
        
        if (isBlocked) {
          String reason = data['blockReason'] ?? "Your account has been suspended by the administrator.";
          _handleBlockedUser(reason);
          return;
        }

        setState(() {
          _userName = data?['name'] ?? data?['fullName'] ?? "User";
          _userRole = role;
          
          // Clean base64 prefix if exists
          String? pic = data?['profilePicture'] ?? data?['imageUrl'] ?? data?['photoUrl'];
          if (pic != null && pic.contains(',')) {
            pic = pic.split(',').last.trim();
          }
          _profilePictureBase64 = pic;
        });
      }
    } catch (e) {
      debugPrint("Error fetching user data: $e");
    }
  }

  void _handleBlockedUser(String reason) {
    if (!mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF151B29),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.block, color: Colors.redAccent),
            SizedBox(width: 10),
            Text("Account Blocked", style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Your account has been suspended by the admin.",
              style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 15),
            const Text("Reason:", style: TextStyle(color: Color(0xFFD4AF37), fontSize: 14)),
            const SizedBox(height: 5),
            Text(
              reason,
              style: const TextStyle(color: Colors.white70, fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: ElevatedButton(
              onPressed: () async {
                Navigator.of(ctx, rootNavigator: true).pop();
                await FirebaseAuth.instance.signOut();
                if (!mounted) return;
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (route) => false,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD4AF37),
                foregroundColor: const Color(0xFF001F3F),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
              child: const Text("OK", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _updateFcmToken(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      String collection = (_userRole == 'lawyer') ? 'verified_lawyers' : 'users';
      await FirebaseFirestore.instance
          .collection(collection)
          .doc(user.uid)
          .set({'fcmToken': token}, SetOptions(merge: true));
      debugPrint("FCM Token updated in $collection for $_userRole");
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
      backgroundColor: const Color(0xFFF8F9FA),
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
                      setState(() {
                        _messagesInitialCategory = 'All';
                        _selectedIndex = 2;
                      });
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
                    _drawerItem(Icons.groups_outlined, "Team Chat", gold, () {
                      Navigator.pop(context);
                      setState(() {
                        _messagesInitialCategory = 'Groups';
                        _selectedIndex = 2;
                      });
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
          setState(() {
            _selectedIndex = index;
            // Reset to 'All' when clicking Messages tab directly from bottom bar
            if (index == 2) {
              _messagesInitialCategory = 'All';
            }
          });
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
      case 2: return MessagesScreen(initialCategory: _messagesInitialCategory);
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
          
          if (_userRole != 'lawyer') _buildRatingReminder(),

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
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              spreadRadius: 1,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: bg.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 32, color: bg),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                color: bg.withValues(alpha: 0.8),
                fontWeight: FontWeight.w700,
                fontSize: 14,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRatingReminder() {
    const Color navyBlue = Color(0xFF001F3F);
    const Color gold = Color(0xFFD4AF37);
    final String? uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('suit_a_file_request')
          .snapshots(),
      builder: (context, suitSnap) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('consultation_request')
              .snapshots(),
          builder: (context, consultSnap) {
            List<QueryDocumentSnapshot> pending = [];
            
            // Filter locally to avoid index issues and handle both clientId/userId
            void filterDocs(QuerySnapshot? snap) {
              if (snap == null) return;
              for (var doc in snap.docs) {
                var data = doc.data() as Map<String, dynamic>;
                // Broad matching for Client identification
                bool isMine = data['clientId'] == uid || 
                             data['userId'] == uid || 
                             (data['senderType'] == 'client' && data['senderId'] == uid);
                             
                bool isClosed = data['status']?.toString().toLowerCase() == 'closed' || 
                               data['status']?.toString().toLowerCase() == 'completed';
                
                // Show if either isRated is false or missing
                bool notRated = data['isRated'] == false || data['isRated'] == null;
                
                if (isMine && isClosed && notRated) {
                  pending.add(doc);
                }
              }
            }

            filterDocs(suitSnap.data);
            filterDocs(consultSnap.data);

            if (pending.isEmpty) return const SizedBox.shrink();

            var caseData = pending.first.data() as Map<String, dynamic>;
            String lawyerName = caseData['lawyerName'] ?? "your lawyer";
            String requestId = pending.first.id;
            String collectionName = pending.first.reference.parent.id;

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [navyBlue, Color(0xFF003366)]),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: navyBlue.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.stars, color: gold, size: 28),
                      const SizedBox(width: 10),
                      const Text("Rate Your Experience", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Case with $lawyerName has been closed. Please share your feedback.",
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        _showRatingDialog(
                          context, 
                          caseData['lawyerId'], 
                          requestId, 
                          collectionName
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: gold,
                        foregroundColor: navyBlue,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text("RATE NOW", style: TextStyle(fontWeight: FontWeight.bold)),
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
      debugPrint("Error: $e");
    }
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
