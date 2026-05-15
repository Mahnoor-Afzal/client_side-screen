import 'package:flutter/material.dart';
import 'firestore_service.dart';

class ManageComplaints extends StatelessWidget {
  const ManageComplaints({super.key});

  final Color navyBackground = const Color(0xFF0F172A);
  final Color goldAccent = const Color(0xFFC7A15E);
  final Color cardNavy = const Color(0xFF1E293B);

  @override
  Widget build(BuildContext context) {
    final FirestoreService firestoreService = FirestoreService();

    return DefaultTabController(
      length: 3, // All, Pending, Resolved
      child: Scaffold(
        backgroundColor: navyBackground,
        appBar: AppBar(
          backgroundColor: cardNavy,
          elevation: 0,
          title: Text("Manage Complaints", style: TextStyle(color: goldAccent, fontWeight: FontWeight.bold)),
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: goldAccent),
            onPressed: () => Navigator.pop(context),
          ),
          bottom: TabBar(
            indicatorColor: goldAccent,
            labelColor: goldAccent,
            unselectedLabelColor: Colors.white54,
            tabs: const [
              Tab(text: "All"),
              Tab(text: "Pending"),
              Tab(text: "Resolved"),
            ],
          ),
        ),
        body: StreamBuilder<List<Map<String, dynamic>>>(
          stream: firestoreService.getComplaints(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text("Error: ${snapshot.error}", style: const TextStyle(color: Colors.white)));
            }
            final complaints = snapshot.data ?? [];

            return TabBarView(
              children: [
                _buildComplaintsList(context, firestoreService, complaints, "All"),
                _buildComplaintsList(context, firestoreService, complaints, "Pending"),
                _buildComplaintsList(context, firestoreService, complaints, "Resolved"),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildComplaintsList(BuildContext context, FirestoreService firestoreService, List<Map<String, dynamic>> allComplaints, String statusFilter) {
    final filteredComplaints = allComplaints.where((cmp) {
      if (statusFilter == "All") return true;
      String status = (cmp['status'] ?? 'pending').toString().toLowerCase().trim();
      if (statusFilter == "Pending") return status != "resolved" && status != "rejected";
      return status == statusFilter.toLowerCase();
    }).toList();

    if (filteredComplaints.isEmpty) {
      return Center(child: Text("No $statusFilter complaints found", style: const TextStyle(color: Colors.white54)));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(15),
      itemCount: filteredComplaints.length,
      itemBuilder: (context, index) {
        final cmp = filteredComplaints[index];
        
        // --- IMPROVED FLEXIBLE KEY CHECKING ---
        String reason = (cmp['reason'] ?? cmp['category'] ?? cmp['subject'] ?? cmp['title'] ?? 'Complaint').toString();
        String fromName = (cmp['fromName'] ?? cmp['userName'] ?? cmp['userEmail'] ?? cmp['clientName'] ?? 'Client').toString();
        String description = (cmp['description'] ?? cmp['details'] ?? cmp['message'] ?? cmp['text'] ?? '').toString();
        String currentStatus = (cmp['status'] ?? 'Pending').toString().toUpperCase();
        
        // Detecting Client UID for Notification
        String clientId = (cmp['userId'] ?? cmp['uid'] ?? cmp['fromId'] ?? cmp['clientId'] ?? '').toString();

        return Card(
          color: cardNavy,
          margin: const EdgeInsets.only(bottom: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          child: ExpansionTile(
            iconColor: goldAccent,
            collapsedIconColor: Colors.white,
            initiallyExpanded: true, 
            title: Text(reason, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            subtitle: Text("From: $fromName", style: const TextStyle(color: Colors.white54, fontSize: 12)),
            children: [
              Padding(
                padding: const EdgeInsets.all(15.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (description.isNotEmpty) ...[
                      const Text("Description:", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 5),
                      Text(description, style: const TextStyle(color: Colors.white60, height: 1.4)),
                      const SizedBox(height: 10),
                    ],
                    
                    // --- AUTOMATICALLY SHOW ALL OTHER FIELDS FROM FIRESTORE ---
                    ...cmp.entries.where((e) => !['id', 'status', 'reason', 'category', 'fromName', 'userName', 'userEmail', 'clientName', 'description', 'details', 'message', 'text', 'userId', 'uid', 'fromId', 'clientId', 'createdAt', 'timestamp'].contains(e.key)).map((e) => Padding(
                      padding: const EdgeInsets.only(bottom: 5.0),
                      child: Text("${e.key}: ${e.value}", style: const TextStyle(color: Colors.white38, fontSize: 11)),
                    )).toList(),

                    const Divider(color: Colors.white10, height: 30),

                    // --- CURRENT STATUS BADGE ---
                    Center(
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 15),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: currentStatus == 'RESOLVED' ? Colors.green.withAlpha(40) : Colors.orange.withAlpha(40),
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(color: currentStatus == 'RESOLVED' ? Colors.green : Colors.orange, width: 0.5),
                        ),
                        child: Text("CURRENT STATUS: $currentStatus", style: TextStyle(color: currentStatus == 'RESOLVED' ? Colors.green : Colors.orange, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ),

                    // --- 3 ACTION BUTTONS (Always Visible) ---
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // 1. REJECT BUTTON
                        _actionButton("Reject", Colors.redAccent, () async {
                          if (clientId.isEmpty) { _showSnackBar(context, "Client ID missing!"); return; }
                          await firestoreService.updateComplaintStatus(
                            complaintId: cmp['id'].toString(), 
                            status: "Rejected", 
                            clientId: clientId, 
                            title: "Complaint Rejected",
                            message: "Your complaint regarding $reason has been rejected.",
                            type: "complaint_rejected"
                          );
                          _showSnackBar(context, "Rejected. Client Notified.");
                        }),

                        // 2. RESOLVED BUTTON
                        _actionButton("Resolved", Colors.green, () async {
                          if (clientId.isEmpty) { _showSnackBar(context, "Client ID missing!"); return; }
                          await firestoreService.updateComplaintStatus(
                            complaintId: cmp['id'].toString(), 
                            status: "Resolved", 
                            clientId: clientId, 
                            title: "Complaint Resolved",
                            message: "complaints has been resolved", // Exact text requested
                            type: "complaint_resolved"
                          );
                          _showSnackBar(context, "Marked as Resolved. Client Notified.");
                        }),
                        
                        // 3. PENDING BUTTON
                        _actionButton("Pending", Colors.orange, () async {
                           if (clientId.isEmpty) { _showSnackBar(context, "Client ID missing!"); return; }
                          await firestoreService.updateComplaintStatus(
                            complaintId: cmp['id'].toString(), 
                            status: "Pending", 
                            clientId: clientId, 
                            title: "Complaint Update",
                            message: "your request is on pending", // Exact text requested
                            type: "complaint_pending"
                          );
                          _showSnackBar(context, "Marked as Pending. Client Notified.");
                        }),
                      ],
                    ),
                  ],
                ),
              )
            ],
          ),
        );
      },
    );
  }

  void _showSnackBar(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));
  }

  Widget _actionButton(String label, Color color, VoidCallback onTap) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: color, 
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onPressed: onTap,
      child: Text(label, style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
    );
  }
}
