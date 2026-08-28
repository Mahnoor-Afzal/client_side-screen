import 'package:flutter/material.dart';
import 'firestore_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserManagement extends StatefulWidget {
  const UserManagement({super.key});

  @override
  State<UserManagement> createState() => _UserManagementState();
}

class _UserManagementState extends State<UserManagement> {
  final FirestoreService _firestoreService = FirestoreService();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  final Color navyBackground = const Color(0xFF0F172A);
  final Color goldAccent = const Color(0xFFC7A15E);
  final Color cardNavy = const Color(0xFF1E293B);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
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

            // Sort users so newly registered appear at the top
            users.sort((a, b) {
              final aTime = a['createdAt'] ?? a['timestamp'] ?? a['registeredAt'];
              final bTime = b['createdAt'] ?? b['timestamp'] ?? b['registeredAt'];

              if (aTime == null && bTime == null) return 0;
              if (aTime == null) return 1;
              if (bTime == null) return -1;

              if (aTime is Timestamp && bTime is Timestamp) {
                return bTime.compareTo(aTime);
              }
              return 0;
            });

            int allCount = _filterUsers(users, "All").length;
            int lawyerCount = _filterUsers(users, "Lawyer").length;
            int clientCount = _filterUsers(users, "Client").length;
            int blockedCount = _filterUsers(users, "Blocked").length;

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(15.0),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: "Search by name or email...",
                      hintStyle: const TextStyle(color: Colors.white54),
                      prefixIcon: Icon(Icons.search, color: goldAccent),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.white54),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = "";
                          });
                        },
                      )
                          : null,
                      filled: true,
                      fillColor: cardNavy,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                TabBar(
                  isScrollable: true,
                  indicatorColor: goldAccent,
                  labelColor: goldAccent,
                  unselectedLabelColor: Colors.white60,
                  tabs: [
                    _buildTab("All Users", allCount),
                    _buildTab("Lawyers", lawyerCount),
                    _buildTab("Clients", clientCount),
                    _buildTab("Blocked", blockedCount),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _userList(context, users, "All"),
                      _userList(context, users, "Lawyer"),
                      _userList(context, users, "Client"),
                      _userList(context, users, "Blocked"),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Tab _buildTab(String label, int count) {
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          if (count > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: goldAccent.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: goldAccent.withOpacity(0.5), width: 0.5),
              ),
              child: Text(
                count.toString(),
                style: TextStyle(color: goldAccent, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          ]
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _filterUsers(List<Map<String, dynamic>> allUsers, String filter) {
    return allUsers.where((user) {
      bool matchesTab = true;
      final String status = user['status'].toString().toLowerCase();
      final bool isBlocked = status == "blocked" || status == "suspended" || user['isBlocked'] == true;

      if (filter == "Blocked") {
        matchesTab = isBlocked;
      } else if (filter != "All") {
        matchesTab = user['role']?.toString().toLowerCase() == filter.toLowerCase();
      }

      if (!matchesTab) return false;

      if (_searchQuery.isEmpty) return true;

      final String name = (user['name'] ?? user['fullName'] ?? '').toString().toLowerCase();
      final String email = (user['email'] ?? '').toString().toLowerCase();

      return name.contains(_searchQuery.toLowerCase()) ||
          email.contains(_searchQuery.toLowerCase());
    }).toList();
  }

  Widget _userList(BuildContext context, List<Map<String, dynamic>> allUsers, String filter) {
    final filteredUsers = _filterUsers(allUsers, filter);

    if (filteredUsers.isEmpty) {
      return Center(
        child: Text(
          _searchQuery.isEmpty
              ? "No ${filter == "All" ? "Users" : filter} found"
              : "No matching results found",
          style: const TextStyle(color: Colors.white54),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(15),
      itemCount: filteredUsers.length,
      itemBuilder: (context, index) {
        final user = filteredUsers[index];

        final String role = (user['role'] ?? 'Client').toString();
        final bool isVerified = user['isVerified'] == true;
        final String status = user['status'].toString().toLowerCase();
        final bool isBlocked = status == "blocked" || status == "suspended" || user['isBlocked'] == true;
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
                  onPressed: () => _showBlockUnblockDialog(context, user, role, isVerified, isBlocked),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showProfileDialog(BuildContext context, Map<String, dynamic> user) {
    final String role = (user['role'] ?? 'Client').toString();
    final String uid = user['id'].toString();

    if (role.toLowerCase() == 'lawyer') {
      showDialog(
        context: context,
        builder: (context) => FutureBuilder<List<DocumentSnapshot>>(
          future: Future.wait([
            FirebaseFirestore.instance.collection('lawyers').doc(uid).get(),
            FirebaseFirestore.instance.collection('verified_lawyers').doc(uid).get(),
          ]),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return AlertDialog(
                backgroundColor: cardNavy,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                content: const SizedBox(
                  height: 100,
                  child: Center(child: CircularProgressIndicator()),
                ),
              );
            }

            final lawyerDoc = snapshot.data?[0].data() as Map<String, dynamic>? ?? {};
            final verifiedDoc = snapshot.data?[1].data() as Map<String, dynamic>? ?? {};
            final lawyerData = {...lawyerDoc, ...verifiedDoc};

            final String name = (lawyerData['fullName'] ?? lawyerData['name'] ?? user['fullName'] ?? user['name'] ?? 'N/A').toString();
            final String email = (lawyerData['email'] ?? user['email'] ?? 'N/A').toString();
            final String phone = (lawyerData['phone'] ?? lawyerData['phoneNumber'] ?? user['phone'] ?? 'N/A').toString();
            final String licenseId = (lawyerData['licenseId'] ?? lawyerData['licenseNumber'] ?? 'N/A').toString();
            final String licenseType = (lawyerData['licenseType'] ?? 'N/A').toString();
            final String province = (lawyerData['province'] ?? lawyerData['area'] ?? lawyerData['barCouncil'] ?? 'N/A').toString();

            String specString = 'N/A';
            final rawSpec = lawyerData['specialization'] ?? lawyerData['description'];
            if (rawSpec is List && rawSpec.isNotEmpty) {
              specString = rawSpec.join(', ');
            } else if (rawSpec is String && rawSpec.isNotEmpty) {
              specString = rawSpec;
            }

            return AlertDialog(
              backgroundColor: cardNavy,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text("Full Profile", style: TextStyle(color: goldAccent)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _detailRow("Name:", name.isNotEmpty ? name : 'N/A'),
                  _detailRow("Email:", email.isNotEmpty ? email : 'N/A'),
                  _detailRow("Phone:", phone.isNotEmpty ? phone : 'N/A'),
                  _detailRow("License Number:", licenseId.isNotEmpty ? licenseId : 'N/A'),
                  _detailRow("License Type:", licenseType.isNotEmpty ? licenseType : 'N/A'),
                  _detailRow("Province:", province.isNotEmpty ? province : 'N/A'),
                  _detailRow("Specialization:", specString),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text("Close", style: TextStyle(color: goldAccent)),
                ),
              ],
            );
          },
        ),
      );
    } else {
      final String phone = (user['phone'] ?? user['phoneNumber'] ?? '').toString();
      final String idNumber = (user['idNumber'] ?? user['cnic'] ?? '').toString();
      final String location = (user['location'] ?? user['city'] ?? '').toString();
      final String status = user['status'].toString().toLowerCase();
      final bool isBlocked = user['isBlocked'] == true || status == 'blocked' || status == 'suspended';

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
              _detailRow("Phone:", phone.isNotEmpty ? phone : 'N/A'),
              _detailRow("CNIC / ID:", idNumber.isNotEmpty ? idNumber : 'N/A'),
              _detailRow("Location:", location.isNotEmpty ? location : 'N/A'),
              _detailRow("Role:", (user['role'] ?? 'N/A').toString()),
              _detailRow("Status:", isBlocked ? 'Blocked / Suspended' : 'Active'),
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
  }

  void _showBlockUnblockDialog(BuildContext context, Map<String, dynamic> user, String role, bool isVerified, bool isBlocked) {
    String action = isBlocked ? "Unblock" : "Block";
    TextEditingController reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardNavy,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("$action User?", style: TextStyle(color: isBlocked ? Colors.green : Colors.redAccent)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Are you sure you want to $action this user?",
              style: const TextStyle(color: Colors.white70),
            ),
            if (!isBlocked) ...[
              const SizedBox(height: 15),
              TextField(
                controller: reasonController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: "Enter block reason...",
                  hintStyle: TextStyle(color: Colors.white38, fontSize: 13),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.redAccent)),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isBlocked ? Colors.green : Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              String uid = user['id'].toString();
              String reasonText = reasonController.text.trim();

              if (isBlocked) {
                await FirebaseFirestore.instance.collection('users').doc(uid).set({
                  'isBlocked': false,
                  'status': 'Active',
                }, SetOptions(merge: true));

                if (role.toLowerCase() == 'lawyer') {
                  await FirebaseFirestore.instance.collection('lawyers').doc(uid).set({
                    'isBlocked': false,
                    'status': 'approved',
                    'verificationStatus': 'approved',
                    'isVerified': true,
                  }, SetOptions(merge: true));

                  await FirebaseFirestore.instance.collection('verified_lawyers').doc(uid).set({
                    'status': 'approved',
                    'verificationStatus': 'approved',
                    'isBlocked': false,
                  }, SetOptions(merge: true));
                }
              } else {
                String finalReason = reasonText.isEmpty ? 'Blocked by admin' : reasonText;

                await FirebaseFirestore.instance.collection('users').doc(uid).set({
                  'isBlocked': true,
                  'status': 'blocked',
                  'blockReason': finalReason,
                }, SetOptions(merge: true));

                if (role.toLowerCase() == 'lawyer') {
                  await FirebaseFirestore.instance.collection('lawyers').doc(uid).set({
                    'isBlocked': true,
                    'status': 'suspended',
                    'verificationStatus': 'suspended',
                    'isVerified': false,
                    'blockReason': finalReason,
                  }, SetOptions(merge: true));

                  await FirebaseFirestore.instance.collection('verified_lawyers').doc(uid).set({
                    'status': 'suspended',
                    'verificationStatus': 'suspended',
                    'isBlocked': true,
                    'blockReason': finalReason,
                  }, SetOptions(merge: true));
                }
              }

              if (context.mounted) Navigator.pop(context);
            },
            child: Text("Yes, $action", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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