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

  const WakalatnamaForm({super.key, this.clientId, this.clientName});

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

  final SignatureController _clientSignController = SignatureController(penStrokeWidth: 3, penColor: Colors.black);
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

  Future<void> _tryResolveClientId() async {
    if (_resolvedClientId != null && _resolvedClientId!.isNotEmpty) return;
    try {
      var chatQuery = await FirebaseFirestore.instance
          .collection('chat')
          .where('clientName', isEqualTo: _petitionerController.text)
          .limit(1)
          .get();
      if (chatQuery.docs.isNotEmpty) {
        setState(() {
          _resolvedClientId = chatQuery.docs.first.get('clientId') ?? chatQuery.docs.first.get('userId');
        });
      }
    } catch (e) {
      debugPrint("Error resolving client ID: $e");
    }
  }

  @override
  void dispose() {
    _clientSignController.dispose();
    _lawyerSignController.dispose();
    super.dispose();
  }

  Future<void> _saveDocument() async {
    if (_courtController.text.isEmpty || _petitionerController.text.isEmpty || _advocateController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill all fields.")));
      return;
    }

    if (_resolvedClientId == null || _resolvedClientId!.isEmpty) {
      await _tryResolveClientId();
    }

    setState(() => _isSaving = true);
    try {
      String? uid = FirebaseAuth.instance.currentUser?.uid;
      final lawyerSignImg = await _lawyerSignController.toPngBytes();

      // 1. Generate PDF with Lawyer Signature
      final pdf = pw.Document();
      pdf.addPage(
        pw.Page(
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Center(child: pw.Text("VAKALATNAMA", style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold))),
                pw.SizedBox(height: 20),
                pw.Text("COURT: ${_courtController.text}"),
                pw.Text("CASE NO: ${_caseNoController.text}"),
                pw.Text("PETITIONER: ${_petitionerController.text}"),
                pw.Text("RESPONDENT: ${_respondentController.text}"),
                pw.Text("ADVOCATE: ${_advocateController.text}"),
                pw.SizedBox(height: 40),
                pw.Text("8 Legal Points of Agreement... (Simplified for PDF)"),
                pw.SizedBox(height: 50),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text("Client Signature: ________________"),
                    pw.Column(
                      children: [
                        if (lawyerSignImg != null) pw.Image(pw.MemoryImage(lawyerSignImg), width: 100, height: 50),
                        pw.Container(width: 120, height: 1, color: PdfColors.black),
                        pw.Text("Advocate Signature")
                      ]
                    )
                  ]
                )
              ]
            );
          }
        )
      );

      final output = await getTemporaryDirectory();
      final file = File("${output.path}/vakalatnama_${DateTime.now().millisecondsSinceEpoch}.pdf");
      await file.writeAsBytes(await pdf.save());

      // 2. Upload to Firebase Storage so Client can download
      String fileName = "vakalatnama_${DateTime.now().millisecondsSinceEpoch}.pdf";
      Reference storageRef = FirebaseStorage.instance.ref().child('vakalatnamas/$uid/$fileName');
      UploadTask uploadTask = storageRef.putFile(file);
      TaskSnapshot storageSnap = await uploadTask;
      String downloadUrl = await storageSnap.ref.getDownloadURL();

      // 3. Save to Firestore
      await FirebaseFirestore.instance.collection('documents').add({
        'lawyerId': uid,
        'clientId': _resolvedClientId ?? "",
        'type': 'Vakalatnama',
        'courtName': _courtController.text,
        'petitioner': _petitionerController.text,
        'respondent': _respondentController.text,
        'advocateName': _advocateController.text,
        'caseNo': _caseNoController.text,
        'date': _dateController.text,
        'status': 'pending_client_signature', 
        'fileUrl': downloadUrl, // The URL for the client to download
        'lawyerSignature': lawyerSignImg != null ? base64Encode(lawyerSignImg) : null,
        'timestamp': FieldValue.serverTimestamp(),
        'senderType': 'lawyer',
      });

      // 4. Notify Client
      if (_resolvedClientId != null) {
        await FirebaseFirestore.instance.collection('notifications').add({
          'userId': _resolvedClientId,
          'title': 'Vakalatnama for Signature',
          'body': 'Your lawyer has sent a Vakalatnama. Please download, sign and re-upload.',
          'type': 'vakalatnama',
          'timestamp': FieldValue.serverTimestamp(),
          'isRead': false,
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Vakalatnama sent! Client can now download and sign."), backgroundColor: Colors.green));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
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
            const Center(child: Text("VAKALATNAMA", style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, letterSpacing: 1.5))),
            const SizedBox(height: 30),
            
            _buildInputField("IN THE COURT OF:", _courtController, "Court Name"),
            _buildInputField("CASE NO / YEAR:", _caseNoController, "e.g. 123/2026"),
            _buildInputField("PETITIONER / PLAINTIFF:", _petitionerController, "Client Name"),
            const Center(child: Text("VERSUS", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12))),
            _buildInputField("RESPONDENT / DEFENDANT:", _respondentController, "Opposing Party"),
            _buildInputField("ADVOCATE(S) NAME:", _advocateController, "Lawyer Name"),

            const SizedBox(height: 20),
            const Divider(thickness: 1),
            const SizedBox(height: 10),
            
            const Text(
              "I/We, the undersigned, do hereby appoint and constitute the above-named Advocate(s) to be my/our lawful attorney to represent me/us in the mentioned case. The Advocate is authorized to perform the following acts on my/our behalf:",
              style: TextStyle(fontSize: 14, height: 1.6, fontWeight: FontWeight.w500, color: Colors.black87),
              textAlign: TextAlign.justify,
            ),
            const SizedBox(height: 15),
            _buildLegalPoint("1. To appear, plead, and act in the above-mentioned Court or any other Court in which the case may be heard or transferred."),
            _buildLegalPoint("2. To sign and verify all plaints, written statements, petitions, appeals, and all other legal documents required for the proceedings."),
            _buildLegalPoint("3. I/We undertake to appear in court on every date of hearing. If the case is dismissed or decided ex-parte due to my/our absence, the Advocate shall not be held responsible."),
            _buildLegalPoint("4. The Advocate is authorized to receive all payments, costs, or documents from the Court or the opposing party and issue valid receipts on my/our behalf."),
            _buildLegalPoint("5. The Advocate has full power to compromise, withdraw the case, or submit the matter to arbitration as deemed beneficial for me/us."),
            _buildLegalPoint("6. The Advocate is authorized to appoint or engage any other legal practitioner, pleader, or assistant to represent or assist in the case."),
            _buildLegalPoint("7. I/We agree to pay the settled legal fees before the date of hearing. If fees are not paid, the Advocate reserves the right to withdraw from the case."),
            _buildLegalPoint("8. I/We have heard and understood the contents of this document in my/our own language and agree to all terms mentioned above."),
            
            const SizedBox(height: 30),
            _buildInputField("DATED:", _dateController, "YYYY-MM-DD"),
            
            const SizedBox(height: 40),
            
            _buildSignatureSection("Client's Signature (To be signed by client):", _clientSignController, isReadOnly: true),
            const SizedBox(height: 25),
            _buildSignatureSection("Advocate's Signature (By Hand):", _lawyerSignController, isReadOnly: false),

            const SizedBox(height: 50),
            
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: navyBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 5,
                ),
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
            style: const TextStyle(fontSize: 16, color: Colors.black),
            decoration: InputDecoration(
              hintText: hint,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.black26)),
              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: goldColor, width: 2)),
            ),
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

  Widget _buildSignatureSection(String label, SignatureController controller, {required bool isReadOnly}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),
        const SizedBox(height: 8),
        AbsorbPointer(
          absorbing: isReadOnly,
          child: Container(
            decoration: BoxDecoration(
              color: isReadOnly ? Colors.grey[100] : Colors.grey[50],
              border: Border.all(color: Colors.black12), 
              borderRadius: BorderRadius.circular(8)
            ),
            child: Signature(controller: controller, height: 120, backgroundColor: Colors.transparent),
          ),
        ),
        if (!isReadOnly)
          Align(alignment: Alignment.centerRight, child: TextButton(onPressed: () => controller.clear(), child: const Text("Clear Signature"))),
        if (isReadOnly)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text("Waiting for client to sign from their app", style: TextStyle(fontSize: 10, color: Colors.grey, fontStyle: FontStyle.italic)),
          ),
      ],
    );
  }
}
