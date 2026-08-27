import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  final Color navyBlue = const Color(0xFF101D3D);
  final Color goldColor = const Color(0xFFC5A358);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text("Admin Panel - Lawyer Requests", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: navyBlue,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('admin_requests')
            .where('status', isEqualTo: 'pending')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No pending verification requests."));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var doc = snapshot.data!.docs[index];
              var data = doc.data() as Map<String, dynamic>;

              // Use doc.id as fallback for lawyerId
              String lawyerId = data['lawyerId'] ?? doc.id;
              String? proofUrl = data['paymentScreenshot'];
              String tid = data['transactionId'] ?? "N/A";

              return Card(
                elevation: 4,
                margin: const EdgeInsets.only(bottom: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(data['fullName'] ?? "New Lawyer",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: navyBlue)),
                      const SizedBox(height: 5),
                      Text("Email: ${data['email'] ?? 'N/A'}", style: const TextStyle(color: Colors.black87)),
                      const SizedBox(height: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: goldColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text("TID: $tid", style: TextStyle(fontWeight: FontWeight.bold, color: navyBlue)),
                      ),

                      const SizedBox(height: 12),

                      // Payment Screenshot Preview Button
                      if (proofUrl != null && proofUrl.isNotEmpty)
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: navyBlue,
                            side: BorderSide(color: navyBlue),
                          ),
                          onPressed: () => _showProofDialog(context, proofUrl, tid),
                          icon: const Icon(Icons.receipt_long_outlined, size: 18),
                          label: const Text("View Payment Proof"),
                        )
                      else
                        const Text("No Payment Proof Uploaded", style: TextStyle(color: Colors.redAccent, fontSize: 12)),

                      const Divider(height: 25),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                              onPressed: () => _handleRequest(doc.id, lawyerId, true, context),
                              child: const Text("ACCEPT"),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                              onPressed: () => _handleRequest(doc.id, lawyerId, false, context),
                              child: const Text("REJECT"),
                            ),
                          ),
                        ],
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

  // Dialog to view screenshot clearly
  void _showProofDialog(BuildContext context, String imageUrl, String tid) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: Text("TID: $tid", style: const TextStyle(fontSize: 16)),
              backgroundColor: navyBlue,
              elevation: 0,
              automaticallyImplyLeading: false,
              actions: [
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: InteractiveViewer(
                child: Image.network(
                  imageUrl,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const SizedBox(
                      height: 200,
                      child: Center(child: CircularProgressIndicator()),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) => const Text("Failed to load image"),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleRequest(String requestId, String lawyerId, bool isAccepted, BuildContext context) async {
    try {
      WriteBatch batch = FirebaseFirestore.instance.batch();

      // 1. Update Lawyer document approval & verification status
      DocumentReference lawyerRef = FirebaseFirestore.instance.collection('lawyers').doc(lawyerId);
      batch.set(lawyerRef, {
        'isVerified': isAccepted,
        'isApproved': isAccepted,
        'paymentStatus': isAccepted ? 'Approved' : 'Rejected',
        'registrationStatus': isAccepted ? 'completed' : 'rejected',
      }, SetOptions(merge: true));

      // 2. Update Admin Request status
      DocumentReference requestRef = FirebaseFirestore.instance.collection('admin_requests').doc(requestId);
      batch.update(requestRef, {
        'status': isAccepted ? 'accepted' : 'rejected',
        'processedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isAccepted ? "Lawyer Approved & Verified!" : "Request Rejected"),
            backgroundColor: isAccepted ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }
}