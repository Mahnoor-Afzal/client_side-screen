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
      String lastUpdated) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: navyBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  caseNumber,
                  style: const TextStyle(
                    color: navyBlue,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  status,
                  style: const TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            caseTitle,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: navyBlue,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.location_on, color: accentGold, size: 16),
              const SizedBox(width: 4),
              Text(
                courtName,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 25),
          const Divider(height: 1),
          const SizedBox(height: 25),
          Row(
            children: [
              _buildInfoItem(Icons.calendar_today_rounded, "Date", hearingDate),
              const SizedBox(width: 30),
              _buildInfoItem(Icons.access_time_rounded, "Time", hearingTime),
            ],
          ),
          const SizedBox(height: 25),
          const Text(
            "Hearing Summary",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: navyBlue,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            hearingDetails,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 25),
          const Divider(height: 1),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Last Updated",
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
              ),
              Text(
                lastUpdated,
                style: const TextStyle(
                  color: navyBlue,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: accentGold, size: 14),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: navyBlue,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
