import 'package:flutter/material.dart';
import 'firestore_service.dart';

class UserManagement extends StatelessWidget {
  UserManagement({super.key});

  final FirestoreService _firestoreService = FirestoreService();

  // Colors matching the design
  final Color navyBackground = const Color(0xFF0F172A);
  final Color goldAccent = const Color(0xFFC7A15E);
  final Color cardNavy = const Color(0xFF1E293B);

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4, // 4 Tabs: All, Lawyers, Clients, Blocked
      child: Scaffold(
        backgroundColor: navyBackground,
        appBar: AppBar(
          backgroundColor: cardNavy,
          elevation: 0,
          title: Text("User Management", style: TextStyle(color: goldAccent, fontWeight: FontWeight.bold)),
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: goldAccent),
            onPressed: () => Navigator.pop(context),
          ),
          bottom: TabBar(
            isScrollable: true,
            indicatorColor: goldAccent,
            labelColor: goldAccent,
            unselectedLabelColor: Colors.white60,
            tabs: const [
              Tab(text: "All Users"),
              Tab(text: "Lawyers"),
              Tab(text: "Clients"),
              Tab(text: "Blocked"),
            ],
          ),
        ),
        body: StreamBuilder<List<Map<String, dynamic>>>(
          stream: _firestoreService.getUsers(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text("Error: ${snapshot.error}", style: const TextStyle(color: Colors.white)));
            }
            final users = snapshot.data ?? [];

            return TabBarView(
              children: [
                _userList(context, users, "All"),
                _userList(context, users, "Lawyer"),
                _userList(context, users, "Client"),
                _userList(context, users, "Blocked"),
              ],
            );
          },
        ),
      ),
    );
  }

  // User List Widget
  Widget _userList(BuildContext context, List<Map<String, dynamic>> allUsers, String filter) {
    final filteredUsers = allUsers.where((user) {
      if (filter == "All") return true;
      if (filter == "Blocked") return user['status'].toString() == "Blocked";
      return user['role']?.toString().toLowerCase() == filter.toLowerCase();
    }).toList();

    if (filteredUsers.isEmpty) {
      return Center(
        child: Text(
          "No ${filter == "All" ? "Users" : filter} found",
          style: const TextStyle(color: Colors.white54),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(15),
      itemCount: filteredUsers.length,
      itemBuilder: (context, index) {
        final user = filteredUsers[index];
        
        // Defensive coding to avoid TypeError: type 'int' is not a subtype of type 'String'
        final String role = (user['role'] ?? 'Client').toString();
        final bool isVerified = user['isVerified'] == true;
        final bool isBlocked = user['status'].toString() == "Blocked";
        final String name = (user['name'] ?? user['fullName'] ?? 'No Name').toString();
        final String email = (user['email'] ?? 'No Email').toString();

        return Card(
          color: cardNavy,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          child: ListTile(
            contentPadding: const EdgeInsets.all(10),
            leading: CircleAvatar(
              backgroundColor: goldAccent.withAlpha(50),
              child: Icon(
                role.toLowerCase() == 'lawyer' ? Icons.gavel : Icons.person,
                color: goldAccent,
              ),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (role.toLowerCase() == 'lawyer') ...[
                  const SizedBox(width: 5),
                  Icon(
                    isVerified ? Icons.verified : Icons.pending,
                    color: isVerified ? Colors.blue : Colors.orange,
                    size: 16,
                  ),
                ]
              ],
            ),
            subtitle: Text(
              "$email\nRole: $role",
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.visibility_outlined, color: goldAccent, size: 20),
                  onPressed: () => _showProfileDialog(context, user),
                ),
                IconButton(
                  icon: Icon(
                    isBlocked ? Icons.check_circle_outline : Icons.block,
                    color: isBlocked ? Colors.green : Colors.redAccent,
                    size: 20,
                  ),
                  onPressed: () {
                    String newStatus = isBlocked ? "Active" : "Blocked";
                    _firestoreService.updateUserStatus(user['id'], role, newStatus, isVerified);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.white38, size: 20),
                  onPressed: () {
                    _firestoreService.deleteUser(user['id'], role, isVerified);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Profile View Dialog
  void _showProfileDialog(BuildContext context, Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardNavy,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Full Profile", style: TextStyle(color: goldAccent)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _detailRow("Name:", (user['name'] ?? user['fullName'] ?? 'N/A').toString()),
            _detailRow("Email:", (user['email'] ?? 'N/A').toString()),
            _detailRow("Role:", (user['role'] ?? 'N/A').toString()),
            _detailRow("Status:", (user['status'] ?? 'N/A').toString()),
            if (user['role']?.toString().toLowerCase() == 'lawyer') ...[
              const Divider(color: Colors.white10),
              _detailRow("Specialization:", (user['specialization'] ?? 'N/A').toString()),
              _detailRow("Experience:", (user['experience'] ?? user['exp'] ?? 'N/A').toString()),
              _detailRow("Verified:", (user['isVerified'] == true) ? "Yes" : "No"),
            ]
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Close", style: TextStyle(color: goldAccent)),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(text: "$label ", style: const TextStyle(color: Colors.white54, fontWeight: FontWeight.bold)),
            TextSpan(text: value, style: const TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }
}
