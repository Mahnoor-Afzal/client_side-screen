import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:signature/signature.dart';
import 'package:file_picker/file_picker.dart';

class DocumentsScreen extends StatefulWidget {
  final String? initialCategory;
  const DocumentsScreen({super.key, this.initialCategory});

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  static const Color navyBlue = Color(0xFF001F3F);
  static const Color accentGold = Color(0xFFD4AF37);
  late String _selectedFilter;
  final List<String> _categories = ['All', 'Vakalatnama', 'Evidence', 'Identity', 'Court Order'];
  String _userRole = 'client';
  bool _isInitLoading = true;

  final SignatureController _signatureController = SignatureController(
    penStrokeWidth: 3,
    penColor: navyBlue,
    exportBackgroundColor: Colors.white,
  );

  String? _userName;

  @override
  void initState() {
    super.initState();
    _selectedFilter = widget.initialCategory ?? 'All';
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        // Pehle 'users' collection check karein (For Clients)
        var userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (userDoc.exists && mounted) {
          setState(() {
            _userRole = userDoc.data()?['role'] ?? 'client';
            _userName = userDoc.data()?['name'] ?? userDoc.data()?['fullName'];
            _isInitLoading = false;
          });
          return;
        }

        // Agar 'users' mein nahi hai, toh 'verified_lawyers' check karein
        var lawyerDoc = await FirebaseFirestore.instance.collection('verified_lawyers').doc(user.uid).get();
        if (lawyerDoc.exists && mounted) {
          setState(() {
            _userRole = 'lawyer';
            _userName = lawyerDoc.data()?['fullName'] ?? lawyerDoc.data()?['name'];
            _isInitLoading = false;
          });
          return;
        }
      } catch (e) {
        debugPrint("Error fetching user data: $e");
      }
    }
    // Fallback taake loading screen khatam ho
    if (mounted) setState(() => _isInitLoading = false);
  }

  @override
  void dispose() {
    _signatureController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text("My Documents", style: TextStyle(color: accentGold, fontWeight: FontWeight.bold)),
        backgroundColor: navyBlue,
        iconTheme: const IconThemeData(color: accentGold),
      ),
      body: _isInitLoading 
          ? const Center(child: CircularProgressIndicator(color: navyBlue))
          : Column(
        children: [
          _buildCategoryFilter(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _getFilteredStream(uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: navyBlue));
                }

                if (snapshot.hasError) {
                  return Center(child: Text("Error: ${snapshot.error}"));
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildEmptyState();
                }

                var allDocs = snapshot.data!.docs;
                
                // User-based filter (Resilient logic for existing data)
                var docs = allDocs.where((d) {
                  var data = d.data() as Map<String, dynamic>;
                  String? dUserId = data['userId'] ?? data['clientId'];
                  
                  // Screenshot ke mutabiq name-based match
                  String? dClientName = (data['clientName'] ?? data['petitioner'] ?? data['clientname'])?.toString().toLowerCase();
                  String? currentName = _userName?.toLowerCase();

                  if (_userRole == 'client') {
                    // Match by ID or by Name (if ID is missing)
                    bool idMatch = (dUserId != null && dUserId == uid);
                    bool nameMatch = (currentName != null && dClientName != null && dClientName.contains(currentName));
                    return idMatch || nameMatch;
                  } else {
                    // For lawyers: show docs they sent or are assigned to
                    return data['lawyerId'] == uid;
                  }
                }).toList();

                // Category filter (Case-insensitive match for 'type' or 'category')
                if (_selectedFilter != 'All') {
                  docs = docs.where((d) {
                    var data = d.data() as Map<String, dynamic>;
                    String cat = (data['category'] ?? data['type'] ?? '').toString().toLowerCase();
                    return cat == _selectedFilter.toLowerCase();
                  }).toList();
                }

                if (docs.isEmpty) {
                  return _buildEmptyState();
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(15),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    var doc = docs[index].data() as Map<String, dynamic>;
                    return _buildDocumentCard(doc, docs[index].id);
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showUploadOptions(context),
        backgroundColor: navyBlue,
        icon: const Icon(Icons.upload_file, color: accentGold),
        label: const Text("Upload Document", style: TextStyle(color: accentGold, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Stream<QuerySnapshot> _getFilteredStream(String? uid) {
    if (uid == null) return const Stream.empty();
    
    // Prototype ke liye hum saare documents stream karenge aur Flutter mein filter karenge
    // taake agar 'userId' missing bhi ho toh hum fallback use kar sakein.
    return FirebaseFirestore.instance.collection('documents').snapshots();
  }

  Widget _buildCategoryFilter() {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 15),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          bool isSelected = _selectedFilter == _categories[index];
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: FilterChip(
              label: Text(_categories[index]),
              selected: isSelected,
              onSelected: (val) {
                setState(() => _selectedFilter = _categories[index]);
              },
              selectedColor: accentGold,
              labelStyle: TextStyle(
                color: isSelected ? navyBlue : Colors.grey[700],
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              backgroundColor: Colors.white,
              checkmarkColor: navyBlue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: isSelected ? accentGold : Colors.grey[300]!),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDocumentCard(Map<String, dynamic> doc, String docId) {
    // Screenshot ke mutabiq fields handle karna
    String clientName = doc['clientName'] ?? doc['petitioner'] ?? 'Unknown';
    String lawyerName = doc['lawyerName'] ?? 'Advocate'; // Fallback
    
    String title = doc['title'] ?? (doc['type'] == 'Vakalatnama' ? 'Vakalatnama - $clientName' : 'Untitled');
    String category = doc['category'] ?? doc['type'] ?? 'Other';
    Timestamp? ts = (doc['uploadedAt'] ?? doc['timestamp']) as Timestamp?;
    String date = ts != null ? DateFormat('dd MMM yyyy').format(ts.toDate()) : 'Recently';
    String status = doc['status'] ?? 'Uploaded';
    
    // Dono tarah ke status strings handle karein
    bool needsSignature = (status == 'Pending Signature' || status == 'pending_client_signature') && _userRole == 'client';
    
    // Display ke liye status ko saaf karein
    String displayStatus = status.replaceAll('_', ' ').split(' ').map((str) => 
      str.isEmpty ? "" : "${str[0].toUpperCase()}${str.substring(1)}"
    ).join(' ');

    IconData iconData;
    switch (category) {
      case 'Vakalatnama':
        iconData = Icons.history_edu;
        break;
      case 'Evidence':
        iconData = Icons.image_search;
        break;
      case 'Court Order':
        iconData = Icons.gavel;
        break;
      case 'Identity':
        iconData = Icons.badge_outlined;
        break;
      default:
        iconData = Icons.description;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: InkWell(
        onTap: () => _showDocumentDetail(doc, docId),
        borderRadius: BorderRadius.circular(15),
        child: Column(
          children: [
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: navyBlue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                child: Icon(iconData, color: navyBlue, size: 30),
              ),
              title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: navyBlue)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 5),
                  if (category == 'Vakalatnama') 
                    Text("Sent by: $lawyerName", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                  Text("Category: $category", style: const TextStyle(fontSize: 12)),
                  Text("Date: $date", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getStatusColor(status).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  displayStatus,
                  style: TextStyle(
                    color: _getStatusColor(status),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            // Action Buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 15),
              child: Row(
                children: [
                  if (needsSignature && _userRole == 'client') ...[
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => VakalatnamaViewScreen(
                                docId: docId,
                                docData: doc,
                                onSigned: () {
                                  // Refresh status logic handled by StreamBuilder
                                },
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.edit, size: 18),
                        label: const Text("View & Sign"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentGold,
                          foregroundColor: navyBlue,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  if (_userRole == 'lawyer' && status != 'Verified') ...[
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _verifyDocument(docId),
                        icon: const Icon(Icons.verified, size: 18),
                        label: const Text("Verify"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _viewDocument(doc),
                      icon: const Icon(Icons.download, size: 18),
                      label: const Text("Download"),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: navyBlue,
                        side: const BorderSide(color: navyBlue),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    status = status.toLowerCase();
    if (status.contains('verified')) return Colors.green;
    if (status.contains('signed')) return Colors.blue;
    if (status.contains('pending')) return Colors.deepOrange;
    if (status.contains('reject')) return Colors.red;
    return Colors.orange;
  }

  Future<void> _verifyDocument(String docId) async {
    try {
      await FirebaseFirestore.instance.collection('documents').doc(docId).update({
        'status': 'Verified',
        'verifiedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Document Verified!")));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  void _showDocumentDetail(Map<String, dynamic> doc, String docId) {
    String category = doc['category'] ?? doc['type'] ?? 'Other';
    int fileSize = doc['fileSize'] ?? 0;
    String? extension = doc['extension'];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(doc['title'] ?? "Document Info",
            style: const TextStyle(color: navyBlue, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _detailRow("Category", category),
            _detailRow("Status", doc['status'] ?? "Uploaded"),
            if (extension != null) _detailRow("File Extension", extension.toUpperCase()),
            if (fileSize > 0) _detailRow("Size", "${(fileSize / 1024).toStringAsFixed(2)} KB"),
            if (doc['uploadedAt'] != null)
              _detailRow("Uploaded",
                  DateFormat('dd MMM yyyy, hh:mm a').format((doc['uploadedAt'] as Timestamp).toDate())),
            if (doc['signedAt'] != null)
              _detailRow("Signed On",
                  DateFormat('dd MMM yyyy, hh:mm a').format((doc['signedAt'] as Timestamp).toDate())),
            if (doc['status'] == 'Verified' && doc['verifiedAt'] != null)
              _detailRow("Verified On",
                  DateFormat('dd MMM yyyy').format((doc['verifiedAt'] as Timestamp).toDate())),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close")),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.black87, fontSize: 14),
          children: [
            TextSpan(text: "$label: ", style: const TextStyle(fontWeight: FontWeight.bold)),
            TextSpan(text: value ?? "N/A"),
          ],
        ),
      ),
    );
  }


  Future<void> _pickAndUploadDocument(String category) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      );

      if (result != null) {
        PlatformFile file = result.files.first;
        final uid = FirebaseAuth.instance.currentUser?.uid;
        
        // In a real app, you would upload to Firebase Storage first.
        // For this prototype, we'll store metadata in Firestore.
        await FirebaseFirestore.instance.collection('documents').add({
          'userId': uid,
          'title': file.name,
          'category': category,
          'status': 'Uploaded',
          'uploadedAt': FieldValue.serverTimestamp(),
          'fileSize': file.size,
          'extension': file.extension,
        });

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$category uploaded successfully!")));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Upload Error: $e")));
    }
  }

  void _viewDocument(Map<String, dynamic> doc) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Downloading ${doc['title']}...")),
      );
    }
  }

  void _showUploadOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Select Document Category", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: navyBlue)),
              const SizedBox(height: 15),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _categories.where((c) => c != 'All').map((cat) {
                  return InkWell(
                    onTap: () {
                      Navigator.pop(context);
                      _pickAndUploadDocument(cat);
                    },
                    child: Container(
                      width: (MediaQuery.of(context).size.width / 2) - 30,
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Icon(_getCategoryIcon(cat), color: navyBlue, size: 28),
                          const SizedBox(height: 8),
                          Text(cat, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Vakalatnama': return Icons.history_edu;
      case 'Evidence': return Icons.image_search;
      case 'Court Order': return Icons.gavel;
      case 'Identity': return Icons.badge_outlined;
      default: return Icons.description;
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_open_outlined, size: 100, color: navyBlue.withValues(alpha: 0.1)),
          const SizedBox(height: 20),
          const Text("No documents found", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: navyBlue)),
          const SizedBox(height: 10),
          const Text("Upload your Vakalatnama or evidence here.", style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}

class VakalatnamaViewScreen extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> docData;
  final VoidCallback onSigned;

  const VakalatnamaViewScreen({
    super.key,
    required this.docId,
    required this.docData,
    required this.onSigned,
  });

  @override
  State<VakalatnamaViewScreen> createState() => _VakalatnamaViewScreenState();
}

class _VakalatnamaViewScreenState extends State<VakalatnamaViewScreen> {
  static const Color navyBlue = Color(0xFF001F3F);
  static const Color accentGold = Color(0xFFD4AF37);
  
  final SignatureController _signatureController = SignatureController(
    penStrokeWidth: 3,
    penColor: navyBlue,
    exportBackgroundColor: Colors.white,
  );

  @override
  void dispose() {
    _signatureController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String clientName = widget.docData['clientName'] ?? widget.docData['petitioner'] ?? "The Undersigned";
    String lawyerName = widget.docData['lawyerName'] ?? "The Advocate";

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Review Vakalatnama", style: TextStyle(color: accentGold)),
        backgroundColor: navyBlue,
        iconTheme: const IconThemeData(color: accentGold),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(
              child: Text(
                "VAKALATNAMA",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.underline,
                  color: navyBlue,
                ),
              ),
            ),
            const SizedBox(height: 30),
            Text(
              "In the Court of: ________________________\n"
              "Case Title: ${widget.docData['title'] ?? 'Legal Matter'}\n",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 15),
            Text(
              "I, $clientName, do hereby appoint and retain $lawyerName, Advocate(s), to appear, plead and act for me/us as my/our Advocate(s) in the above-mentioned case and in all matters connected therewith or incidental thereto.\n\n"
              "I/We authorize the said Advocate(s) to:\n"
              "1. File applications, appeals, revisions, and other legal documents.\n"
              "2. Represent me/us before the court and any other authority.\n"
              "3. Compromise or settle the matter if deemed beneficial.\n"
              "4. Receive payments and issue receipts on my/our behalf.\n\n"
              "I/We agree to ratify all acts done by the said Advocate(s) in pursuance of this authority.",
              style: const TextStyle(fontSize: 15, height: 1.5, color: Colors.black87),
              textAlign: TextAlign.justify,
            ),
            const SizedBox(height: 40),
            const Divider(thickness: 1),
            const SizedBox(height: 20),
            const Text(
              "DIGITAL SIGNATURE SECTION",
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            const SizedBox(height: 10),
            Container(
              height: 200,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!, width: 2),
                borderRadius: BorderRadius.circular(10),
                color: Colors.grey[50],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Signature(
                  controller: _signatureController,
                  backgroundColor: Colors.transparent,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _signatureController.clear(),
                  icon: const Icon(Icons.clear, color: Colors.red),
                  label: const Text("Clear Signature", style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _submitSignature,
                style: ElevatedButton.styleFrom(
                  backgroundColor: navyBlue,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text(
                  "SIGN & SUBMIT VAKALATNAMA",
                  style: TextStyle(color: accentGold, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Future<void> _submitSignature() async {
    if (_signatureController.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please provide your signature to continue.")),
      );
      return;
    }

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator(color: navyBlue)),
      );

      final Uint8List? data = await _signatureController.toPngBytes();
      if (data != null) {
        String base64Signature = base64Encode(data);
        
        // Update document status in Firestore
        await FirebaseFirestore.instance.collection('documents').doc(widget.docId).update({
          'status': 'Signed',
          'signatureBase64': base64Signature,
          'signedAt': FieldValue.serverTimestamp(),
        });

        // Link with request logic (copied from the original _submitSignature)
        String? requestId = widget.docData['requestId'];
        String? clientName = widget.docData['clientName'] ?? "A client";
        
        if (requestId != null) {
          await FirebaseFirestore.instance.collection('suit_a_file_request').doc(requestId).update({
            'status': 'Active',
            'isVakalatnamaSigned': true,
          });

          String? lawyerId = widget.docData['lawyerId'];
          if (lawyerId != null) {
            await FirebaseFirestore.instance.collection('notifications').add({
              'userId': lawyerId,
              'title': 'Vakalatnama Signed',
              'body': '$clientName has signed the Vakalatnama. The case is now Active.',
              'createdAt': FieldValue.serverTimestamp(),
              'type': 'vakalatnama_signed',
              'requestId': requestId,
              'isRead': false,
            });
          }
        }

        if (!mounted) return;
        Navigator.pop(context); // Pop loading
        Navigator.pop(context); // Go back to documents list
        widget.onSigned();
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Vakalatnama signed and submitted successfully!"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      Navigator.pop(context); // Pop loading
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }
}
