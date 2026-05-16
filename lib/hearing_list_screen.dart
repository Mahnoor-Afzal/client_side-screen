import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HearingListScreen extends StatefulWidget {
  const HearingListScreen({super.key});

  @override
  State<HearingListScreen> createState() => _HearingListScreenState();
}

class _HearingListScreenState extends State<HearingListScreen> {
  final Color navyBlue = const Color(0xFF001F3F);
  final Color gold = const Color(0xFFD4AF37);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: navyBlue,
        title: const Text("My Hearings", style: TextStyle(color: Color(0xFFD4AF37), fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Color(0xFFD4AF37)),
      ),
      body: user == null
          ? const Center(child: Text("Please login to view hearings"))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('Hearings')
                  .where('clientId', isEqualTo: user.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                var docs = snapshot.data?.docs ?? [];

                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.event_busy, size: 80, color: navyBlue.withOpacity(0.2)),
                        const SizedBox(height: 16),
                        const Text("No hearings scheduled yet.", style: TextStyle(fontSize: 16, color: Colors.grey)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    var data = docs[index].data() as Map<String, dynamic>;
                    // Case type fallback agar field missing ho
                    String caseType = data['case_type'] ?? data['type'] ?? "Legal Case";
                    String date = data['hearing_date'] ?? "TBD";
                    
                    return Card(
                      elevation: 3,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        leading: CircleAvatar(
                          backgroundColor: navyBlue.withOpacity(0.1),
                          child: Icon(Icons.gavel_rounded, color: navyBlue),
                        ),
                        title: Text(
                          caseType,
                          style: TextStyle(fontWeight: FontWeight.bold, color: navyBlue, fontSize: 18),
                        ),
                        subtitle: Text("Next Hearing: $date", style: const TextStyle(color: Colors.redAccent)),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                        onTap: () => _showHearingDetails(context, data),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }

  void _showHearingDetails(BuildContext context, Map<String, dynamic> data) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        padding: const EdgeInsets.all(25),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 50,
                height: 5,
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 25),
            Text(data['case_type'] ?? "Hearing Detail", 
                 style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: navyBlue)),
            const Divider(height: 30),
            _detailRow(Icons.calendar_today, "Date", data['hearing_date'] ?? "N/A"),
            _detailRow(Icons.access_time, "Time", data['hearing_time'] ?? "N/A"),
            _detailRow(Icons.location_on, "Court", data['court_location'] ?? "Not Specified"),
            _detailRow(Icons.person, "Lawyer", data['lawyerName'] ?? "Advocate"),
            const SizedBox(height: 20),
            const Text("Notes / Instructions:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(15),
              ),
              child: Text(
                data['description'] ?? data['hearingDetails'] ?? "No additional instructions from lawyer.",
                style: const TextStyle(fontSize: 15, height: 1.5),
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: navyBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                child: const Text("GO BACK", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Row(
        children: [
          Icon(icon, color: gold, size: 20),
          const SizedBox(width: 15),
          Text("$label: ", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          Text(value, style: TextStyle(fontWeight: FontWeight.w600, color: navyBlue, fontSize: 16)),
        ],
      ),
    );
  }
}
