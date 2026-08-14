import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'wakalatnama_form.dart';

class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key});

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  final Color navyBlue = const Color(0xFF101D3D);
  final Color goldColor = const Color(0xFFC5A358);
  bool _isUploading = false;

  // Cloudinary Configuration
  final String cloudName = 'gasafl8q';
  final String uploadPreset = 'ml_default';

  // 1. ROBUST CLOUDINARY UPLOAD LOGIC
  Future<void> _pickAndUploadFile() async {
    final String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'png', 'jpeg'],
        withData: true,
      );

      if (result != null && result.files.single.bytes != null) {
        String fileName = result.files.single.name;
        Uint8List fileBytes = result.files.single.bytes!;

        setState(() => _isUploading = true);

        // Extension check for Cloudinary Resource Type (raw vs image)
        String ext = fileName.split('.').last.toLowerCase();
        bool isImage = ['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext);
        String resourceType = isImage ? 'image' : 'raw';

        var uri = Uri.parse("https://api.cloudinary.com/v1_1/$cloudName/$resourceType/upload");
        var request = http.MultipartRequest("POST", uri);

        // Required parameter for Unsigned upload
        request.fields['upload_preset'] = uploadPreset;

        var multipartFile = http.MultipartFile.fromBytes(
          'file',
          fileBytes,
          filename: fileName,
        );

        request.files.add(multipartFile);

        var streamedResponse = await request.send();
        var response = await http.Response.fromStream(streamedResponse);

        if (response.statusCode == 200 || response.statusCode == 201) {
          var responseData = jsonDecode(response.body);
          String downloadUrl = responseData['secure_url'];

          // Save document info to Firestore
          await FirebaseFirestore.instance.collection('documents').add({
            'lawyerId': uid,
            'type': 'Uploaded File',
            'fileName': fileName,
            'fileUrl': downloadUrl,
            'senderType': 'lawyer',
            'date': DateTime.now().toString().split(' ')[0],
            'timestamp': FieldValue.serverTimestamp(),
            'status': 'uploaded'
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("File Uploaded Successfully!"), backgroundColor: Colors.green),
            );
          }
        } else {
          var errData = jsonDecode(response.body);
          String message = errData['error']?['message'] ?? "Unknown error";
          throw "Cloudinary Error (${response.statusCode}): $message";
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Upload Error: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  // 2. OPEN / DOWNLOAD DOCUMENT LOGIC (CHECK ALL CLIENT KEYS)
  Future<void> _openDocument(Map<String, dynamic> data) async {
    // Check all possible file URL keys sent by Client or Lawyer
    String targetUrl = (data['signedFileUrl'] ??
        data['fileUrl'] ??
        data['documentUrl'] ??
        data['pdfUrl'] ??
        data['wakalatnamaUrl'] ??
        data['downloadUrl'] ??
        data['url'] ??
        "").toString().trim();

    // Handle missing file link or dummy placeholder records
    if (targetUrl.isEmpty || targetUrl.contains('dummy.pdf')) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("This document has no valid file attached or is an old dummy record."),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    final Uri uri = Uri.parse(targetUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Could not open document link."), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final String? uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text("Documents Vault", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: navyBlue,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: uid == null
          ? const Center(child: Text("Please login to see documents"))
          : Column(
        children: [
          if (_isUploading)
            const LinearProgressIndicator(backgroundColor: Colors.white, color: Colors.blue),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('documents').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                var docs = snapshot.data?.docs.where((doc) {
                  var data = doc.data() as Map<String, dynamic>;
                  String lId = (data['lawyerId'] ?? data['lawyerid'] ?? "").toString().trim();
                  String cId = (data['clientId'] ?? data['clientid'] ?? data['userId'] ?? "").toString().trim();
                  List assigned = data['assignedLawyers'] ?? [];

                  return lId == uid || cId == uid || assigned.contains(uid);
                }).toList() ?? [];

                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.folder_copy_outlined, size: 80, color: navyBlue.withOpacity(0.3)),
                        const SizedBox(height: 15),
                        const Text("No documents found.", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    var doc = docs[index];
                    var data = doc.data() as Map<String, dynamic>;

                    String type = data['type'] ?? "Document";
                    String name = data['fileName'] ?? data['clientName'] ?? data['petitioner'] ?? data['senderName'] ?? "File";
                    String date = data['date'] ?? (data['timestamp'] != null ? (data['timestamp'] as Timestamp).toDate().toString().split(' ')[0] : "N/A");
                    String senderType = data['senderType'] ?? (data.containsKey('clientId') ? 'client' : 'lawyer');

                    String targetUrl = (data['signedFileUrl'] ??
                        data['fileUrl'] ??
                        data['documentUrl'] ??
                        data['pdfUrl'] ??
                        data['wakalatnamaUrl'] ??
                        data['downloadUrl'] ??
                        data['url'] ??
                        "").toString();

                    bool hasFile = targetUrl.isNotEmpty && !targetUrl.contains('dummy.pdf');

                    return Card(
                      elevation: 3,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: senderType == 'client' ? Colors.purple.shade100 : Colors.blue.shade100,
                          child: Icon(
                            type == 'Vakalatnama' ? Icons.gavel : (senderType == 'client' ? Icons.person : Icons.description),
                            color: senderType == 'client' ? Colors.purple : Colors.blue,
                          ),
                        ),
                        title: Text(type, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("From: ${senderType == 'client' ? 'Client' : 'Lawyer'} ($name)"),
                            Text("Date: $date", style: const TextStyle(fontSize: 11)),
                          ],
                        ),
                        trailing: IconButton(
                          icon: Icon(
                              Icons.download_for_offline,
                              color: hasFile ? Colors.green : Colors.grey,
                              size: 30
                          ),
                          onPressed: () => _openDocument(data),
                        ),
                        onTap: () => _openDocument(data),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: "upload",
            backgroundColor: Colors.blueAccent,
            onPressed: _isUploading ? null : _pickAndUploadFile,
            icon: const Icon(Icons.upload_file, color: Colors.white),
            label: const Text("UPLOAD", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            heroTag: "new_form",
            backgroundColor: goldColor,
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const WakalatnamaForm()));
            },
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text("VAKALATNAMA", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}