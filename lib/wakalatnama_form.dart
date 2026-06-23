import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
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
      if (widget.requestId != null && widget.requestId!.isNotEmpty) {
        var doc = await FirebaseFirestore.instance.collection('Case request').doc(widget.requestId).get();
        if (doc.exists) {
          _resolvedClientId = doc.data()?['clientId'] ?? doc.data()?['userId'];
        }
      }
      if (_resolvedClientId == null || _resolvedClientId!.isEmpty) {
        var userQuery = await FirebaseFirestore.instance.collection('users')
            .where('name', isEqualTo: _petitionerController.text.trim())
            .limit(1).get();
        if (userQuery.docs.isNotEmpty) {
          _resolvedClientId = userQuery.docs.first.id;
        }
      }
    } catch (e) {
      debugPrint("ID Discovery Error: $e");
    }
  }

  @override
  void dispose() {
    _clientSignController.dispose();
    _lawyerSignController.dispose();
    _courtController.dispose();
    _caseNoController.dispose();
    _petitionerController.dispose();
    _respondentController.dispose();
    _advocateController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  Future<void> _saveDocument() async {
    if (_courtController.text.trim().isEmpty || _petitionerController.text.trim().isEmpty || _advocateController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill all required fields.")));
      return;
    }

    if (_lawyerSignController.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Advocate signature is required."), backgroundColor: Colors.orange));
      return;
    }

    setState(() => _isSaving = true);

    try {
      if (_resolvedClientId == null || _resolvedClientId!.isEmpty) {
        await _tryResolveClientId();
      }
      if (_resolvedClientId == null || _resolvedClientId!.isEmpty) throw "Client link failed. Could not find Client ID.";

      String? uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw "Session expired. Please re-login.";

      final lawyerSignImg = await _lawyerSignController.toPngBytes();

      final pdf = pw.Document();
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (pw.Context context) => [
            pw.Center(child: pw.Text("POWER OF ATTORNEY (VAKALATNAMA)", style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold))),
            pw.SizedBox(height: 15),
            pw.Text("IN THE COURT OF: ${_courtController.text.toUpperCase()}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
            pw.Text("CASE NO / YEAR: ${_caseNoController.text.toUpperCase()}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
            pw.SizedBox(height: 10),
            pw.Text("PETITIONER / PLAINTIFF: ${_petitionerController.text.toUpperCase()}", style: pw.TextStyle(fontSize: 9.5)),
            pw.Center(child: pw.Text("VERSUS", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
            pw.Text("RESPONDENT / DEFENDANT: ${_respondentController.text.toUpperCase()}", style: pw.TextStyle(fontSize: 9.5)),
            pw.SizedBox(height: 8),
            pw.Text("ADVOCATE(S) NAME: ${_advocateController.text.toUpperCase()}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9.5)),
            pw.Divider(),
            pw.SizedBox(height: 10),
            pw.Text("In the title captioned above, I hereby appoint and authorize the Advocate(s) named below to pursue, plead, and represent the matter on my behalf at the designated place:", style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            pw.Paragraph(
              text: "On the terms and conditions that I appoint the said Advocate(s) who shall appear before the Court either in person or through a designated representative on every fixed hearing or date, and I shall inform the said Advocate(s) of my attendance immediately upon my arrival at the court premises. If the case proceeds against me or an adverse order is passed due to my non-appearance or absence, the said Advocate(s) shall not be held responsible or liable in any manner whatsoever. Furthermore, the said Advocate(s) shall be fully authorized to pursue and represent this matter at any place outside the principal seat of the court or headquarters, or during extended hours before or after the standard timings of the court premises. If any damage or loss occurs to the case or my interest due to late arrival or failure to reach the designated court timings, the said Advocate(s) shall not be held responsible or liable. I hereby declare that all acts, deeds, and steps taken or performed by the said Advocate(s) shall be fully binding upon my person as if executed by me directly. The said Advocate(s) shall have full power and authority to institute, sign, verify, and file any suits, written statements, execution petitions, appeals, reviews, revisions, or any other necessary applications on my behalf. They are further authorized to file any compromise deeds, arbitrations, settlements, or withdrawal applications, as well as to record any statements, admissions, or confessions on my behalf. They shall possess absolute right to deposit, receive, and acknowledge any funds, amounts, court dues, receipts, or documents from the Honorable Court or opposite parties. In the event of an adverse judgment or for the purpose of moving an appeal, revision, or execution of a decree, or in case of an ex-parte order or restoration application, the said Advocate(s) shall be authorized to proceed subject to a separate vakalatnama or independent fee arrangement. The said Advocate(s) shall also have the complete right to associate, appoint, or substitute any other legal counsel, co-counsel, or junior advocate to assist or represent them in this matter, and such counsel shall enjoy identical powers as granted herein. I strictly bind myself to clear and pay the full professional fees to the said Advocate(s) prior to the scheduled date of the hearing. If I fail to make the full payment of the agreed fees, the said Advocate(s) shall have the absolute right and authority to refuse appearance and completely withdraw from pursuing or conducting the case, and no claim or objection regarding this shall be maintainable against the said Advocate(s) under any circumstances. Therefore, this Power of Attorney (Vakalatnama) has been written and executed by me after carefully listening to, reading, and fully understanding its entire text, contents, and implications, and the same is hereby accepted and approved by me.",
              style: const pw.TextStyle(fontSize: 8.5),
              textAlign: pw.TextAlign.justify,
            ),
            pw.SizedBox(height: 30),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(children: [
                  pw.Container(width: 140, height: 1, color: PdfColors.black),
                  pw.Text("Client Signature", style: const pw.TextStyle(fontSize: 8))
                ]),
                pw.Column(children: [
                  if (lawyerSignImg != null) pw.Image(pw.MemoryImage(lawyerSignImg), width: 90, height: 35),
                  pw.Container(width: 140, height: 1, color: PdfColors.black),
                  pw.Text("Advocate Signature", style: const pw.TextStyle(fontSize: 8))
                ]),
              ],
            ),
            pw.SizedBox(height: 15),
            pw.Text("Dated: ${_dateController.text}", style: const pw.TextStyle(fontSize: 9)),
          ],
        ),
      );

      await pdf.save();
      String downloadUrl = "https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf";

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

      await FirebaseFirestore.instance.collection('notifications').add({
        'userId': _resolvedClientId,
        'title': 'New Vakalatnama Received',
        'body': 'Your lawyer has sent a document for your signature.',
        'type': 'vakalatnama',
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Vakalatnama sent to client successfully!"), backgroundColor: Colors.green));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
                title: const Text("Error"),
                content: Text(e.toString()),
                actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("OK"))]
            )
        );
      }
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
            const Center(child: Text("POWER OF ATTORNEY (VAKALATNAMA)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.1))),
            const SizedBox(height: 20),

            _buildInputField("IN THE COURT OF:", _courtController, "e.g. Islamabad High Court"),
            _buildInputField("CASE NO / YEAR:", _caseNoController, "e.g. 1234/2026"),
            _buildInputField("PETITIONER / PLAINTIFF:", _petitionerController, "Name of Client"),
            const Center(child: Text("VERSUS", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12))),
            const SizedBox(height: 5),
            _buildInputField("RESPONDENT / DEFENDANT:", _respondentController, "Name of Opposing Party"),
            _buildInputField("ADVOCATE(S) NAME:", _advocateController, "Lawyer's Name"),

            const SizedBox(height: 10),
            const Divider(thickness: 1),

            _buildTermsText("In the title captioned above, I hereby appoint and authorize the Advocate(s) named below to pursue, plead, and represent the matter on my behalf at the designated place:"),
            const SizedBox(height: 25),
            const Divider(thickness: 1.5, color: Colors.black87),
            const SizedBox(height: 25),
            _buildTermsText("On the terms and conditions that I appoint the said Advocate(s) who shall appear before the Court either in person or through a designated representative on every fixed hearing or date, and I shall inform the said Advocate(s) of my attendance immediately upon my arrival at the court premises. If the case proceeds against me or an adverse order is passed due to my non-appearance or absence, the said Advocate(s) shall not be held responsible or liable in any manner whatsoever. Furthermore, the said Advocate(s) shall be fully authorized to pursue and represent this matter at any place outside the principal seat of the court or headquarters, or during extended hours before or after the standard timings of the court premises. If any damage or loss occurs to the case or my interest due to late arrival or failure to reach the designated court timings, the said Advocate(s) shall not be held responsible or liable. I hereby declare that all acts, deeds, and steps taken or performed by the said Advocate(s) shall be fully binding upon my person as if executed by me directly. The said Advocate(s) shall have full power and authority to institute, sign, verify, and file any suits, written statements, execution petitions, appeals, reviews, revisions, or any other necessary applications on my behalf. They are further authorized to file any compromise deeds, arbitrations, settlements, or withdrawal applications, as well as to record any statements, admissions, or confessions on my behalf. They shall possess absolute right to deposit, receive, and acknowledge any funds, amounts, court dues, receipts, or documents from the Honorable Court or opposite parties. In the event of an adverse judgment or for the purpose of moving an appeal, revision, or execution of a decree, or in case of an ex-parte order or restoration application, the said Advocate(s) shall be authorized to proceed subject to a separate vakalatnama or independent fee arrangement. The said Advocate(s) shall also have the complete right to associate, appoint, or substitute any other legal counsel, co-counsel, or junior advocate to assist or represent them in this matter, and such counsel shall enjoy identical powers as granted herein. I strictly bind myself to clear and pay the full professional fees to the said Advocate(s) prior to the scheduled date of the hearing. If I fail to make the full payment of the agreed fees, the said Advocate(s) shall have the absolute right and authority to refuse appearance and completely withdraw from pursuing or conducting the case, and no claim or objection regarding this shall be maintainable against the said Advocate(s) under any circumstances. Therefore, this Power of Attorney (Vakalatnama) has been written and executed by me after carefully listening to, reading, and fully understanding its entire text, contents, and implications, and the same is hereby accepted and approved by me."),

            const SizedBox(height: 20),
            _buildInputField("DATED:", _dateController, "YYYY-MM-DD"),

            const SizedBox(height: 25),
            const Text("Client's Signature (Disabled for Lawyer):", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),
            const SizedBox(height: 8),
            AbsorbPointer(
              absorbing: true,
              child: Opacity(
                opacity: 0.4,
                child: Container(
                  decoration: BoxDecoration(color: Colors.grey[200], border: Border.all(color: Colors.black12), borderRadius: BorderRadius.circular(8)),
                  child: Signature(controller: _clientSignController, height: 100, backgroundColor: Colors.transparent),
                ),
              ),
            ),
            const SizedBox(height: 15),
            const Text("Advocate's Signature (Advocate signs here):", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(border: Border.all(color: Colors.black12), borderRadius: BorderRadius.circular(8)),
              child: Signature(controller: _lawyerSignController, height: 100, backgroundColor: Colors.grey[50]!),
            ),
            Align(alignment: Alignment.centerRight, child: TextButton(onPressed: () => _lawyerSignController.clear(), child: const Text("Clear Advocate Signature"))),

            const SizedBox(height: 35),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: navyBlue, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: _isSaving ? null : _saveDocument,
                icon: _isSaving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.check_circle_outline),
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
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black54)),
          const SizedBox(height: 4),
          TextField(
            controller: controller,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(hintText: hint, isDense: true, contentPadding: const EdgeInsets.symmetric(vertical: 6), border: const UnderlineInputBorder()),
          ),
        ],
      ),
    );
  }

  Widget _buildTermsText(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: TextStyle(fontSize: 11.5, height: 1.4, color: Colors.black.withOpacity(0.85)),
        textAlign: TextAlign.justify,
      ),
    );
  }
}