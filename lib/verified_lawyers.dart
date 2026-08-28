import 'package:flutter/material.dart';
import 'firestore_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class VerifiedLawyers extends StatelessWidget {
  const VerifiedLawyers({super.key});

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
          // Stream filter updated to exclude suspended lawyers from count badge
            stream: FirebaseFirestore.instance
                .collection('verified_lawyers')
                .where('status', isNotEqualTo: 'suspended')
                .snapshots(),
            builder: (context, snapshot) {
              int count = snapshot.hasData ? snapshot.data!.docs.length : 0;
              return Row(
                children: [
                  const Text("Verified Lawyers",
                      style: TextStyle(color: goldAccent, fontWeight: FontWeight.bold)),
                  if (count > 0) ...[
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: goldAccent.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: goldAccent.withOpacity(0.5)),
                      ),
                      child: Text(count.toString(),
                          style: const TextStyle(color: goldAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ],
              );
            }
        ),
      ),
      body: _buildLawyerList(context),
    );
  }

  Widget _buildLawyerList(BuildContext context) {
    const String collection = 'verified_lawyers';
    const Color goldAccent = Color(0xFFC7A15E);
    const Color cardNavy = Color(0xFF1E293B);

    return StreamBuilder<QuerySnapshot>(
      // Firestore query updated to remove .orderBy to fix index error
      stream: FirebaseFirestore.instance
          .collection(collection)
          .where('status', isNotEqualTo: 'suspended')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: goldAccent));
        }

        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}", style: const TextStyle(color: Colors.white)));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("No verified lawyers found",
              style: TextStyle(color: Colors.white54)));
        }

        // Make a mutable copy of docs and sort in-memory in Dart
        final docs = List<QueryDocumentSnapshot>.from(snapshot.data!.docs);
        docs.sort((a, b) {
          var dataA = a.data() as Map<String, dynamic>;
          var dataB = b.data() as Map<String, dynamic>;

          dynamic dateAVal = dataA['createdAt'];
          dynamic dateBVal = dataB['createdAt'];

          if (dateAVal == null) return 1;
          if (dateBVal == null) return -1;

          try {
            return (dateBVal as dynamic).compareTo(dateAVal as dynamic);
          } catch (_) {
            return 0;
          }
        });

        return ListView.builder(
          padding: const EdgeInsets.all(15),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            var doc = docs[index];
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
                    child: const Icon(Icons.verified, color: Colors.blue)
                ),
                title: Text((data['name'] ?? data['fullName'] ?? 'Unknown').toString(),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: Text((data['specialization'] ?? 'Legal Consultant').toString(),
                    style: const TextStyle(color: Colors.white54, fontSize: 12)),
                trailing: const Icon(Icons.arrow_forward_ios, color: goldAccent, size: 16),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => VerifiedLawyerProfileDetailsView(lawyer: data)),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class VerifiedLawyerProfileDetailsView extends StatefulWidget {
  final Map<String, dynamic> lawyer;
  const VerifiedLawyerProfileDetailsView({super.key, required this.lawyer});

  @override
  State<VerifiedLawyerProfileDetailsView> createState() => _VerifiedLawyerProfileDetailsViewState();
}

class _VerifiedLawyerProfileDetailsViewState extends State<VerifiedLawyerProfileDetailsView> {
  bool _isLoading = false;

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
        title: Text("Verified Lawyer Profile", style: TextStyle(color: goldAccent, fontSize: 18)),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                            _row("Email", l['email']),
                            _row("Phone", l['phone'] ?? l['phoneNumber']),
                            _row("Location", (l['area'] != null || l['province'] != null)
                                ? "${l['area'] ?? ''}, ${l['province'] ?? ''}"
                                : (l['city'] ?? l['location'])),
                          ],
                        ),
                      ),
                      const SizedBox(width: 15),
                      GestureDetector(
                        onTap: (l['profileImageUrl'] != null && l['profileImageUrl'].toString().isNotEmpty)
                            ? () => _showZoom(l['profileImageUrl'].toString(), "Profile Image")
                            : null,
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: goldAccent.withOpacity(0.5), width: 2),
                          ),
                          child: ClipOval(
                            child: l['profileImageUrl'] != null && l['profileImageUrl'].toString().isNotEmpty
                                ? Image.network(
                              l['profileImageUrl'].toString(),
                              width: 80,
                              height: 80,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Container(
                                color: goldAccent.withOpacity(0.1),
                                child: Icon(Icons.person, color: goldAccent, size: 40),
                              ),
                            )
                                : Container(
                              color: goldAccent.withOpacity(0.1),
                              child: Icon(Icons.person, color: goldAccent, size: 40),
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
                _docTile("Lawyer License (Front Side)", l['licenseFrontUrl'] ?? _findDoc(['licensefront', 'license_back'])),
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
      bottomSheet: Container(
        color: navyBackground,
        padding: const EdgeInsets.all(20),
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent.withOpacity(0.8),
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
          ),
          icon: const Icon(Icons.block, color: Colors.white),
          onPressed: _showBlockDialog,
          label: const Text("Block / Suspend Account", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  void _showBlockDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardNavy,
        title: const Text("Block / Suspend Account", style: TextStyle(color: Colors.redAccent)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: "Enter block/suspension reason...",
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
              _handleBlockLawyer(reasonText);
            },
            child: const Text("Block", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  Future<void> _handleBlockLawyer(String reason) async {
    setState(() => _isLoading = true);
    try {
      String uid = widget.lawyer['id'].toString();
      String reasonText = reason.isEmpty ? 'Blocked by admin' : reason;

      // 1. Update verified_lawyers collection document
      await FirebaseFirestore.instance.collection('verified_lawyers').doc(uid).set({
        'status': 'suspended',
        'verificationStatus': 'suspended',
        'isBlocked': true,
        'blockReason': reasonText,
      }, SetOptions(merge: true));

      // 2. Update users collection document
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'isBlocked': true,
        'status': 'blocked',
        'blockReason': reasonText,
      }, SetOptions(merge: true));

      // 3. Update lawyers collection document
      await FirebaseFirestore.instance.collection('lawyers').doc(uid).set({
        'isBlocked': true,
        'status': 'suspended',
        'verificationStatus': 'suspended',
        'isVerified': false,
        'blockReason': reasonText,
      }, SetOptions(merge: true));

      // 4. Send Notification
      await FirebaseFirestore.instance.collection('notifications').add({
        'userId': uid,
        'lawyerId': uid,
        'title': 'Account Suspended',
        'message': 'Your account has been blocked/suspended. Reason: $reasonText',
        'type': 'account_blocked',
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Account blocked and suspended successfully."))
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error blocking account: $e")));
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
            SizedBox(width: 110, child: Text("$label:", style: const TextStyle(color: Colors.white38, fontSize: 13))),
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