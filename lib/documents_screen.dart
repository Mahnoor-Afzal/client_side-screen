import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart'; // Web platform checking
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'wakalatnama_form.dart';

// HTML element download only for Web browser builds
import 'dart:html' as html;

class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key});

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  final Color navyBlue = const Color(0xFF101D3D);
  final Color goldColor = const Color(0xFFC5A358);
  bool _isUploading = false;

  final String cloudName = 'gasafl8q';
  final String uploadPreset = 'ml_default';

  // Cache to store fetched client names so we don't spam Firestore reads
  final Map<String, String> _clientNameCache = {};

  Future<void> _selectClientAndUpload() async {
    final String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() => _isUploading = true);
    List<Map<String, String>> clients = [];

    try {
      List<String> collections = ['cases', 'Case request', 'coordination_requests', 'suit_a_file_request'];

      for (String col in collections) {
        var querySnap = await FirebaseFirestore.instance.collection(col).get();
        for (var doc in querySnap.docs) {
          var data = doc.data();

          String lId = (data['lawyerId'] ?? data['lawyerid'] ?? data['senderId'] ?? data['mainLawyerId'] ?? "").toString().trim();
          String rId = (data['receiverId'] ?? data['supportingLawyerId'] ?? "").toString().trim();

          List assigned = [];
          if (data['assignedLawyers'] is List) assigned.addAll(data['assignedLawyers']);
          if (data['users'] is List) assigned.addAll(data['users']);
          List<String> assignedIds = assigned.map((e) => e.toString().trim()).toList();

          bool isUserInvolved = (lId == uid) || (rId == uid) || assignedIds.contains(uid);

          if (isUserInvolved) {
            String cId = (data['clientId'] ?? data['clientid'] ?? data['userId'] ?? "").toString().trim();
            String cName = (data['clientName'] ?? data['userName'] ?? "Client").toString().trim();

            if (cId.isNotEmpty && !clients.any((element) => element['id'] == cId)) {
              clients.add({'id': cId, 'name': cName});
            }
          }
        }
      }
    } catch (e) {
      debugPrint("Error fetching active clients: $e");
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }

    if (!mounted) return;

    String? selectedClientId = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: navyBlue,
          title: const Text(
            "Select Client",
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: clients.isEmpty
                ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text("No clients found.", style: TextStyle(color: Colors.white70, fontSize: 13)),
            )
                : ListView.builder(
              shrinkWrap: true,
              itemCount: clients.length,
              itemBuilder: (context, index) {
                return ListTile(
                  leading: const Icon(Icons.person, color: Color(0xFFC5A358)),
                  title: Text(
                    clients[index]['name']!,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                  ),
                  onTap: () => Navigator.pop(context, clients[index]['id']),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text("Cancel", style: TextStyle(color: Colors.white54)),
            ),
          ],
        );
      },
    );

    if (selectedClientId != null && selectedClientId.isNotEmpty) {
      String resolvedClientName = "Client";
      try {
        var userDoc = await FirebaseFirestore.instance.collection('users').doc(selectedClientId).get();
        if (userDoc.exists && userDoc.data() != null) {
          resolvedClientName = userDoc.data()?['fullName'] ?? userDoc.data()?['name'] ?? "Client";
        } else {
          for (var clientMap in clients) {
            if (clientMap['id'] == selectedClientId) {
              resolvedClientName = clientMap['name'] ?? "Client";
              break;
            }
          }
        }
      } catch (_) {}

      _pickAndUploadFile(targetClientId: selectedClientId, clientName: resolvedClientName);
    }
  }

  Future<void> _pickAndUploadFile({required String targetClientId, required String clientName}) async {
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

        String ext = fileName.split('.').last.toLowerCase();
        bool isImage = ['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext);
        String resourceType = isImage ? 'image' : 'raw';

        var uri = Uri.parse("https://api.cloudinary.com/v1_1/$cloudName/$resourceType/upload");
        var request = http.MultipartRequest("POST", uri);
        request.fields['upload_preset'] = uploadPreset;

        var multipartFile = http.MultipartFile.fromBytes('file', fileBytes, filename: fileName);
        request.files.add(multipartFile);

        var streamedResponse = await request.send();
        var response = await http.Response.fromStream(streamedResponse);

        if (response.statusCode == 200 || response.statusCode == 201) {
          var responseData = jsonDecode(response.body);
          String downloadUrl = responseData['secure_url'];

          await FirebaseFirestore.instance.collection('documents').add({
            'lawyerId': uid,
            'senderId': uid,
            'clientId': targetClientId,
            'receiverId': targetClientId,
            'clientName': clientName,
            'type': 'Uploaded File',
            'fileName': fileName,
            'fileUrl': downloadUrl,
            'senderType': 'lawyer',
            'date': DateTime.now().toString().split(' ')[0],
            'timestamp': FieldValue.serverTimestamp(),
            'status': 'uploaded',
            'isDownloaded': true,
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("File Uploaded Successfully!"), backgroundColor: Colors.green),
            );
          }
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

  Future<void> _handleDocumentAction(String docId, Map<String, dynamic> data) async {
    String targetUrl = (data['signedFileUrl'] ??
        data['wakalatnamaUrl'] ??
        data['fileUrl'] ??
        data['pdfUrl'] ??
        data['documentUrl'] ??
        data['downloadUrl'] ??
        data['url'] ??
        data['signatureUrl'] ??
        "").toString().trim();

    if (targetUrl.isEmpty || targetUrl.contains('dummy.pdf')) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No valid document URL found."), backgroundColor: Colors.orange),
        );
      }
      return;
    }

    try {
      bool isDownloadedAlready = data['isDownloaded'] ?? false;
      String senderType = (data['senderType'] ?? "").toString().toLowerCase();

      if (senderType == 'lawyer') {
        isDownloadedAlready = true;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isDownloadedAlready ? "Opening document..." : "Downloading file..."),
            backgroundColor: Colors.blue,
          ),
        );
      }

      if (kIsWeb) {
        if (!isDownloadedAlready) {
          final response = await http.get(Uri.parse(targetUrl));
          if (response.statusCode == 200) {
            final blob = html.Blob([response.bodyBytes], 'application/pdf');
            final url = html.Url.createObjectUrlFromBlob(blob);
            html.AnchorElement(href: url)
              ..setAttribute("download", "${data['fileName'] ?? 'Document'}.pdf")
              ..click();
            html.Url.revokeObjectUrl(url);
          } else {
            throw "Download failed";
          }
        } else {
          html.window.open(targetUrl, '_blank');
        }
      } else {
        final Uri uri = Uri.parse(targetUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      }

      if (!isDownloadedAlready && senderType != 'lawyer') {
        await FirebaseFirestore.instance.collection('documents').doc(docId).update({
          'isDownloaded': true,
        });
      }
    } catch (e) {
      final Uri uri = Uri.parse(targetUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
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
                  String rId = (data['receiverId'] ?? "").toString().trim();
                  String sId = (data['senderId'] ?? "").toString().trim();

                  List assigned = [];
                  if (data['assignedLawyers'] is List) assigned.addAll(data['assignedLawyers']);
                  if (data['users'] is List) assigned.addAll(data['users']);
                  List<String> assignedList = assigned.map((e) => e.toString().trim()).toList();

                  // Only show documents where the current user is directly involved (as lawyer, client, sender, receiver, or explicitly assigned)
                  bool isDirectParty = (lId == uid || cId == uid || rId == uid || sId == uid || assignedList.contains(uid));

                  return isDirectParty;
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

                    String type = data['type'] ?? data['title'] ?? "Document";
                    String status = (data['status'] ?? "").toString();
                    bool isSigned = status.toLowerCase().contains('signed');
                    String senderType = (data['senderType'] ?? "").toString().toLowerCase();

                    String rawClientName = (data['clientName'] ?? data['userName'] ?? "").toString().trim();
                    String clientId = (data['clientId'] ?? data['clientid'] ?? data['userId'] ?? "").toString().trim();

                    return FutureBuilder<String>(
                      future: _resolveClientName(rawClientName, clientId),
                      builder: (context, nameSnapshot) {
                        String clientName = nameSnapshot.data ?? (rawClientName.isNotEmpty ? rawClientName : "Client");

                        String subtitleText;
                        if (type == 'Vakalatnama') {
                          subtitleText = isSigned
                              ? "Status: Signed by Client ($clientName)"
                              : "Status: Pending Client Signature";
                        } else {
                          if (senderType == 'client' || senderType.isEmpty) {
                            subtitleText = "From: $clientName";
                          } else {
                            subtitleText = "From: Lawyer";
                          }
                        }

                        String targetUrl = (data['signedFileUrl'] ??
                            data['wakalatnamaUrl'] ??
                            data['fileUrl'] ??
                            data['pdfUrl'] ??
                            data['documentUrl'] ??
                            data['signatureUrl'] ??
                            "").toString();

                        bool hasFile = targetUrl.isNotEmpty && !targetUrl.contains('dummy.pdf');
                        bool isDownloaded = (senderType == 'lawyer') ? true : (data['isDownloaded'] ?? false);

                        return Card(
                          elevation: 3,
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: isSigned ? Colors.green.shade100 : (type == 'Vakalatnama' ? Colors.blue.shade100 : Colors.purple.shade100),
                              child: Icon(
                                type == 'Vakalatnama' ? (isSigned ? Icons.verified : Icons.gavel) : Icons.description,
                                color: isSigned ? Colors.green.shade800 : (type == 'Vakalatnama' ? Colors.blue : Colors.purple),
                              ),
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(type, style: const TextStyle(fontWeight: FontWeight.bold)),
                                ),
                                if (isSigned)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.green,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      "SIGNED",
                                      style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                              ],
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                    subtitleText,
                                    style: TextStyle(
                                        color: isSigned ? Colors.green.shade900 : Colors.black87,
                                        fontWeight: isSigned ? FontWeight.bold : FontWeight.normal
                                    )
                                ),
                                Text(
                                    "Date: ${data['date'] ?? (data['timestamp'] != null ? (data['timestamp'] as Timestamp).toDate().toString().split(' ')[0] : "N/A")}",
                                    style: const TextStyle(fontSize: 11)
                                ),
                              ],
                            ),
                            trailing: hasFile
                                ? IconButton(
                              icon: Icon(
                                isDownloaded ? Icons.visibility : Icons.download_for_offline,
                                color: isDownloaded ? Colors.grey.shade700 : Colors.green,
                                size: 28,
                              ),
                              onPressed: () => _handleDocumentAction(doc.id, data),
                            )
                                : null,
                            onTap: hasFile ? () => _handleDocumentAction(doc.id, data) : null,
                          ),
                        );
                      },
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
            onPressed: _isUploading ? null : _selectClientAndUpload,
            icon: const Icon(Icons.upload_file, color: Colors.white),
            label: const Text("UPLOAD", style: TextStyle(color: Colors.white,fontWeight: FontWeight.bold)),
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

  Future<String> _resolveClientName(String rawName, String clientId) async {
    if (rawName.isNotEmpty && rawName != "Client") {
      return rawName;
    }
    if (clientId.isEmpty) {
      return "Client";
    }
    if (_clientNameCache.containsKey(clientId)) {
      return _clientNameCache[clientId]!;
    }

    try {
      var userDoc = await FirebaseFirestore.instance.collection('users').doc(clientId).get();
      if (userDoc.exists && userDoc.data() != null) {
        String fetchedName = userDoc.data()?['fullName'] ?? userDoc.data()?['name'] ?? "";
        if (fetchedName.isNotEmpty) {
          _clientNameCache[clientId] = fetchedName;
          return fetchedName;
        }
      }
    } catch (_) {}

    return "Client";
  }
}