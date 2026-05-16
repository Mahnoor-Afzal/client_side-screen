import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
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

  Future<void> _pickAndUploadFile() async {
    final String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'png'],
    );

    if (result != null) {
      File file = File(result.files.single.path!);
      String fileName = result.files.single.name;

      setState(() => _isUploading = true);

      try {
        Reference storageRef = FirebaseStorage.instance
            .ref()
            .child('lawyer_documents/$uid/$fileName');
        
        UploadTask uploadTask = storageRef.putFile(file);
        TaskSnapshot snapshot = await uploadTask;
        String downloadUrl = await snapshot.ref.getDownloadURL();

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
  }

  Future<void> _openDocument(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Could not open document."), backgroundColor: Colors.red),
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
                    stream: FirebaseFirestore.instance
                        .collection('documents')
                        .where('lawyerId', isEqualTo: uid)
                        .orderBy('timestamp', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.folder_copy_outlined, size: 80, color: navyBlue.withOpacity(0.3)),
                              const SizedBox(height: 15),
                              const Text("No documents found.", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 10),
                              const Text("Signed Vakalatnamas and uploads will appear here.", style: TextStyle(color: Colors.grey, fontSize: 12)),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: snapshot.data!.docs.length,
                        itemBuilder: (context, index) {
                          var doc = snapshot.data!.docs[index];
                          var data = doc.data() as Map<String, dynamic>;
                          
                          String type = data['type'] ?? "Document";
                          String name = data['fileName'] ?? data['clientName'] ?? data['petitioner'] ?? "Unknown";
                          String date = data['date'] ?? "N/A";
                          String status = data['status'] ?? "";
                          String? fileUrl = data['fileUrl'];

                          return Card(
                            elevation: 3,
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: status == 'pending_client_signature' ? Colors.orange.shade100 : Colors.blue.shade100,
                                child: Icon(
                                  type == 'Vakalatnama' ? Icons.gavel : Icons.description,
                                  color: status == 'pending_client_signature' ? Colors.orange : Colors.blue,
                                ),
                              ),
                              title: Text(type, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("Name: $name"),
                                  Text("Date: $date", style: const TextStyle(fontSize: 11)),
                                  if (status == 'pending_client_signature')
                                    const Text("Status: Waiting for Client Sign", style: TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.bold))
                                  else if (fileUrl != null)
                                    const Text("Status: Completed / Ready to Download", style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              trailing: fileUrl != null 
                                  ? IconButton(
                                      icon: const Icon(Icons.download_for_offline, color: Colors.green, size: 30),
                                      onPressed: () => _openDocument(fileUrl),
                                    )
                                  : (status == 'pending_client_signature' ? const Icon(Icons.access_time, color: Colors.orange) : const Icon(Icons.remove_red_eye_outlined, color: Colors.grey)),
                              onTap: () {
                                if (fileUrl != null) _openDocument(fileUrl);
                              },
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
            label: const Text("UPLOAD DOCUMENT", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            heroTag: "new_form",
            backgroundColor: goldColor,
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const WakalatnamaForm()));
            },
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text("NEW VAKALATNAMA", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
