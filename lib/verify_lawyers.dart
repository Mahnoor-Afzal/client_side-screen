import 'package:flutter/material.dart';
import 'firestore_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class VerifyLawyers extends StatelessWidget {
  const VerifyLawyers({super.key});

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
        title: const Text("Verify Lawyers", 
          style: TextStyle(color: goldAccent, fontWeight: FontWeight.bold)),
      ),
      body: _buildLawyerList(context),
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

        return ListView.builder(
          padding: const EdgeInsets.all(15),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var doc = snapshot.data!.docs[index];
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
                subtitle: Text((data['specialization'] ?? 'Legal Consultant').toString(), 
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
                _infoCard([
                  _row("Full Name", l['name'] ?? l['fullName']),
                  _row("Email", l['email']),
                  _row("Phone", l['phone'] ?? l['phoneNumber']),
                  _row("City / Prov", "${l['city'] ?? 'N/A'}, ${l['province'] ?? 'N/A'}"),
                ]),

                const SizedBox(height: 25),
                _sectionHeader("Professional Details"),
                _infoCard([
                  _row("Specialization", l['specialization'] ?? l['speciality']),
                  _row("Experience", "${l['experience'] ?? '0'} Years"),
                  _row("Bar Council #", l['barRegistrationNumber'] ?? l['licenseNo']),
                ]),

                const SizedBox(height: 25),
                _sectionHeader("Verification Documents"),
                _docTile("CNIC Front Side", _findDoc(['cnicFront', 'cnic_front', 'cnicf'])),
                _docTile("CNIC Back Side", _findDoc(['cnicBack', 'cnic_back', 'cnicb'])),
                _docTile("Lawyer License / Bar Card", _findDoc(['license', 'barcard', 'lawyerlicense'])),
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
              Navigator.pop(ctx);
              _handleReject(controller.text, isRevoking);
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
      String col = widget.isVerified ? 'verified_lawyers' : 'lawyers';
      await FirebaseFirestore.instance.collection(col).doc(widget.lawyer['id']).update({
        'verificationStatus': 'rejected',
        'rejectionReason': reason,
        'isVerified': false,
      });

      await FirebaseFirestore.instance.collection('notifications').add({
        'userId': widget.lawyer['id'],
        'title': 'Account Update',
        'body': 'Your account status has been updated: Rejected. Reason: $reason',
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
