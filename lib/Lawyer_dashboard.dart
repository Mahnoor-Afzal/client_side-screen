import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// Is file ka naam check karein ke aapne project mein yahi rakha hai na?
import 'case_request_screen.dart';

class LawyerDashboard extends StatefulWidget {
  const LawyerDashboard({super.key});

  @override
  State<LawyerDashboard> createState() => _LawyerDashboardState();
}

class _LawyerDashboardState extends State<LawyerDashboard> {
  final User? user = FirebaseAuth.instance.currentUser;

  // App Theme Colors
  final Color navyBlue = const Color(0xFF101D3D);
  final Color goldColor = const Color(0xFFC5A358);
  final Color lightGrey = const Color(0xFFF5F5F5);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightGrey,

      appBar: AppBar(
        backgroundColor: navyBlue,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          "Lawyer Dashboard",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.notifications, color: Colors.white),
          ),
        ],
      ),

      drawer: Drawer(
        child: Container(
          color: navyBlue,
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              UserAccountsDrawerHeader(
                decoration: BoxDecoration(color: goldColor),
                currentAccountPicture: const CircleAvatar(
                  backgroundColor: Colors.white,
                  child: Icon(Icons.person, size: 50, color: Color(0xFF101D3D)),
                ),
                accountName: Text(
                  "Advocate ${user?.email?.split('@')[0] ?? 'User'}",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                accountEmail: Text(user?.email ?? "lawyer@example.com"),
              ),
              _buildDrawerItem(Icons.dashboard, "Dashboard", onTap: () => Navigator.pop(context)),
              _buildDrawerItem(Icons.check_circle, "Accepted Requests", onTap: () {}),
              _buildDrawerItem(Icons.pending_actions, "Pending Requests", onTap: () {}),
              const Divider(color: Colors.white24),
              _buildDrawerItem(Icons.logout, "Logout", isLogout: true, onTap: () async {
                await FirebaseAuth.instance.signOut();
                Navigator.pushReplacementNamed(context, '/login');
              }),
            ],
          ),
        ),
      ),

      body: SingleChildScrollView(
        child: Column(
          children: [
            // Welcome Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: navyBlue,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Hello,", style: TextStyle(color: Colors.white70, fontSize: 16)),
                  Text(
                    "Advocate ${user?.email?.split('@')[0] ?? 'Lawyer'}",
                    style: TextStyle(color: goldColor, fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(15.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 3. Dynamic Stats Section from Firestore
                  Row(
                    children: [
                      _buildDynamicStatCard("Active", "accepted", Colors.blue),
                      const SizedBox(width: 15),
                      _buildDynamicStatCard("Pending", "pending", Colors.orange),
                    ],
                  ),
                  const SizedBox(height: 25),

                  const Text("Quick Management",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF101D3D))),
                  const SizedBox(height: 15),

                  // 4. Functional Grid
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    mainAxisSpacing: 15,
                    crossAxisSpacing: 15,
                    children: [
                      // CASE REQUESTS BUTTON (Ab ye click hoga)
                      _buildMenuTile(
                        icon: Icons.assignment_ind,
                        title: "Case Requests",
                        color: Colors.indigo,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const CaseRequestsScreen()),
                          );
                        },
                      ),
                      _buildMenuTile(icon: Icons.folder_shared, title: "Documents", color: Colors.teal, onTap: () {}),
                      _buildMenuTile(icon: Icons.gavel, title: "Hearings", color: Colors.amber[900]!, onTap: () {}),
                      _buildMenuTile(icon: Icons.forum, title: "Consultations", color: Colors.green, onTap: () {}),
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

  // --- HELPER WIDGETS ---

  // Dashboard Tiles ko Clickable banane ke liye InkWell add kiya gaya hai
  Widget _buildMenuTile({required IconData icon, required String title, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.1),
              child: Icon(icon, color: color),
            ),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF101D3D))),
          ],
        ),
      ),
    );
  }

  // Real-time Firestore Count fetch karne ke liye widget
  Widget _buildDynamicStatCard(String label, String status, Color color) {
    return Expanded(
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('Case request')
            .where('lawyerid', isEqualTo: user?.uid)
            .where('status', isEqualTo: status)
            .snapshots(),
        builder: (context, snapshot) {
          String count = snapshot.hasData ? snapshot.data!.docs.length.toString() : "...";
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
            ),
            child: Column(
              children: [
                Text(count, style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: color)),
                const SizedBox(height: 5),
                Text("$label Cases", style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w500)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDrawerItem(IconData icon, String title, {bool isLogout = false, required VoidCallback onTap}) {
    return ListTile(
      leading: Icon(icon, color: isLogout ? Colors.redAccent : goldColor),
      title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 16)),
      onTap: onTap,
    );
  }
}