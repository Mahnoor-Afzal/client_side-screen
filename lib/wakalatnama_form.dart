import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:signature/signature.dart';

class WakalatnamaForm extends StatefulWidget {
  final String? clientId;
  final String? clientName;
  final String? requestId;

  const WakalatnamaForm({super.key, this.clientId, this.clientName, this.requestId});

  @override
  State<WakalatnamaForm> createState() => _WakalatnamaFormState();
}

class _WakalatnamaFormState extends State<WakalatnamaForm> {
  final Color navyBlue = const Color(0xFF101D3D);
  final Color goldColor = const Color(0xFFC5A358);

  final _courtController = TextEditingController();
  final _caseNoController = TextEditingController();
  final _petitionerController = TextEditingController();
  final _respondentController = TextEditingController();
  final _advocateController = TextEditingController();
  final _dateController = TextEditingController(text: DateTime.now().toString().split(' ')[0]);

  final SignatureController _lawyerSignController = SignatureController(penStrokeWidth: 3, penColor: Colors.black);

  bool _isSaving = false;
  String? _resolvedClientId;

  @override
  void initState() {
    super.initState();
    _resolvedClientId = widget.clientId;
    if (widget.clientName != null) {
      _petitionerController.text = widget.clientName!;
    }
    _tryResolveClientId();
  }

  // Robust ID lookup for Fatima Bibi / Kainat bibi
  Future<void> _tryResolveClientId() async {
    if (_resolvedClientId != null && _resolvedClientId!.isNotEmpty) return;
    try {
      // Try resolving by request ID first
      if (widget.requestId != null && widget.requestId!.isNotEmpty) {
        var doc = await FirebaseFirestore.instance.collection('Case request').doc(widget.requestId).get();
        if (doc.exists) {
          _resolvedClientId = doc.data()?['clientId'] ?? doc.data()?['userId'];
        }
      }
      
      // Fallback: Search by name in 'chat' collection
      if (_resolvedClientId == null || _resolvedClientId!.isEmpty) {
        var chatQuery = await FirebaseFirestore.instance.collection('chat')
            .where('clientName', isEqualTo: _petitionerController.text)
            .limit(1).get();
        if (chatQuery.docs.isNotEmpty) {
          _resolvedClientId = chatQuery.docs.first.get('clientId') ?? chatQuery.docs.first.get('userId');
        }
      }
    } catch (e) {
      debugPrint("ID Discovery Error: $e");
    }
  }

  @override
  void dispose() {
    _lawyerSignController.dispose();
    super.dispose();
  }

