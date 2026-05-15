import 'package:flutter/material.dart';
import 'firestore_service.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final FirestoreService firestoreService = FirestoreService();

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text("Admin Dashboard", style: TextStyle(color: Color(0xFFC7A15E))),
        backgroundColor: const Color(0xFF1E293B),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            onPressed: () => _showLogoutDialog(context),
          ),
        ],
      ),
      body: GridView.count(
        crossAxisCount: 2,
        padding: const EdgeInsets.all(20),
        crossAxisSpacing: 15,
        mainAxisSpacing: 15,
        children: [
          _buildCard(context, "Manage Users", Icons.people, Colors.blue, '/user_management'),
          
          // VERIFY LAWYERS WITH PENDING COUNT
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: firestoreService.getPendingLawyers(),
            builder: (context, snapshot) {
              int count = snapshot.hasData ? snapshot.data!.length : 0;
              return _buildCard(
                context, "Verify Lawyers", Icons.how_to_reg, const Color(0xFFC7A15E), '/verify_lawyers',
                badgeText: count > 0 ? "$count New" : null,
              );
            }
          ),

          _buildCard(context, "Verified Lawyers", Icons.verified, Colors.green, '/verified_lawyers'),
          _buildCard(context, "Monitor Cases", Icons.gavel_rounded, Colors.orange, '/monitor_cases'),
          
          // COMPLAINTS WITH PENDING COUNT
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: firestoreService.getComplaints(),
            builder: (context, snapshot) {
              int pendingCount = 0;
              if (snapshot.hasData) {
                pendingCount = snapshot.data!.where((c) => 
                  c['status']?.toString().toLowerCase() == 'pending' || 
                  c['status']?.toString().toLowerCase() == 'open').length;
              }
              return _buildCard(
                context, "Complaints", Icons.report_problem, Colors.redAccent, '/manage_complaints',
                badgeText: pendingCount > 0 ? "$pendingCount New" : null,
              );
            }
          ),
        ],
      ),
    );
  }

  Widget _buildCard(BuildContext context, String title, IconData icon, Color color, String route, {String? badgeText}) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, route),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.white10),
        ),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 40, color: color),
                  const SizedBox(height: 10),
                  Text(title, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            if (badgeText != null)
              Positioned(
                right: 12,
                top: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                  ),
                  child: Text(
                    badgeText,
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text("Logout", style: TextStyle(color: Color(0xFFC7A15E))),
        content: const Text("Do you want to logout?", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("No")),
          TextButton(
              onPressed: () => Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false),
              child: const Text("Logout", style: TextStyle(color: Colors.redAccent))
          ),
        ],
      ),
    );
  }
}
