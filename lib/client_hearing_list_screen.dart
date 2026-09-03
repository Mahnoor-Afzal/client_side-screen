import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:rxdart/rxdart.dart';
import 'client_hearing_details_screen.dart';

class HearingListScreen extends StatefulWidget {
  const HearingListScreen({super.key});

  @override
  State<HearingListScreen> createState() => _HearingListScreenState();
}

class _HearingListScreenState extends State<HearingListScreen> {
  static const Color navyBlue = Color(0xFF001F3F);
  static const Color accentGold = Color(0xFFD4AF37);

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) {
      try {
        // Try parsing common formats
        return DateFormat('dd MMM yyyy').parse(value);
      } catch (e) {
        return DateTime.tryParse(value);
      }
    }
    return null;
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return "TBD";
    DateTime? dt = _parseDate(timestamp);
    if (dt != null) {
      return DateFormat('dd MMM yyyy').format(dt);
    }
    return timestamp.toString();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: navyBlue,
        elevation: 0,
        title: const Text("My Hearings", style: TextStyle(color: accentGold, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: accentGold),
      ),
      body: user == null
          ? const Center(child: Text("Please login to view hearings"))
          : StreamBuilder<List<QuerySnapshot>>(
              stream: CombineLatestStream.list([
                FirebaseFirestore.instance.collection('Hearings').where('clientId', isEqualTo: user.uid).snapshots(),
                FirebaseFirestore.instance.collection('Hearings').where('userId', isEqualTo: user.uid).snapshots(),
                FirebaseFirestore.instance.collection('notifications').where('userId', isEqualTo: user.uid).snapshots(),
                FirebaseFirestore.instance.collection('suit_a_file_request').where('clientId', isEqualTo: user.uid).snapshots(),
                FirebaseFirestore.instance.collection('consultation_request').where('clientId', isEqualTo: user.uid).snapshots(),
              ]),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red, size: 48),
                          const SizedBox(height: 16),
                          Text(
                            "Something went wrong while fetching hearings.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: navyBlue.withValues(alpha: 0.7),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Technical details: ${snapshot.error}",
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: navyBlue));
                }

                List<QueryDocumentSnapshot> allDocs = [];
                if (snapshot.hasData) {
                  for (var qSnap in snapshot.data!) {
                    allDocs.addAll(qSnap.docs);
                  }
                }

                // Split into Upcoming and Previous
                List<Map<String, dynamic>> allUpcoming = [];
                List<Map<String, dynamic>> allPrevious = [];
                Set<String> seenRecords = {}; // To avoid duplicates
                DateTime now = DateTime.now();
                DateTime today = DateTime(now.year, now.month, now.day);

                for (var doc in allDocs) {
                  var data = doc.data() as Map<String, dynamic>;
                  String collection = doc.reference.parent.id;

                  // If it's a notification, only process if it's hearing-related
                  if (collection == 'notifications') {
                    String type = (data['type'] ?? '').toString().toLowerCase();
                    if (!type.contains('hearing') && !type.contains('manual') && !type.contains('case') && !type.contains('court')) {
                      continue;
                    }
                  }
                  
                  // For request collections, only show if a hearing date is actually set
                  if (collection == 'suit_a_file_request' || collection == 'consultation_request') {
                    if (data['hearingDate'] == null && data['hearing_date'] == null && data['nextHearingDate'] == null) {
                      continue;
                    }
                  }

                  String caseNum = (data['caseNumber'] ?? data['case_number'] ?? '').toString();
                  String caseTitle = (data['case_type'] ?? data['type'] ?? data['case_title'] ?? data['title'] ?? (collection == 'consultation_request' ? "Consultation" : "Legal Case")).toString();
                  if (caseNum.isNotEmpty && !caseTitle.contains(caseNum)) {
                    caseTitle = "$caseTitle: Case #$caseNum";
                  }
                  
                  // Process main hearing date - support multiple field names
                  var mainHearing = Map<String, dynamic>.from(data);
                  mainHearing['docId'] = data['hearingId'] ?? data['caseId'] ?? data['requestId'] ?? doc.id;
                  mainHearing['displayTitle'] = caseTitle;
                  
                  // Unified date field for sorting and display
                  dynamic rawDate = data['hearingDate'] ?? data['hearing_date'] ?? data['next_hearing_date'] ?? data['nextHearingDate'] ?? data['date'] ?? data['createdAt'];
                  mainHearing['unified_date'] = rawDate;
                  
                  DateTime? dt = _parseDate(rawDate);
                  String dateKey = dt != null ? DateFormat('yyyy-MM-dd').format(dt) : (rawDate ?? '').toString();
                  
                  bool isCompleted = data['status']?.toString().toLowerCase() == 'completed' || data['status']?.toString().toLowerCase() == 'closed' || data['status']?.toString().toLowerCase() == 'resolved';
                  
                  String uniqueKey = "${mainHearing['docId']}_$dateKey";

                  if (dt != null && (dt.isAfter(today) || dt.isAtSameMomentAs(today)) && !isCompleted) {
                    if (!seenRecords.contains(uniqueKey)) {
                      allUpcoming.add(mainHearing);
                      seenRecords.add(uniqueKey);
                    }
                  } else if (dateKey.isNotEmpty) {
                    if (!seenRecords.contains(uniqueKey)) {
                      allPrevious.add(mainHearing);
                      seenRecords.add(uniqueKey);
                    }
                  }

                  // Process previous_hearings array if exists
                  if (data['previous_hearings'] != null && data['previous_hearings'] is List) {
                    for (var prev in data['previous_hearings']) {
                      if (prev is Map) {
                        var prevEvent = Map<String, dynamic>.from(prev);
                        String pDateStr = (prevEvent['hearing_date'] ?? prevEvent['date'] ?? '').toString();
                        String key = "${mainHearing['docId']}_$pDateStr";
                        
                        if (pDateStr.isNotEmpty && !seenRecords.contains(key)) {
                          prevEvent['docId'] = mainHearing['docId'];
                          prevEvent['displayTitle'] = caseTitle;
                          allPrevious.add(prevEvent);
                          seenRecords.add(key);
                        }
                      }
                    }
                  }
                }

                // Sort lists
                allUpcoming.sort((a, b) {
                  DateTime? da = _parseDate(a['unified_date']);
                  DateTime? db = _parseDate(b['unified_date']);
                  if (da == null) return 1;
                  if (db == null) return -1;
                  return da.compareTo(db);
                });

                allPrevious.sort((a, b) {
                  DateTime? da = _parseDate(a['unified_date']);
                  DateTime? db = _parseDate(b['unified_date']);
                  if (da == null) return 1;
                  if (db == null) return -1;
                  return db.compareTo(da); 
                });

                List<Widget> listItems = [];

                if (allUpcoming.isNotEmpty) {
                  listItems.add(const Padding(
                    padding: EdgeInsets.only(bottom: 12, top: 4),
                    child: Text(
                      "Upcoming Hearings",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: navyBlue),
                    ),
                  ));
                  listItems.addAll(allUpcoming.map((item) => _buildHearingCard(item, context)));
                }

                if (allPrevious.isNotEmpty) {
                  listItems.add(const SizedBox(height: 10));
                  listItems.add(
                    Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Theme(
                        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          initiallyExpanded: false,
                          leading: const Icon(Icons.history, color: navyBlue),
                          title: const Text(
                            "Previous / History",
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: navyBlue),
                          ),
                          subtitle: Text(
                            "${allPrevious.length} past records",
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          children: allPrevious.map((item) => _buildHearingCard(item, context, isPast: true)).toList(),
                        ),
                      ),
                    ),
                  );
                }

                if (listItems.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.event_note_outlined, size: 80, color: navyBlue.withValues(alpha: 0.1)),
                        const SizedBox(height: 16),
                        const Text("No active hearings found.", style: TextStyle(fontSize: 16, color: Colors.grey)),
                        const Text("Details will appear once updated by your lawyer.", style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  );
                }

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: listItems,
                );
              },
            ),
    );
  }

  Widget _buildHearingCard(Map<String, dynamic> data, BuildContext context, {bool isPast = false}) {
    String caseTitle = (data['case_type'] ?? data['type'] ?? data['case_title'] ?? data['title'] ?? (data['caseType'] ?? "Legal Case")).toString();
    String date = _formatDate(data['hearingDate'] ?? data['hearing_date'] ?? data['next_hearing_date'] ?? data['nextHearingDate'] ?? data['date']);
    String status = (data['status'] ?? (isPast ? 'Completed' : 'Upcoming')).toString();
    String docId = data['docId'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: (isPast ? Colors.grey : navyBlue).withValues(alpha: 0.05),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.gavel_rounded, color: isPast ? Colors.grey : navyBlue),
        ),
        title: Text(
          caseTitle,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isPast ? Colors.grey[700] : navyBlue,
            fontSize: 17,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              isPast ? "Hearing Date: $date" : "Next Hearing: $date",
              style: TextStyle(
                color: isPast ? Colors.grey : Colors.redAccent,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            _statusText(status),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => HearingDetailsScreen(
                hearingData: data,
                hearingId: docId,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _statusText(String status) {
    String lowerStatus = status.toLowerCase();
    Color color = Colors.blue;
    if (lowerStatus == 'completed') color = Colors.green;
    if (lowerStatus == 'postponed' || lowerStatus == 'delayed') color = Colors.orange;
    if (lowerStatus == 'cancelled') color = Colors.red;
    
    return Text(
      status,
      style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
    );
  }
}