  Future<void> _saveDocument() async {
    if (_courtController.text.isEmpty || _petitionerController.text.isEmpty || _advocateController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill all required fields.")));
      return;
    }

    // Ensure we have a valid Client ID before proceeding
    if (_resolvedClientId == null || _resolvedClientId!.isEmpty) {
      await _tryResolveClientId();
      if (_resolvedClientId == null || _resolvedClientId!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error: Link to Client ID failed. Check client name."), backgroundColor: Colors.redAccent));
        return;
      }
    }

    setState(() => _isSaving = true);
    try {
      String? uid = FirebaseAuth.instance.currentUser?.uid;
      final lawyerSignImg = await _lawyerSignController.toPngBytes();

      // 1. Generate Professional PDF
      final pdf = pw.Document();
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Padding(
              padding: const pw.EdgeInsets.all(30),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Center(child: pw.Text("VAKALATNAMA", style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold))),
                  pw.SizedBox(height: 20),
                  pw.Text("IN THE COURT OF: ${_courtController.text}"),
                  pw.Text("CASE NO / YEAR: ${_caseNoController.text}"),
                  pw.Text("PETITIONER / PLAINTIFF: ${_petitionerController.text}"),
                  pw.Center(child: pw.Text("VERSUS", style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                  pw.Text("RESPONDENT / DEFENDANT: ${_respondentController.text}"),
                  pw.Text("ADVOCATE(S) NAME: ${_advocateController.text}"),
                  pw.SizedBox(height: 20),
                  pw.Divider(),
                  pw.Text("1. To appear, plead, and act in the Court.\n"
                          "2. To sign and verify all plaints and petitions.\n"
                          "3. I/We undertake to appear in court on every date.\n"
                          "4. Advocate is authorized to receive all payments.\n"
                          "5. Power to compromise, withdraw, or arbitrate.\n"
                          "6. Power to appoint other legal practitioners.\n"
                          "7. Agreement to pay settled legal fees.\n"
                          "8. I/We have heard and understood all terms mentioned above.", 
                          style: const pw.TextStyle(fontSize: 12)),
                  pw.SizedBox(height: 60),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(children: [pw.Container(width: 120, height: 1, color: PdfColors.black), pw.Text("Client Signature")]),
                      pw.Column(children: [
                        if (lawyerSignImg != null) pw.Image(pw.MemoryImage(lawyerSignImg), width: 100, height: 40),
                        pw.Container(width: 120, height: 1, color: PdfColors.black),
                        pw.Text("Advocate Signature")
                      ]),
                    ],
                  ),
                  pw.SizedBox(height: 20),
                  pw.Text("DATED: ${_dateController.text}"),
                ],
              ),
            );
          },
        ),
      );

      final output = await getTemporaryDirectory();
      final file = File("${output.path}/vakalatnama_${DateTime.now().millisecondsSinceEpoch}.pdf");
      await file.writeAsBytes(await pdf.save());

      // 2. Upload to Firebase Storage
      String storagePath = "vakalatnamas/${uid}_${DateTime.now().millisecondsSinceEpoch}.pdf";
      TaskSnapshot uploadTask = await FirebaseStorage.instance.ref().child(storagePath).putFile(file);
      String downloadUrl = await uploadTask.ref.getDownloadURL();

      // 3. Save Record to Firestore 'documents'
      await FirebaseFirestore.instance.collection('documents').add({
        'lawyerId': uid,
        'clientId': _resolvedClientId,
        'clientName': _petitionerController.text,
        'type': 'Vakalatnama',
        'courtName': _courtController.text,
        'caseNo': _caseNoController.text,
        'status': 'pending_client_signature', 
        'fileUrl': downloadUrl,
        'lawyerSignature': lawyerSignImg != null ? base64Encode(lawyerSignImg) : null,
        'timestamp': FieldValue.serverTimestamp(),
        'senderType': 'lawyer',
      });

      // 4. Send Notification to Client app
      await FirebaseFirestore.instance.collection('notifications').add({
        'userId': _resolvedClientId,
        'title': 'New Vakalatnama Received',
        'body': 'Your lawyer has sent a Vakalatnama for you to sign.',
        'type': 'vakalatnama',
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Vakalatnama sent successfully to client!"), backgroundColor: Colors.green));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Firebase Error: $e"), backgroundColor: Colors.red));
      debugPrint("Detailed Submit Error: $e");
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("VAKALATNAMA", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: navyBlue,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(child: Text("VAKALATNAMA FORM", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 1.2))),
            const SizedBox(height: 30),
            
            _buildInputField("IN THE COURT OF:", _courtController, "e.g. Islamabad High Court"),
            _buildInputField("CASE NO / YEAR:", _caseNoController, "e.g. 1234/2026"),
            _buildInputField("PETITIONER / PLAINTIFF:", _petitionerController, "Name of Client"),
            const Center(child: Text("VERSUS", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12))),
            const SizedBox(height: 10),
            _buildInputField("RESPONDENT / DEFENDANT:", _respondentController, "Name of Opposing Party"),
            _buildInputField("ADVOCATE(S) NAME:", _advocateController, "Lawyer's Name"),

            const SizedBox(height: 20),
            const Divider(thickness: 1),
            const Text(
              "I/We, the undersigned, do hereby appoint and constitute the above-named Advocate(s) to be my/our lawful attorney to represent me/us in the mentioned case. The Advocate is authorized to perform the following acts on my/our behalf:",
              style: TextStyle(fontSize: 13, height: 1.5, color: Colors.black87),
              textAlign: TextAlign.justify,
            ),
            const SizedBox(height: 10),
            _buildLegalPoint("1. To appear, plead, and act in the Court."),
            _buildLegalPoint("2. To sign and verify all plaints and petitions."),
            _buildLegalPoint("3. I/We undertake to appear in court on every date."),
            _buildLegalPoint("4. Advocate is authorized to receive all payments."),
            _buildLegalPoint("5. Power to compromise, withdraw, or arbitrate."),
            _buildLegalPoint("6. Power to appoint other legal practitioners."),
            _buildLegalPoint("7. Agreement to pay settled legal fees."),
            _buildLegalPoint("8. I/We have understood all terms of agreement."),
            
            const SizedBox(height: 30),
            _buildInputField("DATED:", _dateController, "YYYY-MM-DD"),
            
            const SizedBox(height: 40),
            
            // Client Signature Pad (DISABLED for Lawyer side)
            const Text("Client's Signature:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),
            const SizedBox(height: 8),
            Container(
              height: 100, width: double.infinity,
              decoration: BoxDecoration(color: Colors.grey[100], border: Border.all(color: Colors.black12), borderRadius: BorderRadius.circular(8)),
              child: const Center(child: Text("Waiting for Client to sign from their app", style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic))),
            ),

            const SizedBox(height: 25),
            // Lawyer Signature Pad (ENABLED)
            const Text("Advocate's Signature (Sign Below):", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(border: Border.all(color: Colors.black12), borderRadius: BorderRadius.circular(8)),
              child: Signature(controller: _lawyerSignController, height: 120, backgroundColor: Colors.grey[50]!),
            ),
            Align(alignment: Alignment.centerRight, child: TextButton(onPressed: () => _lawyerSignController.clear(), child: const Text("Clear Signature"))),

            const SizedBox(height: 50),
            
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: navyBlue, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: _isSaving ? null : _saveDocument,
                icon: _isSaving 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                  : const Icon(Icons.send_rounded),
                label: const Text("SAVE AND SUBMIT", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField(String label, TextEditingController controller, String hint) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black54)),
          const SizedBox(height: 5),
          TextField(
            controller: controller,
            decoration: InputDecoration(hintText: hint, isDense: true, contentPadding: const EdgeInsets.symmetric(vertical: 8), border: const UnderlineInputBorder()),
          ),
        ],
      ),
    );
  }

  Widget _buildLegalPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.arrow_right_alt_rounded, size: 20, color: Colors.black45),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13, color: Colors.black87, height: 1.4), textAlign: TextAlign.justify)),
        ],
      ),
    );
  }
}
