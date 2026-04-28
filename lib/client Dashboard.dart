import 'package:flutter/material.dart';
import 'profile_screen.dart';

class DashboardScreen extends StatefulWidget {
  final String clientName;

  const DashboardScreen({super.key, this.clientName = "Mahnoor"});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    const Color navyBlue = Color(0xFF001F3F);
    const Color gold = Color(0xFFD4AF37);
    const Color pureWhite = Colors.white;

    return Scaffold(
      backgroundColor: pureWhite,
      appBar: AppBar(
        backgroundColor: navyBlue,
        elevation: 0,
        title: const Text(
          "Client Dashboard",
          style: TextStyle(color: gold, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: gold),
        actions: [
          // Top Notification Icon
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(
                  Icons.notifications_none_rounded,
                  color: gold,
                  size: 28,
                ),
                onPressed: () {},
              ),
              Positioned(
                right: 12,
                top: 12,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(minWidth: 8, minHeight: 8),
                ),
              ),
            ],
          ),
          // Profile Edit Button
          IconButton(
            icon: const Icon(Icons.edit_note, color: gold, size: 30),
            onPressed: () {},
          ),
          // Top Right Profile Picture
          const Padding(
            padding: EdgeInsets.only(right: 16.0),
            child: CircleAvatar(
              backgroundColor: gold,
              radius: 18,
              child: Icon(Icons.person, color: navyBlue, size: 20),
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
                currentAccountPicture: const CircleAvatar(
                  backgroundColor: gold,
                  child: Icon(Icons.person, size: 40, color: navyBlue),
                ),
                accountName: Text(
                  widget.clientName,
                  style: const TextStyle(
                    color: gold,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                accountEmail: const Text(
                  "client@legalassist.com",
                  style: TextStyle(color: Colors.white70),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    _drawerItem(Icons.message, "Messages", gold),
                    _drawerItem(
                      Icons.check_circle_outline,
                      "Accept Request",
                      gold,
                    ),
                    _drawerItem(Icons.pending_actions, "Pending Request", gold),
                    _drawerItem(
                      Icons.notifications_active,
                      "Notifications",
                      gold,
                    ),
                    _drawerItem(Icons.report_problem, "Complaints", gold),
                  ],
                ),
              ),
              const Divider(color: Colors.white24),
              _drawerItem(Icons.logout, "Logout", Colors.redAccent),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),


      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          if (index == 3) {
            // 3rd index 'Profile' ka hai
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ProfileScreen()),
            );
          } else {
            setState(() {
              _selectedIndex = index;
            });
          }
        },
        backgroundColor: navyBlue,
        selectedItemColor: gold,
        unselectedItemColor: Colors.white54,
        type: BottomNavigationBarType.fixed,
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.gavel_rounded), label: 'Cases'),
          BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_rounded), label: 'Messages'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),

      body: ScrollConfiguration(
        behavior: const ScrollBehavior().copyWith(scrollbars: false),
        child: SingleChildScrollView(
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(25),
                decoration: const BoxDecoration(
                  color: navyBlue,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(30),
                    bottomRight: Radius.circular(30),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Welcome back,",
                      style: TextStyle(color: pureWhite, fontSize: 16),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      widget.clientName,
                      style: const TextStyle(
                        color: gold,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(20.0),
                child: GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 15,
                  mainAxisSpacing: 15,
                  children: [
                    _dashboardCard(
                      "Create Case",
                      Icons.add_box_rounded,
                      navyBlue,
                    ),
                    _dashboardCard(
                      "Documents",
                      Icons.description_rounded,
                      navyBlue,
                    ),
                    _dashboardCard("My Cases", Icons.folder_shared, navyBlue),
                    _dashboardCard("My Lawyers", Icons.person_search, navyBlue),
                    _dashboardCard(
                      "Consultation",
                      Icons.handshake_outlined,
                      navyBlue,
                    ),
                    _dashboardCard(
                      "Hearing Dates",
                      Icons.event_available,
                      navyBlue,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _drawerItem(IconData icon, String title, Color color) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(
        title,
        style: const TextStyle(color: Colors.white, fontSize: 16),
      ),
      onTap: () {},
    );
  }

  Widget _dashboardCard(String title, IconData icon, Color bg) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.15),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
        border: Border.all(color: bg.withOpacity(0.05)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: bg.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 35, color: bg),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              color: bg,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
