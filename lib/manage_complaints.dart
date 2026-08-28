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

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: firestoreService.getComplaints(),
      builder: (context, snapshot) {
        final complaints = snapshot.data ?? [];

        int allCount = complaints.length;
        int pendingCount = complaints.where((cmp) {
          String status = (cmp['status'] ?? 'pending').toString().toLowerCase().trim();
          return status != "resolved" && status != "rejected";
        }).length;

        int resolvedCount = complaints.where((cmp) {
          String status = (cmp['status'] ?? 'pending').toString().toLowerCase().trim();
          bool hasStrike = cmp['hasStrike'] == true || cmp['actionTaken'] == 'Struck';
          return status == "resolved" && !hasStrike;
        }).length;

        int struckCount = complaints.where((cmp) {
          bool hasStrike = cmp['hasStrike'] == true || cmp['actionTaken'] == 'Struck';
          return hasStrike;
        }).length;

        return DefaultTabController(
          length: 4,
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
                isScrollable: true,
                indicatorColor: goldAccent,
                labelColor: goldAccent,
                unselectedLabelColor: Colors.white54,
                tabs: [
                  _buildTab("All", allCount),
                  _buildTab("Pending", pendingCount),
                  _buildTab("Resolved", resolvedCount),
                  _buildTab("Struck", struckCount),
                ],
              ),
            ),
            body: snapshot.connectionState == ConnectionState.waiting
                ? const Center(child: CircularProgressIndicator())
                : snapshot.hasError
                ? Center(child: Text("Error: ${snapshot.error}", style: const TextStyle(color: Colors.white)))
                : TabBarView(
              children: [
                _buildComplaintsList(context, firestoreService, complaints, "All"),
                _buildComplaintsList(context, firestoreService, complaints, "Pending"),
                _buildComplaintsList(context, firestoreService, complaints, "Resolved"),
                _buildComplaintsList(context, firestoreService, complaints, "Struck"),
              ],
            ),
          ),
        );
      },
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

  Widget _buildComplaintsList(BuildContext context, FirestoreService firestoreService, List<Map<String, dynamic>> allComplaints, String statusFilter) {
    final filteredComplaints = allComplaints.where((cmp) {
      if (statusFilter == "All") return true;

      String status = (cmp['status'] ?? 'pending').toString().toLowerCase().trim();
      bool hasStrike = cmp['hasStrike'] == true || cmp['actionTaken'] == 'Struck';

      if (statusFilter == "Pending") {
        return status != "resolved" && status != "rejected";
      }
      if (statusFilter == "Resolved") {
        return status == "resolved" && !hasStrike;
      }
      if (statusFilter == "Struck") {
        return hasStrike;
      }

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

        String reason = (cmp['reason'] ?? cmp['category'] ?? cmp['subject'] ?? cmp['title'] ?? 'Complaint').toString();
        String fromName = (cmp['fromName'] ?? cmp['userName'] ?? cmp['userEmail'] ?? cmp['clientName'] ?? 'Client').toString();
        String lawyerName = (cmp['lawyerName'] ?? cmp['targetLawyerName'] ?? 'N/A').toString();

        bool hasStrike = cmp['hasStrike'] == true || cmp['actionTaken'] == 'Struck';
        String currentStatus = hasStrike ? 'STRIKE_ISSUED' : (cmp['status'] ?? 'Pending').toString().toUpperCase();

        String dateStr = _formatDate(cmp['createdAt'] ?? cmp['timestamp']);

        return Card(
          color: cardNavy,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        reason,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildStatusBadge(currentStatus),
                  ],
                ),
                const SizedBox(height: 10),

                Row(
                  children: [
                    const Icon(Icons.person, color: Colors.white38, size: 14),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        "By: $fromName",
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (lawyerName != 'N/A') ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.gavel, color: Colors.white38, size: 14),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          "Against: $lawyerName",
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.access_time, color: Colors.white38, size: 14),
                    const SizedBox(width: 5),
                    Text(
                      dateStr,
                      style: const TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                  ],
                ),

                const Divider(color: Colors.white10, height: 20),

                Align(
                  alignment: Alignment.centerRight,
                  child: InkWell(
                    onTap: () => _showComplaintDetailsDialog(context, firestoreService, cmp),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: goldAccent.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: goldAccent.withOpacity(0.5), width: 0.8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text("View Details", style: TextStyle(color: goldAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 4),
                          Icon(Icons.arrow_forward_ios, color: goldAccent, size: 10),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- Detailed Dialog View ---
  void _showComplaintDetailsDialog(BuildContext context, FirestoreService firestoreService, Map<String, dynamic> cmp) {
    String reason = (cmp['reason'] ?? cmp['category'] ?? cmp['subject'] ?? cmp['title'] ?? 'Complaint').toString();
    String fromName = (cmp['fromName'] ?? cmp['userName'] ?? cmp['clientName'] ?? 'N/A').toString();
    String userEmail = (cmp['userEmail'] ?? cmp['email'] ?? 'N/A').toString();
    String description = (cmp['description'] ?? cmp['details'] ?? cmp['message'] ?? cmp['text'] ?? 'No description provided.').toString();

    bool hasStrike = cmp['hasStrike'] == true || cmp['actionTaken'] == 'Struck';
    String currentStatus = hasStrike ? 'STRIKE_ISSUED' : (cmp['status'] ?? 'Pending').toString().toUpperCase();

    String priority = (cmp['priority'] ?? cmp['severity'] ?? 'Normal').toString();
    String dateStr = _formatDate(cmp['createdAt'] ?? cmp['timestamp']);

    String clientId = (cmp['userId'] ?? cmp['uid'] ?? cmp['fromId'] ?? cmp['clientId'] ?? '').toString();
    String lawyerId = (cmp['lawyerId'] ?? cmp['lawyerUid'] ?? cmp['lawyerUID'] ?? cmp['targetLawyerId'] ?? cmp['lawyerid'] ?? cmp['lawyer_id'] ?? '').toString();
    String lawyerName = (cmp['lawyerName'] ?? cmp['targetLawyerName'] ?? (lawyerId.isNotEmpty ? lawyerId : 'N/A')).toString();

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return Dialog(
          backgroundColor: cardNavy,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: navyBackground,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        "Complaint Details",
                        style: TextStyle(color: goldAccent, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                      onPressed: () => Navigator.pop(dialogCtx),
                    )
                  ],
                ),
              ),

              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              reason,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ),
                          _buildStatusBadge(currentStatus),
                        ],
                      ),
                      const SizedBox(height: 15),

                      // Section 1: Complainant Details
                      _detailSectionHeader("COMPLAINANT DETAILS"),
                      _detailRow("Name", fromName),
                      _detailRow("Email", userEmail),
                      _detailRow("User ID", clientId.isNotEmpty ? clientId : 'N/A'),
                      const SizedBox(height: 15),

                      // Section 2: Lawyer Details & Dynamic Strikes Count
                      _detailSectionHeader("LAWYER DETAILS"),
                      _detailRow("Lawyer Name", lawyerName),
                      _detailRow("Lawyer ID", lawyerId.isNotEmpty ? lawyerId : 'N/A'),

                      // Live Stream to fetch total strikes for this Lawyer
                      if (lawyerId.isNotEmpty)
                        StreamBuilder<List<Map<String, dynamic>>>(
                          stream: firestoreService.getUsers(),
                          builder: (context, lawyerSnap) {
                            int strikesCount = 0;
                            if (lawyerSnap.hasData) {
                              final lawyer = lawyerSnap.data!.firstWhere(
                                    (u) => u['id'] == lawyerId,
                                orElse: () => {},
                              );
                              strikesCount = lawyer['strikesCount'] ?? 0;
                            }
                            return _detailRow("Total Strikes", "$strikesCount / 3");
                          },
                        ),
                      const SizedBox(height: 15),

                      // Section 3: Complaint Info
                      _detailSectionHeader("COMPLAINT INFO"),
                      _detailRow("Category", reason),
                      _detailRow("Priority", priority),
                      _detailRow("Submitted At", dateStr),
                      const SizedBox(height: 10),

                      const Text("Description:", style: TextStyle(color: Colors.white38, fontSize: 12)),
                      const SizedBox(height: 4),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: navyBackground,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Text(
                          description,
                          style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                        ),
                      ),

                      ...cmp.entries.where((e) => !['id', 'status', 'reason', 'category', 'subject', 'title', 'fromName', 'userName', 'userEmail', 'clientName', 'email', 'description', 'details', 'message', 'text', 'userId', 'uid', 'fromId', 'clientId', 'createdAt', 'timestamp', 'lawyerId', 'lawyerUid', 'lawyerUID', 'targetLawyerId', 'lawyerid', 'lawyer_id', 'lawyerName', 'targetLawyerName', 'priority', 'severity', 'hasStrike', 'actionTaken'].contains(e.key)).map((e) => Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text("${e.key}: ${e.value}", style: const TextStyle(color: Colors.white38, fontSize: 11)),
                      )).toList(),

                      const Divider(color: Colors.white10, height: 25),

                      // Section 4: Action Buttons
                      _detailSectionHeader("ACTIONS"),
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _actionButton("Reject", Colors.redAccent, () async {
                              if (clientId.isEmpty) { _showSnackBar(context, "Client ID missing!"); return; }
                              Navigator.pop(dialogCtx);
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
                            const SizedBox(width: 8),

                            _actionButton("Resolved", Colors.green, () async {
                              if (clientId.isEmpty) { _showSnackBar(context, "Client ID missing!"); return; }
                              Navigator.pop(dialogCtx);
                              await firestoreService.updateComplaintStatus(
                                  complaintId: cmp['id'].toString(),
                                  status: "Resolved",
                                  clientId: clientId,
                                  title: "Complaint Resolved",
                                  message: "complaints has been resolved",
                                  type: "complaint_resolved"
                              );
                              _showSnackBar(context, "Marked as Resolved. Client Notified.");
                            }),
                            const SizedBox(width: 8),

                            _actionButton("Pending", Colors.orange, () async {
                              if (clientId.isEmpty) { _showSnackBar(context, "Client ID missing!"); return; }
                              Navigator.pop(dialogCtx);
                              await firestoreService.updateComplaintStatus(
                                  complaintId: cmp['id'].toString(),
                                  status: "Pending",
                                  clientId: clientId,
                                  title: "Complaint Update",
                                  message: "your request is on pending",
                                  type: "complaint_pending"
                              );
                              _showSnackBar(context, "Marked as Pending. Client Notified.");
                            }),
                            const SizedBox(width: 8),

                            _actionButton("Issue Strike", Colors.purple, () {
                              if (lawyerId.isEmpty) {
                                _showSnackBar(context, "Lawyer ID missing from this complaint!");
                                return;
                              }
                              Navigator.pop(dialogCtx);
                              _showStrikeDialog(context, firestoreService, cmp['id'].toString(), lawyerId, clientId, reason);
                            }),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- Helper UI Components ---
  Widget _buildStatusBadge(String status) {
    Color color = Colors.orange;
    if (status == 'RESOLVED') color = Colors.green;
    if (status == 'REJECTED') color = Colors.redAccent;
    if (status == 'STRIKE_ISSUED') color = Colors.purple;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.6), width: 0.5),
      ),
      child: Text(
        status == 'STRIKE_ISSUED' ? 'STRIKE ISSUED' : status,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _detailSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: TextStyle(color: goldAccent, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text("$label:", style: const TextStyle(color: Colors.white38, fontSize: 12)),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return "N/A";
    if (date.runtimeType.toString().contains("Timestamp")) {
      try {
        DateTime dt = date.toDate();
        return "${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}";
      } catch (_) {}
    }
    return date.toString();
  }

  void _showStrikeDialog(BuildContext context, FirestoreService firestoreService, String complaintId, String lawyerId, String clientId, String complaintReason) {
    final TextEditingController reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: cardNavy,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Text(
            "Issue Strike & Resolve",
            style: TextStyle(color: goldAccent, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "This will issue a strike to the lawyer and notify the client that their complaint has been resolved.",
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                style: const TextStyle(color: Colors.white),
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: "Reason for strike...",
                  hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                  filled: true,
                  fillColor: navyBackground,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel", style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                String strikeReason = reasonController.text.trim();
                if (strikeReason.isEmpty) {
                  _showSnackBar(context, "Please enter a reason!");
                  return;
                }
                Navigator.pop(context);

                try {
                  await firestoreService.issueStrike(
                    lawyerId: lawyerId,
                    complaintId: complaintId,
                    reason: strikeReason,
                  );

                  if (clientId.isNotEmpty) {
                    await firestoreService.updateComplaintStatus(
                        complaintId: complaintId,
                        status: "Resolved",
                        clientId: clientId,
                        title: "Complaint Resolved",
                        message: "complaints has been resolved",
                        type: "complaint_resolved",
                        hasStrike: true
                    );
                  }

                  _showSnackBar(context, "Strike Issued & Client Notified (Complaint Resolved).");
                } catch (e) {
                  _showSnackBar(context, "Error: $e");
                }
              },
              child: const Text(
                "Confirm & Send",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
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