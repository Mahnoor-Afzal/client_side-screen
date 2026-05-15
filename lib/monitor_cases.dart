import 'package:flutter/material.dart';
import 'firestore_service.dart';

class MonitorCases extends StatelessWidget {
  const MonitorCases({super.key});

  final Color navyBackground = const Color(0xFF0F172A);
  final Color goldAccent = const Color(0xFFC7A15E);
  final Color cardNavy = const Color(0xFF1E293B);

  @override
  Widget build(BuildContext context) {
    final FirestoreService firestoreService = FirestoreService();

    return DefaultTabController(
      length: 4, // All, Active, Pending, Closed
      child: Scaffold(
        backgroundColor: navyBackground,
        appBar: AppBar(
          backgroundColor: cardNavy,
          elevation: 0,
          title: Text("Monitor Cases", style: TextStyle(color: goldAccent, fontWeight: FontWeight.bold)),
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: goldAccent),
            onPressed: () => Navigator.pop(context),
          ),
          bottom: TabBar(
            isScrollable: true,
            indicatorColor: goldAccent,
            labelColor: goldAccent,
            unselectedLabelColor: Colors.white54,
            tabs: const [
              Tab(text: "All Cases"),
              Tab(text: "Active"),
              Tab(text: "Pending"),
              Tab(text: "Closed"),
            ],
          ),
        ),
        body: StreamBuilder<List<Map<String, dynamic>>>(
          stream: firestoreService.getCases(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text("Error: ${snapshot.error}", style: const TextStyle(color: Colors.white)));
            }
            final cases = snapshot.data ?? [];

            return TabBarView(
              children: [
                _buildCaseList(cases, "All"),
                _buildCaseList(cases, "Active"),
                _buildCaseList(cases, "Pending"),
                _buildCaseList(cases, "Closed"),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildCaseList(List<Map<String, dynamic>> allCases, String statusFilter) {
    final filteredCases = allCases.where((caseData) {
      if (statusFilter == "All") return true;
      return caseData['status']?.toString().toLowerCase() == statusFilter.toLowerCase();
    }).toList();

    if (filteredCases.isEmpty) {
      return Center(child: Text("No $statusFilter cases found", style: const TextStyle(color: Colors.white54)));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(15),
      itemCount: filteredCases.length,
      itemBuilder: (context, index) {
        final caseData = filteredCases[index];
        
        // FIX: Using .toString() for every field to avoid "int is not a subtype of String" error
        String title = (caseData['caseType'] ?? caseData['title'] ?? 'Untitled Case').toString();
        String client = (caseData['clientName'] ?? caseData['client'] ?? 'N/A').toString();
        String lawyer = (caseData['lawyerid'] ?? caseData['lawyerName'] ?? 'N/A').toString();
        String date = (caseData['createdAt'] ?? caseData['date'] ?? 'N/A').toString();
        String status = (caseData['status'] ?? 'Pending').toString();

        return Card(
          color: cardNavy,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          child: Padding(
            padding: const EdgeInsets.all(15.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                    _statusBadge(status),
                  ],
                ),
                const Divider(color: Colors.white10, height: 20),
                _infoRow(Icons.person, "Client: ", client),
                _infoRow(Icons.gavel, "Lawyer: ", lawyer),
                _infoRow(Icons.calendar_today, "Created: ", date),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _statusBadge(String status) {
    Color badgeColor;
    String s = status.toLowerCase();
    if (s == "active") badgeColor = Colors.green;
    else if (s == "pending") badgeColor = Colors.orange;
    else if (s == "closed") badgeColor = Colors.redAccent;
    else badgeColor = Colors.blueGrey;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: badgeColor.withAlpha(50), borderRadius: BorderRadius.circular(8)),
      child: Text(status, style: TextStyle(color: badgeColor, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: goldAccent),
          const SizedBox(width: 10),
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 14)),
          Expanded(child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 14), overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }
}
