import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class HearingDetailsScreen extends StatefulWidget {
  final Map<String, dynamic>? hearingData;
  final String hearingId;

  const HearingDetailsScreen({
    super.key,
    this.hearingData,
    required this.hearingId,
  });

  @override
  State<HearingDetailsScreen> createState() => _HearingDetailsScreenState();
}

class _HearingDetailsScreenState extends State<HearingDetailsScreen> {
  static const Color navyBlue = Color(0xFF001F3F);
  static const Color accentGold = Color(0xFFD4AF37);
  static const Color backgroundColor = Color(0xFFF8F9FA);

  List<Map<String, dynamic>> combinedHistory = [];

  @override
  void initState() {
    super.initState();
    _loadNotificationHistory();
  }

  void _loadNotificationHistory() {
    try {
      if (widget.hearingData != null && widget.hearingData!.containsKey('previous_hearings')) {
        var rawData = widget.hearingData!['previous_hearings'];
        if (rawData is List) {
          for (var item in rawData) {
            if (item is Map) {
              combinedHistory.add(Map<String, dynamic>.from(item));
            }
          }
        }
      }
    } catch (e) {
      debugPrint("Error loading notification history: $e");
    }
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return "N/A";
    if (timestamp is Timestamp) {
      return DateFormat('dd MMM yyyy, hh:mm a').format(timestamp.toDate());
    }
    if (timestamp is String) return timestamp;
    return "N/A";
  }

