import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'Hearing_details.dart';

class HearingsListScreen extends StatelessWidget {
  const HearingsListScreen({super.key});

  final Color navyBlue = const Color(0xFF101D3D);
  final Color goldColor = const Color(0xFFC5A358);

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
              // Fetching all hearings and filtering in code to prevent any "disappearing" issue
              stream: FirebaseFirestore.instance.collection('Hearings').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                // Master Filter for Lawyer ID (Handling both lawyerid and lawyerId)
                var docs = snapshot.data?.docs.where((doc) {
                  var data = doc.data() as Map<String, dynamic>;
                  String lId = (data['lawyerid'] ?? data['lawyerId'] ?? "").toString().trim();
                  return lId == uid.toString().trim();
                }).toList() ?? [];

                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.event_note, size: 80, color: navyBlue.withOpacity(0.3)),
                        const SizedBox(height: 15),
                        const Text("No scheduled hearings found.", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 40),
                          child: Text(
                            "Lawyer ID: $uid\n(Ensure this ID matches perfectly in Firebase)",
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 10, color: Colors.blueGrey),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    var doc = docs[index];
                    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

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
                                Text(data['client_name'] ?? "Client Name", 
                                     style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: navyBlue)),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: (data['status'] == 'Upcoming') ? Colors.blue.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    data['status'] ?? "Upcoming",
                                    style: TextStyle(
                                      color: (data['status'] == 'Upcoming') ? Colors.blue : Colors.green, 
                                      fontSize: 12, 
                                      fontWeight: FontWeight.bold
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),
                            Text("Hearing Date: ${data['hearing_date'] ?? 'N/A'}", 
                                 style: TextStyle(color: goldColor, fontWeight: FontWeight.w600)),
                            const Divider(height: 20),
                            Row(
                              children: [
                                const Icon(Icons.access_time, size: 16, color: Colors.grey),
                                const SizedBox(width: 5),
                                Text(data['hearing_time'] ?? "N/A", style: const TextStyle(color: Colors.grey)),
                                const SizedBox(width: 15),
                                const Icon(Icons.location_on, size: 16, color: Colors.grey),
                                const SizedBox(width: 5),
                                Expanded(child: Text(data['court_location'] ?? "Not Set", style: const TextStyle(color: Colors.grey), overflow: TextOverflow.ellipsis)),
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
                                        clientName: data['client_name'] ?? "Client",
                                      ),
                                    ),
                                  );
                                },
                                child: const Text("UPDATE DETAILS", style: TextStyle(fontWeight: FontWeight.bold)),
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
