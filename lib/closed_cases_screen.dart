import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ClosedCasesScreen extends StatefulWidget {
  const ClosedCasesScreen({super.key});

  @override
  State<ClosedCasesScreen> createState() => _ClosedCasesScreenState();
}

class _ClosedCasesScreenState extends State<ClosedCasesScreen> {
  final Color navyBlue = const Color(0xFF101D3D);
  final Color goldColor = const Color(0xFFC5A358);
  String searchQuery = "";
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String? uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text("Closed Cases", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: navyBlue,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: uid == null
          ? const Center(child: Text("Please login to see your cases"))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      setState(() {
                        searchQuery = value.toLowerCase();
                      });
                    },
                    decoration: InputDecoration(
                      hintText: "Search by client name or case type...",
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    ),
                  ),
                ),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('suit_a_file_request').snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      List<DocumentSnapshot> closedCases = [];
                      if (snapshot.hasData) {
                        closedCases = snapshot.data!.docs.where((doc) {
                          var data = doc.data() as Map<String, dynamic>;
                          String status = (data['status'] ?? "").toString().toLowerCase().trim();
                          String leadId = (data['lawyerid'] ?? data['lawyerId'] ?? "").toString().trim();

                          List assigned = data['assignedLawyers'] ?? [];
                          bool isAssigned = (leadId == uid.trim()) || assigned.contains(uid.trim());

                          if (status != 'closed' || !isAssigned) return false;

                          // Search Filter
                          String name = (data['clientName'] ?? data['fullName'] ?? "").toString().toLowerCase();
                          String type = (data['caseType'] ?? data['title'] ?? "").toString().toLowerCase();
                          
                          return name.contains(searchQuery) || type.contains(searchQuery);
                        }).toList();
                      }

                      if (closedCases.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.archive_outlined, size: 70, color: Colors.grey[300]),
                              const SizedBox(height: 10),
                              Text(
                                searchQuery.isEmpty ? "No closed cases found" : "No results for \"$searchQuery\"",
                                style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: closedCases.length,
                        itemBuilder: (context, index) {
                          var doc = closedCases[index];
                          var data = doc.data() as Map<String, dynamic>;
                          String name = data['clientName'] ?? data['fullName'] ?? "Client";
                          String type = data['caseType'] ?? data['title'] ?? "Matter";
                          double rating = (data['rating'] ?? 0.0).toDouble();
                          String review = data['review'] ?? "";

                          return Card(
                            elevation: 3,
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(15),
                              leading: CircleAvatar(
                                backgroundColor: navyBlue.withValues(alpha: 0.1),
                                child: const Icon(Icons.check_circle, color: Colors.green),
                              ),
                              title: Text(name, style: TextStyle(fontWeight: FontWeight.bold, color: navyBlue)),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(type, style: const TextStyle(fontSize: 13, color: Colors.black54)),
                                  if (rating > 0) ...[
                                    const SizedBox(height: 5),
                                    Row(
                                      children: [
                                        const Icon(Icons.star, color: Colors.amber, size: 16),
                                        const SizedBox(width: 4),
                                        Text("$rating", style: const TextStyle(fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ],
                                  if (review.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text("\"$review\"", style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                                  ],
                                ],
                              ),
                              trailing: const Icon(Icons.chevron_right),
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
  }
}