  @override
  Widget build(BuildContext context) {
    // Agar widget.hearingData mein direct data mojood ho toh use karein, warna Firestore se stream karein
    if (widget.hearingData != null) {
      return _buildScaffoldWithData(widget.hearingData!);
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: navyBlue,
        elevation: 0,
        title: const Text(
          "Hearing Details",
          style: TextStyle(color: accentGold, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: accentGold),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('Hearings').doc(widget.hearingId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: navyBlue));
          }

          var data = (snapshot.hasData && snapshot.data!.exists)
              ? snapshot.data!.data() as Map<String, dynamic>
              : null;

          if (data == null) {
            return const Center(child: Text("Hearing details not found."));
          }

          return _buildBodyContent(data);
        },
      ),
    );
  }

  Widget _buildScaffoldWithData(Map<String, dynamic> data) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: navyBlue,
        elevation: 0,
        title: const Text(
          "Hearing Details",
          style: TextStyle(color: accentGold, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: accentGold),
      ),
      body: _buildBodyContent(data),
    );
  }

  Widget _buildBodyContent(Map<String, dynamic> data) {
    String caseNumber = (data['caseNumber'] ?? data['case_number'])?.toString() ??
        'CN-${widget.hearingId.length >= 5 ? widget.hearingId.substring(0, 5).toUpperCase() : widget.hearingId.toUpperCase()}';
    String caseTitle = (data['caseType'] ?? data['case_type'] ?? data['type'] ?? 'Legal Case').toString();
    String courtName = (data['courtName'] ?? data['courtLocation'] ?? data['court_location'] ?? 'District Court').toString();

    String hearingDate = _formatDate(data['hearingDate'] ?? data['nextHearingDate'] ?? data['next_hearing_date'] ?? data['hearing_date'] ?? data['date']);
    String hearingTime = (data['hearingTime'] ?? data['hearing_time'] ?? data['time'] ?? 'N/A').toString();
    String hearingDetails = (data['hearingDescription'] ?? data['details'] ?? data['hearingDetails'] ?? data['body'] ?? data['note'] ?? data['message'] ?? 'No additional details provided.').toString();
    String status = (data['status'] ?? 'Upcoming').toString();
    String lastUpdated = _formatDate(data['createdAt'] ?? data['lastUpdated'] ?? data['updatedAt']);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMainInfoCard(
            caseNumber,
            caseTitle,
            courtName,
            hearingDate,
            hearingTime,
            hearingDetails,
            status,
            lastUpdated,
          ),
          const SizedBox(height: 30),
          const Row(
            children: [
              Icon(Icons.history, color: navyBlue),
              SizedBox(width: 10),
              Text(
                "Case History",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: navyBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          _buildHistoryList(data),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildMainInfoCard(
      String caseNumber,
      String caseTitle,
      String courtName,
      String hearingDate,
      String hearingTime,
      String hearingDetails,
      String status,
      String lastUpdated,
      ) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: navyBlue,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _statusBadge(status),
                    Text(
                      caseNumber,
                      style: const TextStyle(
                        color: accentGold,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                Text(
                  caseTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                _infoRow(Icons.account_balance_rounded, "Court Name", courtName),
                const Divider(height: 32),
                Row(
                  children: [
                    Expanded(child: _infoRow(Icons.calendar_today_rounded, "Hearing Date", hearingDate)),
                    Container(width: 1, height: 40, color: Colors.grey.shade200),
                    const SizedBox(width: 15),
                    Expanded(child: _infoRow(Icons.access_time_rounded, "Hearing Time", hearingTime)),
                  ],
                ),
                const Divider(height: 32),
                _infoRow(Icons.description_rounded, "Description", hearingDetails),
                const SizedBox(height: 25),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.update, size: 14, color: Colors.grey),
                      const SizedBox(width: 6),
                      Text(
                        "Last Updated: $lastUpdated",
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: accentGold.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: accentGold, size: 20),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  color: navyBlue,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _statusBadge(String status) {
    Color color;
    IconData icon;
    switch (status.toLowerCase()) {
      case 'upcoming':
        color = Colors.blue;
        icon = Icons.event_available;
        break;
      case 'completed':
        color = Colors.green;
        icon = Icons.check_circle;
        break;
      case 'postponed':
        color = Colors.orange;
        icon = Icons.event_busy;
        break;
      default:
        color = Colors.grey;
        icon = Icons.help_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 6),
          Text(
            status.toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryList(Map<String, dynamic> parentData) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('Hearings')
          .doc(widget.hearingId)
          .collection('History')
          .orderBy('hearing_date', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        // Use a Map to avoid duplicates based on date
        Map<String, Map<String, dynamic>> historyMap = {};

        // 1. Add from passed hearingData (if any)
        for (var item in combinedHistory) {
          String dateKey = _formatDate(item['hearing_date'] ?? item['date']);
          historyMap[dateKey] = item;
        }

        // 2. Add from parentData (current stream data) previous_hearings array
        if (parentData.containsKey('previous_hearings')) {
          var arrayData = parentData['previous_hearings'];
          if (arrayData is List) {
            for (var item in arrayData) {
              if (item is Map) {
                var casted = Map<String, dynamic>.from(item);
                String dateKey = _formatDate(casted['hearing_date'] ?? casted['date']);
                historyMap[dateKey] = casted;
              }
            }
          }
        }

        // 3. Add from Firestore History subcollection stream
        if (snapshot.hasData) {
          for (var doc in snapshot.data!.docs) {
            var data = doc.data() as Map<String, dynamic>;
            String dateKey = _formatDate(data['hearing_date'] ?? data['date']);
            historyMap[dateKey] = data;
          }
        }

        List<Map<String, dynamic>> historyItems = historyMap.values.toList();
        
        // Sort by date descending
        historyItems.sort((a, b) {
          var dateA = a['hearing_date'] ?? a['date'];
          var dateB = b['hearing_date'] ?? b['date'];
          
          if (dateA is Timestamp && dateB is Timestamp) {
            return dateB.compareTo(dateA);
          }
          return 0;
        });

        if (historyItems.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade100),
            ),
            child: Column(
              children: [
                Icon(Icons.history_toggle_off, size: 40, color: Colors.grey.shade300),
                const SizedBox(height: 10),
                const Text(
                  "No previous hearing records available.",
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: historyItems.length,
          itemBuilder: (context, index) {
            var data = historyItems[index];
            return _buildHistoryItem(data);
          },
        );
      },
    );
  }

  Widget _buildHistoryItem(Map<String, dynamic> data) {
    String date = _formatDate(data['hearing_date'] ?? data['date']);
    String court = (data['court_location'] ?? 'District Court').toString();
    String status = (data['status'] ?? 'N/A').toString();

    Color statusColor;
    switch (status.toLowerCase()) {
      case 'completed': statusColor = Colors.green; break;
      case 'postponed': statusColor = Colors.orange; break;
      default: statusColor = Colors.grey;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: navyBlue.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.gavel_rounded, color: navyBlue, size: 18),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  date,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: navyBlue,
                    fontSize: 15,
                  ),
                ),
                Text(
                  court,
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              status,
              style: TextStyle(
                color: statusColor,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
