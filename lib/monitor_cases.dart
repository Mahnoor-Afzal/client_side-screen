import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class MonitorCases extends StatefulWidget {
  const MonitorCases({super.key});

  @override
  State<MonitorCases> createState() => _MonitorCasesState();
}

class _MonitorCasesState extends State<MonitorCases> {
  final Color navyBackground = const Color(0xFF0F172A);
  final Color goldAccent = const Color(0xFFC7A15E);
  final Color cardNavy = const Color(0xFF1E293B);

  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _allCases = [];

  @override
  void initState() {
    super.initState();
    _fetchCasesData();
  }

  Future<void> _fetchCasesData() async {
    try {
      if (!mounted) return;
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // Fetch documents in parallel using Future.wait
      final results = await Future.wait([
        FirebaseFirestore.instance.collection('Case request').get(),
        FirebaseFirestore.instance.collection('consultation_request').get(),
        FirebaseFirestore.instance.collection('suit_a_file_request').get(),
        FirebaseFirestore.instance.collection('cases').get(),
      ]);

      List<Map<String, dynamic>> combined = [];

      for (var doc in results[0].docs) {
        combined.add({'id': doc.id, 'requestType': 'Case Request', ...doc.data()});
      }
      for (var doc in results[1].docs) {
        combined.add({'id': doc.id, 'requestType': 'Consultation Request', ...doc.data()});
      }
      for (var doc in results[2].docs) {
        combined.add({'id': doc.id, 'requestType': 'Suit a File Request', ...doc.data()});
      }
      for (var doc in results[3].docs) {
        combined.add({'id': doc.id, 'requestType': 'Active Case', ...doc.data()});
      }

      // Sort combined records descending based on creation date/timestamp
      combined.sort((a, b) {
        DateTime dateA = _getRawDateTime(a['createdAt'] ?? a['timestamp'] ?? a['updatedAt'] ?? a['date']);
        DateTime dateB = _getRawDateTime(b['createdAt'] ?? b['timestamp'] ?? b['updatedAt'] ?? b['date']);
        return dateB.compareTo(dateA);
      });

      if (!mounted) return;
      setState(() {
        _allCases = combined;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  // Safely format Firestore Timestamps, Numbers, or Strings into 'dd MMM yyyy'
  String _formatDate(dynamic dateVal) {
    if (dateVal == null) return "N/A";
    try {
      DateTime dt;
      if (dateVal is Timestamp) {
        dt = dateVal.toDate();
      } else if (dateVal is int) {
        dt = DateTime.fromMillisecondsSinceEpoch(dateVal);
      } else if (dateVal is String) {
        dt = DateTime.tryParse(dateVal) ?? DateTime.now();
      } else {
        return "N/A";
      }
      return DateFormat('dd MMM yyyy').format(dt);
    } catch (_) {
      return "N/A";
    }
  }

  // Parse DateTime helper for sorting combined records
  DateTime _getRawDateTime(dynamic dateVal) {
    if (dateVal == null) return DateTime.fromMillisecondsSinceEpoch(0);
    try {
      if (dateVal is Timestamp) return dateVal.toDate();
      if (dateVal is int) return DateTime.fromMillisecondsSinceEpoch(dateVal);
      if (dateVal is String) return DateTime.tryParse(dateVal) ?? DateTime.fromMillisecondsSinceEpoch(0);
    } catch (_) {}
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  // Multi-collection lookup for Lawyer Name (verified_lawyers -> lawyers -> users)
  Future<String> _getLawyerName(String rawIdOrName) async {
    if (rawIdOrName.isEmpty || rawIdOrName == 'N/A' || rawIdOrName == 'null') {
      return 'N/A';
    }

    if (rawIdOrName.contains(' ') && !rawIdOrName.startsWith('0x')) {
      return rawIdOrName;
    }

    try {
      final verifiedDoc = await FirebaseFirestore.instance.collection('verified_lawyers').doc(rawIdOrName).get();
      if (verifiedDoc.exists && verifiedDoc.data() != null) {
        final data = verifiedDoc.data()!;
        return data['fullName'] ?? data['name'] ?? data['displayName'] ?? rawIdOrName;
      }

      final lawyerDoc = await FirebaseFirestore.instance.collection('lawyers').doc(rawIdOrName).get();
      if (lawyerDoc.exists && lawyerDoc.data() != null) {
        final data = lawyerDoc.data()!;
        return data['fullName'] ?? data['name'] ?? data['displayName'] ?? rawIdOrName;
      }

      final userDoc = await FirebaseFirestore.instance.collection('users').doc(rawIdOrName).get();
      if (userDoc.exists && userDoc.data() != null) {
        final data = userDoc.data()!;
        return data['displayName'] ?? data['fullName'] ?? data['name'] ?? rawIdOrName;
      }
    } catch (_) {}

    return rawIdOrName;
  }

  // Calculate active cases count per lawyer ID/Name
  Map<String, int> _calculateLawyerActiveCounts(List<Map<String, dynamic>> allCases) {
    Map<String, int> counts = {};

    final activeCases = _filterCases(allCases, "Active");
    for (var c in activeCases) {
      String rawLawyerId = (c['lawyerId'] ?? c['lawyerid'] ?? c['lawyerName'] ?? '').toString().trim();
      if (rawLawyerId.isNotEmpty && rawLawyerId != 'N/A' && rawLawyerId != 'null') {
        counts[rawLawyerId] = (counts[rawLawyerId] ?? 0) + 1;
      }
    }

    return counts;
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 7, // All, Accepted, Active, Ongoing Cases, Pending, Rejected, Closed
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
            tabs: [
              _buildTabBadge("All Cases", "All"),
              _buildTabBadge("Accepted", "Accepted"),
              _buildTabBadge("Active", "Active"),
              _buildTabBadge("Ongoing Cases", "Ongoing Cases"),
              _buildTabBadge("Pending", "Pending"),
              _buildTabBadge("Rejected", "Rejected"),
              _buildTabBadge("Closed", "Closed"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildTabContent("All"),
            _buildTabContent("Accepted"),
            _buildTabContent("Active"),
            _buildTabContent("Ongoing Cases"),
            _buildTabContent("Pending"),
            _buildTabContent("Rejected"),
            _buildTabContent("Closed"),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBadge(String label, String statusFilter) {
    int count = 0;
    if (!_isLoading && _errorMessage == null) {
      count = _filterCases(_allCases, statusFilter).length;
    }

    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          if (count > 0) ...[
            const SizedBox(width: 6),
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
          ],
        ],
      ),
    );
  }

  Widget _buildTabContent(String statusFilter) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("Error: $_errorMessage", style: const TextStyle(color: Colors.white)),
            const SizedBox(height: 10),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: goldAccent),
              onPressed: _fetchCasesData,
              child: const Text("Retry", style: TextStyle(color: Colors.black)),
            )
          ],
        ),
      );
    }

    final filteredCases = _filterCases(_allCases, statusFilter);
    final lawyerActiveCounts = _calculateLawyerActiveCounts(_allCases);

    return RefreshIndicator(
      onRefresh: _fetchCasesData,
      color: goldAccent,
      backgroundColor: cardNavy,
      child: _buildCaseList(filteredCases, statusFilter, lawyerActiveCounts),
    );
  }

  List<Map<String, dynamic>> _filterCases(List<Map<String, dynamic>> allCases, String statusFilter) {
    return allCases.where((caseData) {
      if (statusFilter == "Ongoing Cases") {
        bool isSuitFileRequest = caseData['requestType'] == 'Suit a File Request';
        String status = (caseData['status'] ?? '').toString().toLowerCase().trim();
        return isSuitFileRequest && (status == 'accepted' || status == 'active');
      }

      // Sirf 'suit_a_file_request' collection se jiska status rejected ho
      if (statusFilter == "Rejected") {
        bool isSuitFileRequest = caseData['requestType'] == 'Suit a File Request';
        String status = (caseData['status'] ?? '').toString().toLowerCase().trim();
        return isSuitFileRequest && (status == 'rejected' || status == 'declined');
      }

      if (statusFilter == "All") return true;

      String status = (caseData['status'] ?? 'pending').toString().toLowerCase().trim();

      if (statusFilter == "Pending") {
        return status == "pending" || status == "waiting" || status == "new";
      } else if (statusFilter == "Accepted") {
        return status == "accepted";
      } else if (statusFilter == "Active") {
        return status == "active";
      } else if (statusFilter == "Closed") {
        return status == "closed" || status == "completed" || status == "finished" || status == "ended";
      }

      return status == statusFilter.toLowerCase();
    }).toList();
  }

  Widget _buildCaseList(List<Map<String, dynamic>> filteredCases, String statusFilter, Map<String, int> lawyerActiveCounts) {
    if (filteredCases.isEmpty) {
      return ListView(
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.6,
            child: Center(
              child: Text("No $statusFilter cases found", style: const TextStyle(color: Colors.white54)),
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(15),
      itemCount: filteredCases.length,
      itemBuilder: (context, index) {
        final caseData = filteredCases[index];

        String requestType = caseData['requestType'] ?? 'Case Request';
        String tagCategory = caseData['type'] ?? caseData['subCategory'] ?? requestType;
        String title;

        if (statusFilter == "Ongoing Cases") {
          title = (caseData['type'] ?? caseData['caseType'] ?? caseData['caseCategory'] ?? caseData['title'] ?? 'File a Suit').toString();
        } else if (statusFilter == "Active") {
          String caseNo = (caseData['caseNumber'] ?? caseData['caseNo'] ?? '').toString();
          String caseYear = (caseData['caseYear'] ?? caseData['year'] ?? '').toString();

          if (caseNo.isNotEmpty) {
            title = "Case #$caseNo${caseYear.isNotEmpty ? " ($caseYear)" : ""}";
          } else {
            title = (caseData['caseType'] ?? caseData['caseCategory'] ?? caseData['title'] ?? 'Untitled Case').toString();
          }
        } else {
          title = (caseData['caseType'] ?? caseData['caseCategory'] ?? caseData['title'] ?? 'Untitled Case').toString();
        }

        String client = (caseData['clientName'] ?? caseData['client'] ?? caseData['userName'] ?? 'N/A').toString();
        String rawLawyerId = (caseData['lawyerName'] ?? caseData['lawyerId'] ?? caseData['lawyerid'] ?? 'N/A').toString();

        String formattedDate = _formatDate(caseData['createdAt'] ?? caseData['timestamp'] ?? caseData['updatedAt'] ?? caseData['date']);

        String status = (caseData['status'] ?? 'Pending').toString();
        String scrapingStatus = (caseData['scrapingStatus'] ?? '').toString();

        String nextHearing = _formatDate(caseData['nextHearingDate'] ?? caseData['nextHearing']);
        String caseStage = (caseData['caseStage'] ?? caseData['stage'] ?? '').toString();
        String courtName = (caseData['courtName'] ?? caseData['court'] ?? '').toString();
        String district = (caseData['district'] ?? caseData['city'] ?? '').toString();
        String courtLocation = courtName.isNotEmpty
            ? (district.isNotEmpty ? "$courtName, $district" : courtName)
            : district;

        int activeCount = lawyerActiveCounts[rawLawyerId.trim()] ?? 0;

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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          // Request Type / Tag Category Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: goldAccent.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              tagCategory,
                              style: TextStyle(color: goldAccent, fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        if (scrapingStatus.toLowerCase() == 'synced')
                          _syncBadge("Synced"),
                        const SizedBox(width: 8),
                        _statusBadge(status),
                      ],
                    ),
                  ],
                ),
                const Divider(color: Colors.white10, height: 20),
                _infoRow(Icons.person, "Client: ", client),

                FutureBuilder<String>(
                  future: _getLawyerName(rawLawyerId),
                  builder: (context, lawyerSnapshot) {
                    if (lawyerSnapshot.connectionState == ConnectionState.waiting) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Icon(Icons.gavel, size: 16, color: goldAccent),
                            const SizedBox(width: 10),
                            const Text("Lawyer: ", style: TextStyle(color: Colors.white54, fontSize: 14)),
                            const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.white54)),
                          ],
                        ),
                      );
                    }

                    String lawyerDisplayName = lawyerSnapshot.data ?? rawLawyerId;

                    // Display Active Case Count ONLY under Active tab
                    if (statusFilter == "Active" && lawyerDisplayName != 'N/A') {
                      String countSuffix = activeCount == 1 ? "1 Case" : "$activeCount Cases";
                      lawyerDisplayName = "$lawyerDisplayName ($countSuffix)";
                    }

                    return _infoRow(Icons.gavel, "Lawyer: ", lawyerDisplayName);
                  },
                ),

                _infoRow(Icons.calendar_today, "Created: ", formattedDate),

                if (statusFilter == "Active") ...[
                  if (nextHearing != "N/A")
                    _infoRow(Icons.event, "Next Hearing: ", nextHearing),
                  if (caseStage.isNotEmpty)
                    _infoRow(Icons.alt_route, "Stage: ", caseStage),
                  if (courtLocation.isNotEmpty)
                    _infoRow(Icons.account_balance, "Court Location: ", courtLocation),
                ],

                if (scrapingStatus.isNotEmpty && scrapingStatus.toLowerCase() != 'synced')
                  _infoRow(Icons.cloud_sync, "Sync Status: ", scrapingStatus),

                const SizedBox(height: 10),

                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: goldAccent,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: goldAccent.withOpacity(0.5)),
                      ),
                    ),
                    onPressed: () => _showDetailsModal(context, caseData, formattedDate),
                    icon: const Icon(Icons.visibility_outlined, size: 16),
                    label: const Text("View Details", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showDetailsModal(BuildContext context, Map<String, dynamic> caseData, String formattedDate) {
    String title = (caseData['type'] ?? caseData['caseType'] ?? caseData['caseCategory'] ?? caseData['title'] ?? 'Untitled Case').toString();
    String requestType = caseData['requestType'] ?? 'Case Request';
    String clientName = (caseData['clientName'] ?? caseData['client'] ?? caseData['userName'] ?? 'N/A').toString();
    String clientEmail = (caseData['clientEmail'] ?? caseData['userEmail'] ?? 'N/A').toString();
    String rawLawyerId = (caseData['lawyerName'] ?? caseData['lawyerId'] ?? caseData['lawyerid'] ?? 'N/A').toString();
    String status = (caseData['status'] ?? 'Pending').toString();
    String description = (caseData['description'] ?? caseData['details'] ?? caseData['notes'] ?? 'No description provided.').toString();
    String documentUrl = (caseData['documentUrl'] ?? caseData['agreementUrl'] ?? caseData['fileUrl'] ?? '').toString();

    showModalBottomSheet(
      context: context,
      backgroundColor: cardNavy,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            top: 20,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 15),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(title, style: TextStyle(color: goldAccent, fontSize: 20, fontWeight: FontWeight.bold)),
                    ),
                    _statusBadge(status),
                  ],
                ),
                const Divider(color: Colors.white10, height: 25),

                _modalSectionTitle("Case Overview"),
                _modalDetailRow("Request Type", requestType),
                _modalDetailRow("Created Date", formattedDate),
                _modalDetailRow("Case Status", status),

                const SizedBox(height: 12),
                _modalSectionTitle("Client Information"),
                _modalDetailRow("Name", clientName),
                if (clientEmail != 'N/A') _modalDetailRow("Email", clientEmail),

                const SizedBox(height: 12),
                _modalSectionTitle("Lawyer Information"),
                FutureBuilder<String>(
                  future: _getLawyerName(rawLawyerId),
                  builder: (context, snapshot) {
                    return _modalDetailRow("Assigned Lawyer", snapshot.data ?? rawLawyerId);
                  },
                ),

                const SizedBox(height: 12),
                _modalSectionTitle("Case Description"),
                Text(
                  description,
                  style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                ),

                if (documentUrl.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _modalSectionTitle("Documents & Agreements"),
                  InkWell(
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Document: $documentUrl"), behavior: SnackBarBehavior.floating),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: navyBackground,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: goldAccent.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.insert_drive_file, color: goldAccent, size: 20),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              "View Attached Case Document",
                              style: TextStyle(color: Colors.white, fontSize: 13, decoration: TextDecoration.underline),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Icon(Icons.open_in_new, color: goldAccent, size: 16),
                        ],
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: navyBackground,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Close", style: TextStyle(color: Colors.white)),
                  ),
                )
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _modalSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(title, style: TextStyle(color: goldAccent, fontSize: 14, fontWeight: FontWeight.bold)),
    );
  }

  Widget _modalDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text("$label:", style: const TextStyle(color: Colors.white54, fontSize: 13)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  Widget _syncBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.green.withAlpha(40),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.green, width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle, size: 10, color: Colors.green),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _statusBadge(String status) {
    Color badgeColor;
    String s = status.toLowerCase();
    if (s == "active") badgeColor = Colors.green;
    else if (s == "accepted") badgeColor = Colors.blue;
    else if (s == "pending") badgeColor = Colors.orange;
    else if (s == "rejected" || s == "declined") badgeColor = Colors.red;
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