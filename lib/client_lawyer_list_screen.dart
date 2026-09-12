import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'client_notification_helper.dart';
import 'client_lawyer_profile_screen.dart';
import 'client_dashboard.dart';

class LawyerListScreen extends StatefulWidget {
  final String? specializationFilter;
  final String? stateFilter;
  final Map<String, dynamic>? aiAnalysis;
  final Map<String, dynamic>? pendingCaseData;

  const LawyerListScreen({
    super.key, 
    this.specializationFilter, 
    this.stateFilter,
    this.aiAnalysis, 
    this.pendingCaseData
  });

  @override
  State<LawyerListScreen> createState() => _LawyerListScreenState();
}

class _LawyerListScreenState extends State<LawyerListScreen> {
  static const Color navyBlue = Color(0xFF001F3F);
  static const Color accentGold = Color(0xFFD4AF37);
  
  late TextEditingController _searchController;
  late String _searchQuery;
  bool _showSuccess = false;

  @override
  void initState() {
    super.initState();
    // We don't pre-fill _searchQuery with the specialization filter to avoid 
    // over-restricting the results. The auto-filter logic handles this below.
    _searchQuery = "";
    _searchController = TextEditingController();
  }
  String _safeString(dynamic value, {String defaultValue = ""}) {
    if (value == null) return defaultValue;
    if (value is List) return value.join(", ");
    return value.toString();
  }

