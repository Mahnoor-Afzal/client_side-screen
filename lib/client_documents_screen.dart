import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'client_signature_screen.dart';
import 'client_notification_helper.dart';
import 'package:intl/intl.dart';

class DocumentsScreen extends StatefulWidget {
  final String? initialCategory;
  final int initialTab;
  final String? initialDocId;
  const DocumentsScreen({
    super.key,
    this.initialCategory,
    this.initialTab = 0,
    this.initialDocId,
  });

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> with SingleTickerProviderStateMixin {
  String _selectedCategory = 'All';
  late TabController _tabController;
  bool _isUploading = false;
  double _uploadProgress = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab,
    );
    if (widget.initialCategory != null) {
      _selectedCategory = widget.initialCategory!;
    }

    if (widget.initialDocId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _viewDocumentById(widget.initialDocId!);
      });
    }
  }

  Future<void> _viewDocumentById(String docId) async {
    try {
      var doc = await FirebaseFirestore.instance.collection('documents').doc(docId).get();
      if (doc.exists && mounted) {
        var data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        _viewDocument(data);
      }
    } catch (e) {
      debugPrint("Error viewing document by ID: $e");
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _uploadDocument() async {
    final String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      bool isLawyer = false;
      String senderName = 'Client';

      DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (userDoc.exists) {
        var userData = userDoc.data() as Map<String, dynamic>;
        senderName = userData['name'] ?? userData['fullName'] ?? 'Client';
      } else {
        DocumentSnapshot lawyerDoc = await FirebaseFirestore.instance.collection('verified_lawyers').doc(uid).get();
        if (lawyerDoc.exists) {
          isLawyer = true;
          var lawyerData = lawyerDoc.data() as Map<String, dynamic>;
          senderName = lawyerData['fullName'] ?? lawyerData['name'] ?? 'Lawyer';
        }
      }

      Future<List<QueryDocumentSnapshot>> getReqs(String collectionName) async {
        var snap1 = await FirebaseFirestore.instance.collection(collectionName).where('clientId', isEqualTo: uid).get();
        var snap2 = await FirebaseFirestore.instance.collection(collectionName).where('userId', isEqualTo: uid).get();
        var snap3 = await FirebaseFirestore.instance.collection(collectionName).where('lawyerId', isEqualTo: uid).get();
        
        // Supporting lawyers check
        var snap4 = await FirebaseFirestore.instance.collection(collectionName).where('supportingLawyerIds', arrayContains: uid).get();
        
        return [...snap1.docs, ...snap2.docs, ...snap3.docs, ...snap4.docs];
      }

      List<QueryDocumentSnapshot> allReqs = [
        ...await getReqs('consultation_request'),
        ...await getReqs('suit_a_file_request'),
      ];

      var activeReqs = allReqs.where((doc) {
        var data = doc.data() as Map<String, dynamic>;
        String status = (data['status'] ?? data['requestStatus'] ?? '').toString().toLowerCase();
        bool isActive = ['accepted', 'active', 'in progress', 'approved', 'started'].contains(status);

        if (isLawyer) {
          return isActive && (data['clientId'] != null || data['userId'] != null);
        } else {
          bool hasLawyer = data['lawyerId'] != null || data['lawyerid'] != null || data['lawyer_id'] != null;
          return isActive && hasLawyer;
        }
      }).toList();

      if (activeReqs.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isLawyer ? "No active clients found." : "No active lawyers found. Ensure your request has been 'Accepted'."),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      Map<String, String> uniqueOthers = {};
      for (var doc in activeReqs) {
        var data = doc.data() as Map<String, dynamic>;
        if (isLawyer) {
          String? cId = data['clientId'] ?? data['userId'];
          String name = data['clientName'] ?? data['userName'] ?? 'Client';
          if (cId != null) uniqueOthers[cId] = name;
        } else {
          String? lId = data['lawyerId'] ?? data['lawyerid'] ?? data['lawyer_id'];
          String name = data['lawyerName'] ?? data['lawyername'] ?? data['lawyer_name'] ?? 'Lawyer';
          if (lId != null) uniqueOthers[lId] = name;
        }
      }

      if (uniqueOthers.isEmpty) return;

      if (!mounted) return;
      String? selectedOtherId = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(isLawyer ? "Select Client" : "Select Lawyer",
              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF001F3F))),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: uniqueOthers.length,
              itemBuilder: (context, index) {
                String otherId = uniqueOthers.keys.elementAt(index);
                return ListTile(
                  leading: const CircleAvatar(backgroundColor: Color(0xFFD4AF37), child: Icon(Icons.person, color: Colors.white)),
                  title: Text(uniqueOthers[otherId]!, style: const TextStyle(fontWeight: FontWeight.w500)),
                  onTap: () => Navigator.pop(context, otherId),
                );
              },
            ),
          ),
        ),
      );

      if (!mounted || selectedOtherId == null) return;
      String? selectedOtherName = uniqueOthers[selectedOtherId];

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'png'],
        withData: true,
      );

      if (result == null) return;

      if (mounted) setState(() => _isUploading = true);

      String fileName = result.files.single.name;
      final cloudinary = CloudinaryPublic('gasafl8q', 'ml_default', cache: false);

      CloudinaryResponse response;
      if (kIsWeb) {
        response = await cloudinary.uploadFile(
          CloudinaryFile.fromBytesData(
            result.files.single.bytes!,
            identifier: fileName,
            folder: 'documents/$uid',
          ),
          onProgress: (bytesSent, total) {
            if (mounted) {
              setState(() {
                _uploadProgress = bytesSent / total;
              });
            }
          },
        );
      } else {
        response = await cloudinary.uploadFile(
          CloudinaryFile.fromFile(
            result.files.single.path!,
            identifier: fileName,
            folder: 'documents/$uid',
          ),
          onProgress: (bytesSent, total) {
            if (mounted) {
              setState(() {
                _uploadProgress = bytesSent / total;
              });
            }
          },
        );
      }

      String downloadUrl = response.secureUrl;

      DocumentReference docRef = await FirebaseFirestore.instance.collection('documents').add({
        'userId': isLawyer ? selectedOtherId : uid,
        'clientId': isLawyer ? selectedOtherId : uid,
        'senderId': uid,
        'senderName': senderName,
        'receiverId': selectedOtherId,
        'lawyerId': isLawyer ? uid : selectedOtherId,
        'lawyerName': isLawyer ? senderName : selectedOtherName,
        'clientName': isLawyer ? selectedOtherName : senderName,
        'title': fileName,
        'category': 'Coordination',
        'fileUrl': downloadUrl,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'Uploaded',
        'extension': result.files.single.extension ?? fileName.split('.').last,
        'senderType': isLawyer ? 'lawyer' : 'client',
      });

      await FirebaseFirestore.instance.collection('notifications').add({
        'userId': selectedOtherId,
        'title': isLawyer ? 'New Document from Lawyer' : 'New Document Received',
        'body': '$senderName has uploaded: $fileName',
        'createdAt': FieldValue.serverTimestamp(),
        'type': 'document_received',
        'senderId': uid,
        'senderName': senderName,
        'isRead': false,
        'docId': docRef.id,
      });

      try {
        await NotificationHelper.sendPushNotification(
          selectedOtherId,
          isLawyer ? 'New Document from Lawyer' : 'New Document Received',
          '$senderName has uploaded: $fileName',
          {
            'click_action': 'FLUTTER_NOTIFICATION_CLICK',
            'type': 'document_received',
            'docId': docRef.id,
            'senderName': senderName,
          },
        );
      } catch (e) {
        debugPrint("Push notification error: $e");
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Sent successfully!"), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() { _isUploading = false; _uploadProgress = 0; });
    }
  }

  Future<void> _viewDocument(Map<String, dynamic> doc) async {
    String docType = doc['type'] ?? doc['category'] ?? '';

    bool isVakalatnama = docType == 'Vakalatnama' ||
        doc['courtName'] != null ||
        doc['advocateName'] != null ||
        doc['caseNo'] != null;

    if (isVakalatnama) {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VakalatnamaViewerScreen(
            doc: doc,
            onDelete: () async {
              bool deleted = await _deleteDocument(doc['id'] as String);
              if (deleted && context.mounted) {
                Navigator.pop(context);
              }
            },
          ),
        ),
      );
      return;
    }

    String? fileUrl = doc['fileUrl'] ?? doc['url'] ?? doc['downloadUrl'];

    if (fileUrl == null || fileUrl.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Document link not available. Please contact your lawyer.")),
        );
      }
      return;
    }

    try {
      final Uri uri = Uri.parse(fileUrl.trim());
      if (!mounted) return;
      await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      debugPrint("Error launching URL: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Could not open document. Please try again.")),
        );
      }
    }
  }

  Future<bool> _deleteDocument(String docId) async {
    try {
      bool confirm = await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: const Text("Delete Document", style: TextStyle(color: Color(0xFF001F3F), fontWeight: FontWeight.bold)),
          content: const Text("Are you sure you want to delete this document permanently?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("CANCEL", style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("DELETE", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ) ?? false;

      if (confirm) {
        await FirebaseFirestore.instance.collection('documents').doc(docId).delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Document deleted successfully"), backgroundColor: Colors.red),
          );
        }
        return true;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error deleting document: $e")));
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    const Color navyBlue = Color(0xFF001F3F);
    const Color gold = Color(0xFFD4AF37);
    final String? uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: navyBlue,
        title: const Text("Documents", style: TextStyle(color: gold, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          labelColor: gold,
          unselectedLabelColor: Colors.white70,
          indicatorColor: gold,
          tabs: const [
            Tab(text: "Received", icon: Icon(Icons.inbox)),
            Tab(text: "Sent", icon: Icon(Icons.send)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isUploading ? null : _uploadDocument,
        backgroundColor: navyBlue,
        icon: _isUploading
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: gold, strokeWidth: 2))
            : const Icon(Icons.upload_file, color: gold),
        label: Text(_isUploading ? "Uploading..." : "Upload", style: const TextStyle(color: gold)),
      ),
      body: Column(
        children: [
          if (_isUploading)
            LinearProgressIndicator(value: _uploadProgress, backgroundColor: Colors.grey[200], color: gold),
          _buildCategoryFilter(),
          Expanded(
            child: uid == null
                ? const Center(child: Text("Please login to view documents"))
                : TabBarView(
              controller: _tabController,
              children: [
                _buildDocumentList(uid, isReceived: true),
                _buildDocumentList(uid, isReceived: false),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentList(String uid, {required bool isReceived}) {
    const Color navyBlue = Color(0xFF001F3F);

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('documents')
          .where(Filter.or(
        Filter('userId', isEqualTo: uid),
        Filter('clientId', isEqualTo: uid),
        Filter('receiverId', isEqualTo: uid),
        Filter('senderId', isEqualTo: uid),
        Filter('lawyerId', isEqualTo: uid),
      ))
          .snapshots(includeMetadataChanges: true),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: navyBlue));
        }

        var docs = snapshot.data?.docs ?? [];
        var filteredDocs = docs.where((doc) {
          var data = doc.data() as Map<String, dynamic>;
          String effectiveSenderId = data['uploadedById'] ?? data['senderId'] ?? '';
          bool isMeSender = effectiveSenderId == uid || (data['senderType'] == 'client' && data['userId'] == uid && !isReceived);

          if (isReceived) {
            return data['receiverId'] == uid || (!isMeSender && (data['userId'] == uid || data['clientId'] == uid));
          } else {
            return isMeSender;
          }
        }).toList();

        filteredDocs.sort((a, b) {
          var dataA = a.data() as Map<String, dynamic>;
          var dataB = b.data() as Map<String, dynamic>;
          Timestamp? t1 = dataA['timestamp'] as Timestamp? ?? dataA['uploadedAt'] as Timestamp?;
          Timestamp? t2 = dataB['timestamp'] as Timestamp? ?? dataB['uploadedAt'] as Timestamp?;
          if (t1 == null) return 1;
          if (t2 == null) return -1;
          return t2.compareTo(t1);
        });

        return _buildListView(filteredDocs, isReceived: isReceived);
      },
    );
  }

  Widget _buildListView(List<QueryDocumentSnapshot> docs, {required bool isReceived}) {
    const Color navyBlue = Color(0xFF001F3F);

    if (_selectedCategory != 'All') {
      docs = docs.where((d) {
        var data = d.data() as Map<String, dynamic>;
        String rawCat = (data['category'] ?? data['type'] ?? 'General').toString();
        bool isVak = rawCat == 'Vakalatnama' || data['courtName'] != null;

        if (_selectedCategory == 'Vakalatnama') return isVak;
        if (_selectedCategory == 'Coordination') return !isVak;
        return false;
      }).toList();
    }

    if (docs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open, size: 80, color: navyBlue.withValues(alpha: 0.1)),
            const SizedBox(height: 16),
            Text(
              "No documents found",
              style: TextStyle(color: navyBlue.withValues(alpha: 0.5), fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: docs.length,
      itemBuilder: (context, index) {
        var docData = Map<String, dynamic>.from(docs[index].data() as Map<String, dynamic>);
        docData['id'] = docs[index].id;

        String title = docData['title'] ?? docData['fileName'] ?? 'Unnamed Document';
        String rawCat = (docData['category'] ?? docData['type'] ?? 'General').toString();
        bool isVak = rawCat == 'Vakalatnama' || docData['courtName'] != null;

        String category = isVak ? 'Vakalatnama' : 'Case Documents';
        String resolvedName = docData['uploadedBy'] ??
            docData['senderName'] ??
            docData['lawyerName'] ??
            docData['advocateName'] ??
            docData['lawyer_name'] ??
            'Lawyer';

        String roleStr = docData['uploadedByRole'] != null ? " (${docData['uploadedByRole']})" : "";
        String displaySender = isReceived ? "Sent by: $resolvedName$roleStr" : "To: $resolvedName";

        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: navyBlue.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.description, color: navyBlue),
            ),
            title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: navyBlue)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                (resolvedName == 'Lawyer' || resolvedName == 'Advocate' || resolvedName.isEmpty || resolvedName == 'Client') && (docData['senderId'] != null || docData['uploadedById'] != null)
                    ? FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance
                      .collection(isReceived ? 'verified_lawyers' : 'users')
                      .doc(docData['uploadedById'] ?? docData['senderId'])
                      .get(),
                  builder: (context, lSnap) {
                    String name = resolvedName;
                    if (lSnap.hasData && lSnap.data!.exists) {
                      var lData = lSnap.data!.data() as Map<String, dynamic>;
                      name = lData['fullName'] ?? lData['name'] ?? name;
                    }
                    return Text(isReceived ? "Sent by: $name$roleStr" : "To: $name",
                        style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13));
                  },
                )
                    : Text(displaySender, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                Text("Category: $category", style: const TextStyle(fontSize: 12)),
                if (docData['timestamp'] != null || docData['uploadedAt'] != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      "Date: ${DateFormat('dd MMM yyyy, hh:mm a').format(((docData['timestamp'] ?? docData['uploadedAt']) as Timestamp).toDate())}",
                      style: TextStyle(
                        color: navyBlue.withValues(alpha: 0.6),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
            trailing: PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: navyBlue),
              onSelected: (value) {
                if (value == 'view') {
                  _viewDocument(docData);
                } else if (value == 'delete') {
                  _deleteDocument(docData['id']);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'view',
                  child: Row(
                    children: [
                      Icon(Icons.open_in_new, color: Colors.green, size: 20),
                      SizedBox(width: 8),
                      Text("View"),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, color: Colors.red, size: 20),
                      SizedBox(width: 8),
                      Text("Delete"),
                    ],
                  ),
                ),
              ],
            ),
            onTap: () => _viewDocument(docData),
          ),
        );
      },
    );
  }

  Widget _buildCategoryFilter() {
    List<String> categories = ['All', 'Vakalatnama', 'Coordination'];
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          bool isSelected = _selectedCategory == categories[index];
          return GestureDetector(
            onTap: () => setState(() => _selectedCategory = categories[index]),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF001F3F) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF001F3F).withValues(alpha: 0.2)),
              ),
              child: Center(
                child: Text(
                  categories[index],
                  style: TextStyle(
                    color: isSelected ? const Color(0xFFD4AF37) : Colors.black54,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class VakalatnamaViewerScreen extends StatelessWidget {
  final Map<String, dynamic> doc;
  final VoidCallback? onDelete;
  const VakalatnamaViewerScreen({super.key, required this.doc, this.onDelete});

  void _showPasswordVerifyDialog(BuildContext context, {bool isForLawyer = false}) {
    final TextEditingController passwordController = TextEditingController();
    bool isLoading = false;
    bool obscurePassword = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.security, color: Color(0xFFD4AF37)),
                SizedBox(width: 10),
                Text("Verify Identity", style: TextStyle(color: Color(0xFF001F3F), fontWeight: FontWeight.bold)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(isForLawyer
                    ? "Advocate, please enter your password to sign this Vakalatnama."
                    : "Please enter your login password to authorize this digital signature."),
                const SizedBox(height: 20),
                TextField(
                  controller: passwordController,
                  obscureText: obscurePassword,
                  enableSuggestions: false,
                  autocorrect: false,
                  autofillHints: const [],
                  keyboardType: TextInputType.visiblePassword,
                  decoration: InputDecoration(
                    labelText: "Login Password",
                    hintText: "Enter your password",
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(obscurePassword ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setDialogState(() => obscurePassword = !obscurePassword),
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
              ElevatedButton(
                onPressed: isLoading ? null : () async {
                  setDialogState(() => isLoading = true);
                  try {
                    User? user = FirebaseAuth.instance.currentUser;
                    AuthCredential credential = EmailAuthProvider.credential(
                      email: user!.email!,
                      password: passwordController.text.trim(),
                    );
                    await user.reauthenticateWithCredential(credential);

                    if (context.mounted) {
                      Navigator.pop(context);
                      if (context.mounted) {
                        _showSignaturePadDialog(context, isForLawyer: isForLawyer);
                      }
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Incorrect password!"), backgroundColor: Colors.red),
                      );
                    }
                  } finally {
                    setDialogState(() => isLoading = false);
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF001F3F)),
                child: isLoading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text("Verify", style: TextStyle(color: Color(0xFFD4AF37))),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showSignaturePadDialog(BuildContext context, {bool isForLawyer = false}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (innerContext) => Dialog(
        insetPadding: const EdgeInsets.all(10),
        child: SizedBox(
          width: MediaQuery.of(context).size.width * 0.9,
          height: 600,
          child: SignatureScreen(
            docId: doc['id'] ?? '',
            title: isForLawyer ? "Advocate Signature" : "Sign Vakalatnama",
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color navyBlue = Color(0xFF001F3F);
    const Color gold = Color(0xFFD4AF37);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Vakalatnama Details", style: TextStyle(color: gold, fontWeight: FontWeight.bold)),
        backgroundColor: navyBlue,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (onDelete != null)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.redAccent),
              onPressed: onDelete,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 5)),
            ],
            border: Border.all(color: navyBlue.withValues(alpha: 0.1)),
          ),
          padding: const EdgeInsets.all(30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(
                child: Text(
                  "VAKALAT NAMA",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1A237E), letterSpacing: 1.2),
                ),
              ),
              const SizedBox(height: 25),
              _buildTemplateRow("IN THE HONOURABLE COURT OF:", (doc['courtName'] ?? '').toString().toUpperCase()),
              _buildTemplateRow("CASE NO / YEAR:", (doc['caseNo'] ?? '').toString().toUpperCase()),
              _buildTemplateRow("PETITIONER / PLAINTIFF:", (doc['clientName'] ?? '').toString().toUpperCase()),
              const Padding(
                padding: EdgeInsets.only(right: 80, top: 5, bottom: 5),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text("VERSUS", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12)),
                ),
              ),
              _buildTemplateRow("RESPONDENT / DEFENDANT:", (doc['respondentName'] ?? doc['respondent'] ?? '').toString().toUpperCase()),
              const SizedBox(height: 15),
              RichText(
                textAlign: TextAlign.justify,
                text: TextSpan(
                  style: const TextStyle(fontSize: 13, color: Colors.black, height: 1.5),
                  children: [
                    const TextSpan(text: "KNOW ALL TO WHOM these presents shall come that I, the undersigned appoint: ", style: TextStyle(fontStyle: FontStyle.italic)),
                    TextSpan(
                      text: (doc['advocateName'] ?? doc['lawyerName'] ?? 'Advocate').toString().toUpperCase(),
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1A237E)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 15),
              const Text(
                "to be the advocates in the above mentioned case / proceedings to do all the following acts, deeds and things or any of these i.e. to say:",
                style: TextStyle(fontSize: 12.5),
              ),
              const SizedBox(height: 12),
              _buildClause(1, "To act, appear and plead in the above mentioned case in this court / authority or any other court in which the same may be tried or heard in the first instance or in appeal or revision or review or execution or in any stage of its proceedings until its final decision."),
              _buildClause(2, "To present pleading, appeals, cross objections, petitions, applications for executions, review, revision, compromise or other petitions or affidavit or other documents as shall be deemed necessary or advisable in the said case / proceedings."),
              _buildClause(3, "To withdraw or compromise the said case / petition or submit to arbitration any differences or disputes that shall arise ancillary or akin or in any manner relating to the said case / proceedings."),
              _buildClause(4, "To receive money and grant receipts and discharge thereof and to do all other acts and things which may be necessary to be done of the progress in the course of the case / petition / proceedings."),
              const SizedBox(height: 12),
              const Text(
                "And I hereby agree to ratify, whatever the advocate or his associate, assistant shall do in this behalf AND I personally or through attorney appear in the court at the time of call on each and every date of hearing and will also inform the advocate. The advocate / counsel will not responsible for any default due to non-appearance of the undersigned in the court. We are responsible to pay the entire fee before the appearance of the advocate / counsel in the court and if the undersigned could not pay the same, the advocate / counsel will be at liberty not to proceed the case / petition etc.",
                textAlign: TextAlign.justify,
                style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.black87),
              ),
              const SizedBox(height: 20),
              Text(
                "DATED: ${doc['date'] ?? (doc['timestamp'] != null ? DateFormat('yyyy-MM-dd').format((doc['timestamp'] as Timestamp).toDate()) : '_________________')}",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 40),
              Builder(
                builder: (context) {
                  final String? currentUid = FirebaseAuth.instance.currentUser?.uid;
                  final bool isClient = currentUid == doc['clientId'] || currentUid == doc['userId'];
                  final bool isLawyer = currentUid == doc['lawyerId'];
                  final bool isSignedByClient = doc['signatureUrl'] != null && doc['signatureUrl'].toString().isNotEmpty && doc['signatureUrl'].toString() != "null";
                  final bool isSignedByLawyer = (doc['lawyerSignatureUrl'] != null && doc['lawyerSignatureUrl'].toString().isNotEmpty && doc['lawyerSignatureUrl'].toString() != "null") ||
                      (doc['lawyerSignature'] != null && doc['lawyerSignature'].toString().isNotEmpty && doc['lawyerSignature'].toString() != "null");

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Signature / Thumb Impression of Client(s):", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                            const SizedBox(height: 10),
                            if (isSignedByClient)
                              Image.network(doc['signatureUrl'].toString(), height: 40)
                            else if (isClient)
                              GestureDetector(
                                onTap: () => _showPasswordVerifyDialog(context),
                                child: Container(
                                  height: 40, width: 120,
                                  decoration: BoxDecoration(border: Border.all(color: navyBlue.withValues(alpha: 0.3), style: BorderStyle.solid)),
                                  child: const Center(child: Text("Click to Sign", style: TextStyle(color: navyBlue, fontSize: 10))),
                                ),
                              )
                            else
                              const SizedBox(height: 40),
                            Container(width: 150, height: 1, color: Colors.black),
                            const SizedBox(height: 4),
                            Text(isSignedByClient ? (doc['clientName'] ?? 'Client') : "Waiting for Client signature",
                                style: const TextStyle(fontSize: 9, color: Colors.grey)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Advocate's Signature:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                            const SizedBox(height: 5),
                            if (isSignedByLawyer)
                              Builder(builder: (context) {
                                String? lSigUrl = doc['lawyerSignatureUrl']?.toString();
                                String? lSigBase64 = doc['lawyerSignature']?.toString();
                                if (lSigUrl != null && lSigUrl.startsWith('http')) return Image.network(lSigUrl, height: 35);
                                if (lSigBase64 != null) return Image.memory(base64Decode(lSigBase64), height: 35);
                                return const Icon(Icons.check_circle, color: Colors.green, size: 30);
                              })
                            else if (isLawyer)
                              GestureDetector(
                                onTap: () => _showPasswordVerifyDialog(context, isForLawyer: true),
                                child: Container(
                                  height: 40, width: 120,
                                  decoration: BoxDecoration(border: Border.all(color: Colors.red.withValues(alpha: 0.3), style: BorderStyle.solid)),
                                  child: const Center(child: Text("Click to Sign", style: TextStyle(color: Colors.red, fontSize: 10))),
                                ),
                              )
                            else
                              const SizedBox(height: 40),
                            Container(width: 150, height: 1, color: Colors.black),
                            const SizedBox(height: 4),
                            Text((doc['lawyerName'] ?? doc['advocateName'] ?? 'Advocate').toString().toUpperCase(),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10)),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTemplateRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 11)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildClause(int number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("$number. ", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 12), textAlign: TextAlign.justify)),
        ],
      ),
    );
  }
}