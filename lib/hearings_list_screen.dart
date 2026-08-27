import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'Hearing_details.dart';

class HearingsListScreen extends StatelessWidget {
  const HearingsListScreen({super.key});

  final Color navyBlue = const Color(0xFF101D3D);
  final Color goldColor = const Color(0xFFC5A358);

  // Helper method to safely extract and format dates regardless of type (Timestamp or String)
  String _safeFormatDate(dynamic dateVal) {
    if (dateVal == null) return 'N/A';
    if (dateVal is Timestamp) {
      DateTime dt = dateVal.toDate();
      return "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}";
    }
    return dateVal.toString();
  }

  // Hearing History Bottom Sheet (Fetches history from Hearings -> caseId -> history subcollection)
  void _showHearingHistory(BuildContext context, String caseId, String clientName) {
    showModalBottomSheet(
      context: context,
      backgroundColor: navyBlue,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "History: $clientName",
                    style: TextStyle(color: goldColor, fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(color: Colors.white24),
              const SizedBox(height: 10),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('Hearings')
                      .doc(caseId)
                      .collection('history')
                      .orderBy('createdTimeStamp', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: Colors.white));
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(
                        child: Text("No hearing history records found.", style: TextStyle(color: Colors.white54)),
                      );
                    }

                    var historyDocs = snapshot.data!.docs;

                    return ListView.builder(
                      itemCount: historyDocs.length,
                      itemBuilder: (context, index) {
                        var hData = historyDocs[index].data() as Map<String, dynamic>;

                        String historyDate = _safeFormatDate(hData['hearingDate'] ?? hData['hearing_date'] ?? hData['date']);
                        String historyTime = (hData['hearingTime'] ?? hData['hearing_time'] ?? 'N/A').toString();
                        String historyLocation = (hData['courtLocation'] ?? hData['court_location'] ?? 'N/A').toString();
                        String historyDesc = (hData['hearingDescription'] ?? hData['description'] ?? '').toString();

                        return Card(
                          color: Colors.white.withOpacity(0.1),
                          margin: const EdgeInsets.only(bottom: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          child: ListTile(
                            leading: Icon(Icons.event_available, color: goldColor),
                            title: Text(
                              "Date: $historyDate",
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(
                                  "Time: $historyTime\nLocation: $historyLocation",
                                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                                ),
                                if (historyDesc.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    "Note: $historyDesc",
                                    style: const TextStyle(color: Colors.amberAccent, fontSize: 11),
                                  ),
                                ],
                              ],
                            ),
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
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final String? uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text("Scheduled Hearings", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: navyBlue,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: uid == null
          ? const Center(child: Text("Please login to see hearings"))
          : StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('Hearings').snapshots(),
        builder: (context, snapshot) {
          var docs = snapshot.data?.docs.where((doc) {
            var data = doc.data() as Map<String, dynamic>;
            String lId = (data['lawyerid'] ?? data['lawyerId'] ?? "").toString().trim();

            // Check Lawyer Assignment for Hearings collection
            bool isAssigned = lId == uid.toString().trim();

            // Check if explicitly saved or has status Manual/Active
            bool isSaved = data['isSaved'] == true || data['status'] == 'Manual' || data['status'] == 'Active';

            return isAssigned && isSaved;
          }).toList() ?? [];

          if (docs.isEmpty && snapshot.connectionState != ConnectionState.waiting) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.event_note, size: 80, color: navyBlue.withOpacity(0.3)),
                  const SizedBox(height: 15),
                  const Text("No saved scheduled hearings found.", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                ],
              ),
            );
          }

          if (docs.isEmpty && snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              var doc = docs[index];
              Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

              String clientName = data['clientName'] ?? data['client_name'] ?? "Client Name";

              // Safe parsing for main list hearing date from Hearings collection
              String hearingDate = _safeFormatDate(data['hearingDate'] ?? data['hearing_date'] ?? data['date']);
              String hearingTime = (data['hearingTime'] ?? data['hearing_time'] ?? "N/A").toString();

              // Formatting court location safely
              String courtName = (data['courtName'] ?? "").toString();
              String district = (data['district'] ?? "").toString();
              String courtLocation = data['courtLocation'] ?? data['court_location'] ??
                  (courtName.isNotEmpty ? "$courtName${district.isNotEmpty ? ', $district' : ''}" : "Not Set");

              return Card(
                elevation: 4,
                margin: const EdgeInsets.only(bottom: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(clientName,
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: navyBlue)),

                          InkWell(
                            onTap: () => _showHearingHistory(context, doc.id, clientName),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: goldColor.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: goldColor),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.history, size: 14, color: navyBlue),
                                  const SizedBox(width: 4),
                                  Text(
                                    "History",
                                    style: TextStyle(
                                        color: navyBlue,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text("Date: $hearingDate",
                          style: TextStyle(color: goldColor, fontWeight: FontWeight.w600)),
                      const Divider(height: 20),
                      Row(
                        children: [
                          const Icon(Icons.access_time, size: 16, color: Colors.grey),
                          const SizedBox(width: 5),
                          Text(hearingTime, style: const TextStyle(color: Colors.grey)),
                          const SizedBox(width: 15),
                          const Icon(Icons.location_on, size: 16, color: Colors.grey),
                          const SizedBox(width: 5),
                          Expanded(child: Text(courtLocation, style: const TextStyle(color: Colors.grey), overflow: TextOverflow.ellipsis)),
                        ],
                      ),
                      const SizedBox(height: 15),
                      SizedBox(
                        width: double.infinity,
                        height: 45,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: goldColor,
                              foregroundColor: navyBlue,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => HearingDetailsScreen(
                                  caseId: doc.id,
                                  clientName: clientName,
                                ),
                              ),
                            );
                          },
                          child: const Text("HEARING DETAILS", style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      )
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}