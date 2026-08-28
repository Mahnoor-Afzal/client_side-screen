import 'package:flutter/material.dart';
import 'firestore_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class VerifyLawyers extends StatefulWidget {
  const VerifyLawyers({super.key});

  @override
  State<VerifyLawyers> createState() => _VerifyLawyersState();
}

class _VerifyLawyersState extends State<VerifyLawyers> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color navyBackground = Color(0xFF0F172A);
    const Color goldAccent = Color(0xFFC7A15E);
    const Color cardNavy = Color(0xFF1E293B);

    return Scaffold(
      backgroundColor: navyBackground,
      appBar: AppBar(
        backgroundColor: cardNavy,
        elevation: 0,
        iconTheme: const IconThemeData(color: goldAccent),
        title: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('lawyers').snapshots(),
          builder: (context, snapshot) {
            int count = snapshot.hasData ? snapshot.data!.docs.length : 0;
            return Row(
              children: [
                const Text(
                  "Verify Lawyers",
                  style: TextStyle(color: goldAccent, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: goldAccent.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: goldAccent.withOpacity(0.5), width: 1),
                  ),
                  child: Text(
                    "$count",
                    style: const TextStyle(
                      color: goldAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
      body: Column(
        children: [
          // Search Bar Implementation
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
            color: cardNavy,
            child: TextField(
              controller: _searchController,
              onChanged: (val) {
                setState(() {
                  _searchQuery = val.toLowerCase().trim();
                });
              },
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Search by Name, Email or Specialization...",
                hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                prefixIcon: const Icon(Icons.search, color: goldAccent),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.white38),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                    });
                  },
                )
                    : null,
                filled: true,
                fillColor: navyBackground,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(child: _buildLawyerList(context)),
        ],
      ),
    );
  }

  Widget _buildLawyerList(BuildContext context) {
    const String collection = 'lawyers';
    const Color goldAccent = Color(0xFFC7A15E);
    const Color cardNavy = Color(0xFF1E293B);

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(collection)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: goldAccent));
        }

        if (snapshot.hasError) {
          if (snapshot.error.toString().contains('index')) {
            return Center(child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Text("Sorting error: Please create a Firestore index for 'createdAt' in $collection collection.\n\n${snapshot.error}",
                  style: const TextStyle(color: Colors.redAccent, fontSize: 12), textAlign: TextAlign.center),
            ));
          }
          return Center(child: Text("Error: ${snapshot.error}", style: const TextStyle(color: Colors.white)));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("No pending lawyer requests found",
              style: TextStyle(color: Colors.white54)));
        }

        // Search Filter Logic (Name, Email, Specialization)
        var filteredDocs = snapshot.data!.docs.where((doc) {
          var data = doc.data() as Map<String, dynamic>;
          String name = (data['name'] ?? data['fullName'] ?? '').toString().toLowerCase();
          String email = (data['email'] ?? '').toString().toLowerCase();
          String specialization = (data['specialization'] ?? data['speciality'] ?? '').toString().toLowerCase();

          return name.contains(_searchQuery) ||
              email.contains(_searchQuery) ||
              specialization.contains(_searchQuery);
        }).toList();

        // Secondary fallback sort to strictly guarantee newest requests are on top
        filteredDocs.sort((a, b) {
          var aData = a.data() as Map<String, dynamic>;
          var bData = b.data() as Map<String, dynamic>;

          final aTime = aData['createdAt'] ?? aData['timestamp'] ?? aData['registeredAt'] ?? aData['requestedAt'];
          final bTime = bData['createdAt'] ?? bData['timestamp'] ?? bData['registeredAt'] ?? bData['requestedAt'];

          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1;
          if (bTime == null) return -1;

          if (aTime is Timestamp && bTime is Timestamp) {
            return bTime.compareTo(aTime);
          }
          return 0;
        });

        if (filteredDocs.isEmpty) {
          return const Center(
            child: Text("No lawyer matching your search criteria",
                style: TextStyle(color: Colors.white54)),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(15),
          itemCount: filteredDocs.length,
          itemBuilder: (context, index) {
            var doc = filteredDocs[index];
            var data = doc.data() as Map<String, dynamic>;
            data['id'] = doc.id;

            return Card(
              color: cardNavy,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                leading: CircleAvatar(
                    backgroundColor: goldAccent.withOpacity(0.1),
                    child: const Icon(Icons.gavel, color: goldAccent)
                ),
                title: Text((data['name'] ?? data['fullName'] ?? 'Unknown').toString(),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: Text((data['specialization'] ?? data['speciality'] ?? 'Legal Consultant').toString(),
                    style: const TextStyle(color: Colors.white54, fontSize: 12)),
                trailing: const Icon(Icons.arrow_forward_ios, color: goldAccent, size: 16),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => LawyerProfileView(lawyer: data, isVerified: false)),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class LawyerProfileView extends StatefulWidget {
  final Map<String, dynamic> lawyer;
  final bool isVerified;
  const LawyerProfileView({super.key, required this.lawyer, required this.isVerified});

  @override
  State<LawyerProfileView> createState() => _LawyerProfileViewState();
}

class _LawyerProfileViewState extends State<LawyerProfileView> {
  bool _isLoading = false;
  final FirestoreService _firestore = FirestoreService();

  final Color navyBackground = const Color(0xFF0F172A);
  final Color goldAccent = const Color(0xFFC7A15E);
  final Color cardNavy = const Color(0xFF1E293B);

  String? _findDoc(List<String> keywords) {
    for (var entry in widget.lawyer.entries) {
      String key = entry.key.toLowerCase();
      for (var word in keywords) {
        if (key.contains(word.toLowerCase()) && entry.value.toString().startsWith('http')) {
          return entry.value.toString();
        }
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.lawyer;

    return Scaffold(
      backgroundColor: navyBackground,
      appBar: AppBar(
          backgroundColor: cardNavy,
          iconTheme: IconThemeData(color: goldAccent),
          title: Text(widget.isVerified ? "Verified Lawyer Profile" : "Verification Details",
              style: TextStyle(color: goldAccent, fontSize: 18))
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.isVerified)
                  _buildStatusBadge(),

                _sectionHeader("Personal Information"),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(color: cardNavy, borderRadius: BorderRadius.circular(15)),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            _row("Full Name", l['name'] ?? l['fullName']),
                            _row("Email", l['email']),
                            _row("Phone", l['phone'] ?? l['phoneNumber']),
                            _row("Location", (l['area'] != null || l['province'] != null)
                                ? "${l['area'] ?? ''}, ${l['province'] ?? ''}"
                                : (l['city'] ?? l['location'])),
                          ],
                        ),
                      ),
                      const SizedBox(width: 15),
                      // Circular Profile Avatar with interactive Zoom
                      GestureDetector(
                        onTap: (l['profileImageUrl'] != null && l['profileImageUrl'].toString().isNotEmpty)
                            ? () => _showZoom(l['profileImageUrl'].toString(), "Profile Image")
                            : null,
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: goldAccent.withOpacity(0.5), width: 2),
                          ),
                          child: ClipOval(
                            child: l['profileImageUrl'] != null && l['profileImageUrl'].toString().isNotEmpty
                                ? Image.network(
                              l['profileImageUrl'].toString(),
                              width: 100,
                              height: 100,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Container(
                                color: goldAccent.withOpacity(0.1),
                                child: Icon(Icons.person, color: goldAccent, size: 50),
                              ),
                            )
                                : Container(
                              color: goldAccent.withOpacity(0.1),
                              child: Icon(Icons.person, color: goldAccent, size: 50),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 25),
                _sectionHeader("Professional Details"),
                _infoCard([
                  _row("Specialization", l['specialization'] ?? l['speciality']),
                  _row("Experience", "${l['experience'] ?? '0'} Years"),
                  _row("License ID", l['licenseId'] ?? l['barCouncilNo'] ?? l['barRegistrationNumber'] ?? l['licenseNo']),
                  _row("CNIC Number", l['cnic'] ?? l['cnicNumber'] ?? l['cnicNo']),
                  _row("Transaction ID", l['transactionId'] ?? l['txn_id']),
                ]),

                const SizedBox(height: 25),
                _sectionHeader("Verification Documents"),
                _docTile("CNIC Front Side", _findDoc(['cnicFront', 'cnic_front', 'cnicf'])),
                _docTile("CNIC Back Side", _findDoc(['cnicBack', 'cnic_back', 'cnicb'])),
                _docTile("Lawyer License (Front Side)", l['licenseFrontUrl'] ?? _findDoc(['licensefront', 'license_front'])),
                _docTile("Lawyer License (Back Side)", l['licenseBackUrl'] ?? _findDoc(['licenseback', 'license_back'])),
                _docTile("Fee Payment Receipt", _findDoc(['payment', 'receipt', 'fee', 'screenshot'])),

                const SizedBox(height: 100),
              ],
            ),
          ),
          if (_isLoading)
            Container(color: Colors.black54, child: const Center(child: CircularProgressIndicator(color: Colors.amber))),
        ],
      ),
      bottomSheet: _buildActionButtons(),
    );
  }

  Widget _buildStatusBadge() {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.1),
          border: Border.all(color: Colors.green.withOpacity(0.5)),
          borderRadius: BorderRadius.circular(12)
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.verified, color: Colors.green, size: 20),
          SizedBox(width: 10),
          Text("OFFICIALLY VERIFIED", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, letterSpacing: 1)),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Container(
      color: navyBackground,
      padding: const EdgeInsets.all(20),
      child: widget.isVerified
          ? ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
            backgroundColor: Colors.redAccent.withOpacity(0.8),
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
        ),
        icon: const Icon(Icons.block, color: Colors.white),
        onPressed: () => _showRejectDialog(isRevoking: true),
        label: const Text("Revoke Access / Suspend", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      )
          : Row(
        children: [
          Expanded(
              child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.redAccent),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                  ),
                  onPressed: () => _showRejectDialog(isRevoking: false),
                  child: const Text("Reject", style: TextStyle(color: Colors.redAccent))
              )
          ),
          const SizedBox(width: 15),
          Expanded(
              child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                  ),
                  onPressed: _handleAccept,
                  child: const Text("Accept & Verify", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
              )
          ),
        ],
      ),
    );
  }

  Future<void> _handleAccept() async {
    setState(() => _isLoading = true);
    try {
      Map<String, dynamic> data = Map.from(widget.lawyer);
      data['verificationStatus'] = 'approved';
      data['isVerified'] = true;
      data['verifiedAt'] = FieldValue.serverTimestamp();

      await _firestore.approveLawyer(widget.lawyer['id'], data);

      await FirebaseFirestore.instance.collection('notifications').add({
        'userId': widget.lawyer['id'],
        'title': 'Verification Successful',
        'body': 'Your lawyer account has been verified. You can now take cases.',
        'type': 'verification',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showRejectDialog({required bool isRevoking}) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardNavy,
        title: Text(isRevoking ? "Revoke Access" : "Reject Lawyer", style: const TextStyle(color: Colors.redAccent)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: "Enter reason...",
            hintStyle: TextStyle(color: Colors.white24),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              final reasonText = controller.text.trim();
              Navigator.pop(ctx);
              _handleReject(reasonText, isRevoking);
            },
            child: const Text("Confirm", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  Future<void> _handleReject(String reason, bool isRevoking) async {
    setState(() => _isLoading = true);
    try {
      String lawyerId = widget.lawyer['id'].toString();
      String col = widget.isVerified ? 'verified_lawyers' : 'lawyers';
      String reasonInputText = reason.isEmpty ? 'No reason provided' : reason;

      // 1. Update the specified collection (lawyers or verified_lawyers)
      await FirebaseFirestore.instance.collection(col).doc(lawyerId).set({
        'status': 'rejected',
        'verificationStatus': 'rejected',
        'rejectionReason': reasonInputText,
        'isApproved': false,
        'isVerified': false,
      }, SetOptions(merge: true));

      // 2. Update corresponding admin_requests collection
      try {
        final adminReqDoc = await FirebaseFirestore.instance.collection('admin_requests').doc(lawyerId).get();
        if (adminReqDoc.exists) {
          await FirebaseFirestore.instance.collection('admin_requests').doc(lawyerId).update({
            'status': 'rejected',
            'rejectionReason': reasonInputText,
          });
        } else {
          final querySnap = await FirebaseFirestore.instance
              .collection('admin_requests')
              .where('lawyerId', isEqualTo: lawyerId)
              .get();

          for (var doc in querySnap.docs) {
            await doc.reference.update({
              'status': 'rejected',
              'rejectionReason': reasonInputText,
            });
          }
        }
      } catch (e) {
        debugPrint("Note: admin_requests update skipped or encountered: $e");
      }

      // 3. Send Notification
      await FirebaseFirestore.instance.collection('notifications').add({
        'lawyerId': lawyerId,
        'userId': lawyerId,
        'title': 'Verification Application Update',
        'message': 'Your verification request was rejected. Reason: $reasonInputText',
        'type': 'verification_rejected',
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Lawyer rejection updated successfully across all collections."))
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error updating rejection: $e")));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _sectionHeader(String title) => Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 5),
      child: Text(title.toUpperCase(), style: TextStyle(color: goldAccent, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1))
  );

  Widget _infoCard(List<Widget> children) => Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: cardNavy, borderRadius: BorderRadius.circular(15)),
      child: Column(children: children)
  );

  Widget _row(String label, dynamic val) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 130, child: Text("$label:", style: const TextStyle(color: Colors.white38, fontSize: 13))),
            Expanded(child: Text(val?.toString() ?? 'N/A', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500))),
          ]
      )
  );

  Widget _docTile(String label, String? url) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    decoration: BoxDecoration(color: cardNavy, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withOpacity(0.05))),
    child: ListTile(
      title: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
      trailing: url != null
          ? const Icon(Icons.zoom_in, color: Colors.blueAccent)
          : const Text("Not Found", style: TextStyle(color: Colors.white24, fontSize: 11)),
      onTap: url != null ? () => _showZoom(url, label) : null,
    ),
  );

  void _showZoom(String url, String title) {
    showDialog(context: context, builder: (_) => Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: Column(children: [
        AppBar(
            backgroundColor: Colors.black,
            title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 16)),
            leading: IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context))
        ),
        Expanded(child: InteractiveViewer(child: Image.network(url, fit: BoxFit.contain,
            errorBuilder: (c, e, s) => const Center(child: Text("Error loading image", style: TextStyle(color: Colors.white54)))))),
      ]),
    ));
  }
}