  @override
  Widget build(BuildContext context) {
    if (_showSuccess) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: const Text("CASE SUBMITTED", style: TextStyle(color: navyBlue, fontSize: 16, fontWeight: FontWeight.bold)),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: navyBlue),
            onPressed: () => setState(() => _showSuccess = false),
          ),
        ),
        body: _buildSuccessView(),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: navyBlue,
        elevation: 0,
        title: const Text("Legal Experts", style: TextStyle(color: accentGold, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('verified_lawyers')
                  .snapshots(includeMetadataChanges: true), // Ensure it reacts to cache vs server
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: navyBlue));
                }

                if (snapshot.hasError) {
                  // Specific fix for IndexedDB errors on Web
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red, size: 40),
                          const SizedBox(height: 10),
                          Text(
                            "Connection Error: ${snapshot.error}",
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.red),
                          ),
                          const SizedBox(height: 10),
                          ElevatedButton(
                            onPressed: () => setState(() {}),
                            child: const Text("Retry"),
                          )
                        ],
                      ),
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildEmptyState();
                }

                // 3. Convert to a list of Maps for sorting and display
                List<Map<String, dynamic>> sortedLawyers = snapshot.data!.docs.map((doc) {
                  return {
                    'id': doc.id,
                    'data': doc.data() as Map<String, dynamic>,
                  };
                }).where((item) {
                  final data = item['data'] as Map<String, dynamic>;
                  
                  // 1. Filter out blocked lawyers
                  bool isBlocked = data['isBlocked'] == true || 
                                   data['status'] == 'Blocked' || 
                                   data['status'] == 'blocked';
                  if (isBlocked) return false;

                  // 2. Search & Auto-Filter Logic
                  String name = _safeString(data['fullName'] ?? data['name'] ?? data['organizationName']).toLowerCase();
                  String spec = _safeString(data['specialization']).toLowerCase();
                  String province = _safeString(data['province'] ?? data['location']).toLowerCase();

                  // Auto-filter from CreateCaseScreen (Match State and Case Type)
                  if (widget.stateFilter != null && widget.stateFilter!.isNotEmpty) {
                    // Match State (e.g., 'Punjab')
                    if (!province.contains(widget.stateFilter!.toLowerCase())) return false;
                  }
                  
                  if (widget.specializationFilter != null && widget.specializationFilter!.isNotEmpty) {
                    // Match Case Type Keyword (e.g., 'Family' from 'Family Issues')
                    // We take the first word to ensure broader matching with lawyer specializations
                    String filterKeyword = widget.specializationFilter!.toLowerCase().split(' ').first;
                    if (!spec.contains(filterKeyword)) return false;
                  }
                  
                  // Search bar filter
                  if (_searchQuery.isNotEmpty) {
                    return name.contains(_searchQuery.toLowerCase()) || 
                           spec.contains(_searchQuery.toLowerCase()) ||
                           province.contains(_searchQuery.toLowerCase());
                  }
                  
                  return true;
                }).toList();

                // Sort by rating descending
                sortedLawyers.sort((a, b) {
                  final dataA = a['data'] as Map<String, dynamic>;
                  final dataB = b['data'] as Map<String, dynamic>;
                  double ratingA = double.tryParse((dataA['rating'] ?? '0').toString()) ?? 0.0;
                  double ratingB = double.tryParse((dataB['rating'] ?? '0').toString()) ?? 0.0;
                  return ratingB.compareTo(ratingA);
                });

                if (sortedLawyers.isEmpty) {
                  return _buildEmptyState();
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  itemCount: sortedLawyers.length,
                  itemBuilder: (context, index) {
                    final lawyerItem = sortedLawyers[index];
                    return _buildLawyerCard(
                      lawyerItem['data'] as Map<String, dynamic>, 
                      lawyerItem['id'] as String,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 100),
            const SizedBox(height: 20),
            const Text(
              "Case Submitted!",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: navyBlue),
            ),
            const SizedBox(height: 10),
            const Text(
              "Your case has been successfully registered. Now you can find a legal expert to help you.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _showSuccess = false;
                  });
                },
                icon: const Icon(Icons.search, color: Colors.white),
                label: const Text("SEARCH LAWYER", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentGold,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const DashboardScreen()),
                  (route) => false,
                );
              },
              child: const Text(
                "Go Back to Dashboard",
                style: TextStyle(color: navyBlue, fontWeight: FontWeight.w600),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(15),
      color: navyBlue,
      child: TextField(
        controller: _searchController,
        style: const TextStyle(color: Colors.white),
        onChanged: (value) => setState(() => _searchQuery = value),
        decoration: InputDecoration(
          hintText: "Search by name or specialization...",
          hintStyle: const TextStyle(color: Colors.white54),
          prefixIcon: const Icon(Icons.search, color: accentGold),
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.1),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildLawyerCard(Map<String, dynamic> lawyer, String lawyerId) {
    // Debugging: This will print the exact data from Firestore in your console
    debugPrint("Lawyer Data for $lawyerId: $lawyer");

    // Using field names seen in your Firestore screenshot
    String name = _safeString(lawyer['fullName'] ?? lawyer['name'] ?? lawyer['organizationName'], defaultValue: "Advocate");
    String spec = _safeString(lawyer['specialization'], defaultValue: "Legal Expert");
    String exp = _safeString(lawyer['experience'], defaultValue: "0");
    String org = _safeString(lawyer['organizationName'] ?? lawyer['organization'], defaultValue: "Independent Practice");
    String license = _safeString(lawyer['licenseType'], defaultValue: "Advocate");
    String province = _safeString(lawyer['province'], defaultValue: "Location N/A");
    String description = _safeString(lawyer['description'] ?? lawyer['bio'], defaultValue: "Expert legal practitioner providing professional services.");
    
    // Rating logic
    double rating = double.tryParse((lawyer['rating'] ?? '0').toString()) ?? 0.0;
    int reviewCount = int.tryParse((lawyer['reviewCount'] ?? '0').toString()) ?? 0;

    // Robust image detection logic
    dynamic profilePicData = lawyer['profilePicture'] ?? 
                             lawyer['profile_picture'] ??
                             lawyer['profileImage'] ??
                             lawyer['profile_image'] ??
                             lawyer['profilePic'] ??
                             lawyer['profile_pic'] ??
                             lawyer['profileImageUrl'] ??
                             lawyer['imageUrl'] ?? 
                             lawyer['image'] ?? 
                             lawyer['photoUrl'] ??
                             lawyer['avatar'];
    
    ImageProvider? imageProvider;
    if (profilePicData != null) {
      if (profilePicData is String && profilePicData.trim().isNotEmpty) {
        String imgStr = profilePicData.trim();
        if (imgStr.startsWith('http')) {
          imageProvider = NetworkImage(imgStr);
        } else {
          try {
            // Clean Base64 prefix and remove whitespace
            String cleanBase64 = imgStr.contains(',') ? imgStr.split(',').last : imgStr;
            cleanBase64 = cleanBase64.replaceAll(RegExp(r'\s+'), '');
            
            // Fix padding if needed
            int padLength = cleanBase64.length % 4;
            if (padLength > 0) {
              cleanBase64 += '=' * (4 - padLength);
            }
            
            imageProvider = MemoryImage(base64Decode(cleanBase64));
          } catch (e) {
            debugPrint("Failed to decode image for $lawyerId: $e");
          }
        }
      } else if (profilePicData is Uint8List) {
        imageProvider = MemoryImage(profilePicData);
      }
    }
    
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => LawyerProfileScreen(lawyer: lawyer, lawyerId: lawyerId)));
            },
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: navyBlue.withValues(alpha: 0.1), width: 2),
                    ),
                    child: CircleAvatar(
                      radius: 35,
                      backgroundColor: Colors.grey[200],
                      backgroundImage: imageProvider,
                      child: imageProvider == null 
                        ? const Icon(Icons.person, size: 40, color: navyBlue) 
                        : null,
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                name,
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: navyBlue),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(Icons.verified, color: Colors.blue, size: 18),
                          ],
                        ),
                        Text(spec, style: const TextStyle(color: accentGold, fontWeight: FontWeight.w600, fontSize: 14)),
                        const SizedBox(height: 4),
                        Text(org, style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Row(
                  children: [
                    _buildInfoChip(Icons.gavel, license),
                    const SizedBox(width: 8),
                    _buildInfoChip(Icons.location_on, province),
                    const SizedBox(width: 8),
                    _buildInfoChip(Icons.history, "$exp Years Exp"),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.star, color: Colors.amber, size: 20),
                    const SizedBox(width: 4),
                    Text(
                      rating.toStringAsFixed(1),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Text(
                      " ($reviewCount Engaged Clients)",
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.black87.withValues(alpha: 0.7), fontSize: 13, height: 1.4),
                ),
                const Divider(height: 30),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _handleRequest(lawyerId, name, "Consultation"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentGold,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                        child: const Text("Consultation", style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _handleRequest(lawyerId, name, "File a Suit"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: navyBlue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                        child: const Text("File a Suit", style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => LawyerProfileScreen(lawyer: lawyer, lawyerId: lawyerId)));
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: navyBlue,
                      side: const BorderSide(color: navyBlue),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text("View Full Profile"),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: navyBlue),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 12, color: navyBlue, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  void _handleRequest(String lawyerId, String lawyerName, String type) async {
    String? currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    try {
      // Check if a request already exists for this lawyer
      var consultQuery = await FirebaseFirestore.instance
          .collection('consultation_request')
          .where('clientId', isEqualTo: currentUserId)
          .where('lawyerId', isEqualTo: lawyerId)
          .get();

      var suitQuery = await FirebaseFirestore.instance
          .collection('suit_a_file_request')
          .where('clientId', isEqualTo: currentUserId)
          .where('lawyerId', isEqualTo: lawyerId)
          .get();

      bool alreadyExists = false;
      for (var doc in [...consultQuery.docs, ...suitQuery.docs]) {
        String status = (doc['status'] ?? '').toString().toLowerCase();
        if (['pending', 'accepted', 'active', 'in progress'].contains(status)) {
          alreadyExists = true;
          break;
        }
      }

      if (alreadyExists) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("You have already sent a request to this lawyer."),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUserId).get();
      String clientName = _safeString((userDoc.data() as Map<String, dynamic>?)?['name'], defaultValue: "Client");

      String collectionName = type == 'Consultation' ? 'consultation_request' : 'suit_a_file_request';

      // 1. Create the Request in specific collection
      Map<String, dynamic> requestData = {
        'clientId': currentUserId,
        'lawyerId': lawyerId, // Saving the selected lawyer's ID
        'status': 'Pending',
        'createdAt': FieldValue.serverTimestamp(),
        'clientName': clientName,
        'lawyerName': lawyerName,
        'type': type,
        'aiAnalysis': widget.aiAnalysis,
        'isDirectRequest': true, // It is direct because client chose this specific lawyer
      };

      // If we have pending case data from CreateCaseScreen (Dashboard flow), merge it
      if (widget.pendingCaseData != null) {
        requestData.addAll(widget.pendingCaseData!);
      }

      DocumentReference requestRef = await FirebaseFirestore.instance
          .collection(collectionName)
          .add(requestData);

      // 2. Send Notification to Lawyer (Firestore entry for Dashboard)
      await FirebaseFirestore.instance.collection('notifications').add({
        'userId': lawyerId,
        'title': 'New $type Request',
        'body': '$clientName has sent you a $type request with AI Analysis.',
        'createdAt': FieldValue.serverTimestamp(),
        'requestId': requestRef.id,
        'requestCollection': collectionName,
        'type': 'request_received',
        'isRead': false,
      });

      // 3. Push Notification (FCM)
      await NotificationHelper.sendPushNotification(
        lawyerId,
        "New $type Request",
        "$clientName has sent you a $type request.",
        {
          'click_action': 'FLUTTER_NOTIFICATION_CLICK',
          'type': 'request_received',
          'requestId': requestRef.id,
          'requestCollection': collectionName,
        },
      );

      if (!mounted) return;
      setState(() {
        _showSuccess = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Request sent to $lawyerName"), backgroundColor: Colors.green));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_search, size: 80, color: navyBlue.withValues(alpha: 0.2)),
          const SizedBox(height: 20),
          const Text("No verified lawyers found", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: navyBlue)),
          const SizedBox(height: 10),
          const Text("Check back later or try a different search.", style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}
