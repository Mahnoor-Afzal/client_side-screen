import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:signature/signature.dart';
import 'package:http/http.dart' as http;

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

  // Editable fields for lawyers
  final _leadLawyerController = TextEditingController();
  final _supportingLawyersController = TextEditingController();

  final _dateController = TextEditingController(text: DateTime.now().toString().split(' ')[0]);

  final SignatureController _lawyerSignController = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.black,
  );

  bool _isSaving = false;
  bool _isLoadingTeam = true;
  String? _resolvedClientId;

  // Cloudinary Settings
  final String cloudName = 'gasafl8q';
  final String uploadPreset = 'ml_default';

  @override
  void initState() {
    super.initState();
    _resolvedClientId = widget.clientId;
    if (widget.clientName != null && widget.clientName!.isNotEmpty) {
      _petitionerController.text = widget.clientName!;
    }
    _fetchLawyerAndTeamDetails();
    _tryResolveClientId();
  }

  Future<void> _fetchLawyerAndTeamDetails() async {
    try {
      String? uid = FirebaseAuth.instance.currentUser?.uid;
      String fetchedLead = "";
      if (uid != null) {
        var doc = await FirebaseFirestore.instance.collection('lawyers').doc(uid).get();
        if (doc.exists && doc.data() != null) {
          fetchedLead = doc.data()?['fullName'] ?? doc.data()?['name'] ?? "";
        }
      }

      List<String> team = [];
      if (widget.requestId != null && widget.requestId!.isNotEmpty) {
        var coordQuery = await FirebaseFirestore.instance
            .collection('coordination_requests')
            .where('caseId', isEqualTo: widget.requestId)
            .get();

        for (var doc in coordQuery.docs) {
          String senderName = doc.data()['senderName'] ?? '';
          String receiverName = doc.data()['receiverName'] ?? '';

          if (senderName.isNotEmpty && senderName != fetchedLead && !team.contains(senderName)) {
            team.add(senderName);
          }
          if (receiverName.isNotEmpty && receiverName != fetchedLead && !team.contains(receiverName)) {
            team.add(receiverName);
          }
        }
      }

      setState(() {
        _leadLawyerController.text = fetchedLead;
        _supportingLawyersController.text = team.join(', ');
      });
    } catch (e) {
      debugPrint("Team/Lawyer details error: $e");
    } finally {
      setState(() => _isLoadingTeam = false);
    }
  }

  Future<void> _tryResolveClientId() async {
    if (_resolvedClientId != null && _resolvedClientId!.isNotEmpty) return;
    try {
      if (widget.requestId != null && widget.requestId!.isNotEmpty) {
        var doc = await FirebaseFirestore.instance.collection('suit_a_file_request').doc(widget.requestId).get();
        if (doc.exists) {
          _resolvedClientId = doc.data()?['clientId'] ?? doc.data()?['userId'];
        } else {
          doc = await FirebaseFirestore.instance.collection('Case request').doc(widget.requestId).get();
          if (doc.exists) {
            _resolvedClientId = doc.data()?['clientId'] ?? doc.data()?['userId'];
          }
        }
      }

      if ((_resolvedClientId == null || _resolvedClientId!.isEmpty) && _petitionerController.text.trim().isNotEmpty) {
        var userQuery = await FirebaseFirestore.instance
            .collection('users')
            .where('name', isEqualTo: _petitionerController.text.trim())
            .limit(1)
            .get();
        if (userQuery.docs.isNotEmpty) {
          _resolvedClientId = userQuery.docs.first.id;
        }
      }

      if ((_resolvedClientId == null || _resolvedClientId!.isEmpty) && _caseNoController.text.trim().isNotEmpty) {
        var caseQuery = await FirebaseFirestore.instance
            .collection('cases')
            .where('caseNumber', isEqualTo: _caseNoController.text.trim())
            .limit(1)
            .get();
        if (caseQuery.docs.isNotEmpty) {
          _resolvedClientId = caseQuery.docs.first.data()['clientId'];
        }
      }
    } catch (e) {
      debugPrint("ID Discovery Error: $e");
    }
  }

  @override
  void dispose() {
    _lawyerSignController.dispose();
    _courtController.dispose();
    _caseNoController.dispose();
    _petitionerController.dispose();
    _respondentController.dispose();
    _leadLawyerController.dispose();
    _supportingLawyersController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  Future<String> _uploadPdfToCloudinary(Uint8List pdfBytes, String fileName) async {
    var uri = Uri.parse("https://api.cloudinary.com/v1_1/$cloudName/raw/upload");
    var request = http.MultipartRequest("POST", uri);

    request.fields['upload_preset'] = uploadPreset;

    var multipartFile = http.MultipartFile.fromBytes(
      'file',
      pdfBytes,
      filename: fileName,
    );

    request.files.add(multipartFile);

    var streamedResponse = await request.send();
    var response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200 || response.statusCode == 201) {
      var responseData = jsonDecode(response.body);
      return responseData['secure_url'];
    } else {
      var errData = jsonDecode(response.body);
      String msg = errData['error']?['message'] ?? 'Upload failed';
      throw "Cloudinary Error (${response.statusCode}): $msg";
    }
  }

  Future<void> _saveDocument() async {
    if (_courtController.text.trim().isEmpty ||
        _petitionerController.text.trim().isEmpty ||
        _leadLawyerController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all required fields.")),
      );
      return;
    }

    if (_lawyerSignController.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Advocate signature is required."),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      if (_resolvedClientId == null || _resolvedClientId!.isEmpty) {
        await _tryResolveClientId();
      }

      if (_resolvedClientId == null || _resolvedClientId!.isEmpty) {
        _resolvedClientId = "manual_client_${DateTime.now().millisecondsSinceEpoch}";
      }

      String? uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw "Session expired. Please re-login.";

      final lawyerSignImg = await _lawyerSignController.toPngBytes();
      List<String> supportingList = _supportingLawyersController.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      String leadLawyerName = _leadLawyerController.text.trim();
      String allAdvocatesText = leadLawyerName + (supportingList.isNotEmpty ? ', ${supportingList.join(', ')}' : '');

      // PDF Generation with only Lead Advocate signature space
      final pdf = pw.Document();
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(35),
          build: (pw.Context context) => [
            pw.Center(
              child: pw.Text("VAKALAT NAMA", style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
            ),
            pw.SizedBox(height: 10),
            pw.Text("IN THE HONOURABLE COURT OF: ${_courtController.text.toUpperCase()}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9.5)),
            pw.SizedBox(height: 5),
            pw.Text("CASE NO / YEAR: ${_caseNoController.text.toUpperCase()}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9.5)),
            pw.SizedBox(height: 5),
            pw.Text("PETITIONER / PLAINTIFF: ${_petitionerController.text.toUpperCase()}", style: pw.TextStyle(fontSize: 9.5)),
            pw.SizedBox(height: 4),
            pw.Center(child: pw.Text("VERSUS", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9.5, color: PdfColors.grey700))),
            pw.SizedBox(height: 4),
            pw.Text("RESPONDENT / DEFENDANT: ${_respondentController.text.toUpperCase()}", style: pw.TextStyle(fontSize: 9.5)),
            pw.SizedBox(height: 8),
            pw.Text("KNOW ALL TO WHOM these presents shall come that I, the undersigned appoint:", style: pw.TextStyle(fontSize: 9, fontStyle: pw.FontStyle.italic)),
            pw.SizedBox(height: 4),
            pw.Text(allAdvocatesText.toUpperCase(), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.indigo800)),
            pw.SizedBox(height: 8),
            pw.Divider(color: PdfColors.grey400),
            pw.SizedBox(height: 6),
            pw.Text(
              "to be the advocates in the above mentioned case / proceedings to do all the following acts, deeds and things or any of these i.e. to say:",
              style: const pw.TextStyle(fontSize: 9),
            ),
            pw.SizedBox(height: 6),
            ...[
              "1. To act, appear and plead in the above mentioned case in this court / authority or any other court in which the same may be tried or heard in the first instance or in appeal or revision or review or execution or in any stage of its proceedings until its final decision.",
              "2. To present pleading, appeals, cross objections, petitions, applications for executions, review, revision, compromise or other petitions or affidavit or other documents as shall be deemed necessary or advisable in the said case / proceedings.",
              "3. To withdraw or compromise the said case / petition or submit to arbitration any differences or disputes that shall arise ancillary or akin or in any manner relating to the said case / proceedings.",
              "4. To receive money and grant receipts and discharge thereof and to do all other acts and things which may be necessary to be done of the progress in the course of the case / petition / proceedings.",
            ].map((item) => pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 4),
              child: pw.Text(item, style: const pw.TextStyle(fontSize: 8.5)),
            )),
            pw.SizedBox(height: 6),
            pw.Text(
              "And I hereby agree to ratify, whatever the advocate or his associate, assistant shall do in this behalf AND I personally or through attorney appear in the court at the time of call on each and every date of hearing and will also inform the advocate. The advocate / counsel will not responsible for any default due to non-appearance of the undersigned in the court. We are responsible to pay the entire fee before the appearance of the advocate / counsel in the court and if the undersigned could not pay the same, the advocate / counsel will be at liberty not to proceed the case / petition etc.",
              style: pw.TextStyle(fontSize: 8.5, fontStyle: pw.FontStyle.italic),
            ),
            pw.SizedBox(height: 15),
            pw.Text("DATED: ${_dateController.text}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9.5)),
            pw.SizedBox(height: 20),
            // Signatures Section (Only Lead Advocate signature)
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text("Signature / Thumb Impression of Client(s):", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5)),
                    pw.SizedBox(height: 20),
                    pw.Container(width: 140, height: 1, color: PdfColors.black),
                    pw.SizedBox(height: 2),
                    pw.Text("Waiting for Client signature", style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text("Advocate's Signature:", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5)),
                    pw.SizedBox(height: 5),
                    if (lawyerSignImg != null) pw.Image(pw.MemoryImage(lawyerSignImg), width: 90, height: 25),
                    pw.Container(width: 140, height: 1, color: PdfColors.black),
                    pw.SizedBox(height: 2),
                    pw.Text(leadLawyerName, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
                  ],
                ),
              ],
            ),
          ],
        ),
      );

      final pdfBytes = await pdf.save();
      String fileName = 'Vakalatnama_${DateTime.now().millisecondsSinceEpoch}.pdf';

      String downloadUrl = await _uploadPdfToCloudinary(pdfBytes, fileName);

      DocumentReference docRef = FirebaseFirestore.instance.collection('documents').doc();

      await docRef.set({
        'docId': docRef.id,
        'caseId': widget.requestId ?? "",
        'clientId': _resolvedClientId,
        'userId': _resolvedClientId,
        'senderId': uid,
        'receiverId': _resolvedClientId,
        'lawyerId': uid,
        'lawyerName': leadLawyerName,
        'supportingLawyers': supportingList,
        'senderName': leadLawyerName,
        'senderType': 'lawyer',
        'title': 'Vakalatnama',
        'extension': 'pdf',
        'fileUrl': downloadUrl,
        'type': 'Vakalatnama',
        'status': 'pending_client_signature',
        'courtName': _courtController.text.trim(),
        'caseNo': _caseNoController.text.trim(),
        'respondent': _respondentController.text.trim(),
        'advocateName': allAdvocatesText,
        'clientName': _petitionerController.text.trim(),
        'requiresPassword': true,
        'actionRequired': 'sign',
        'lawyerSignature': lawyerSignImg != null ? base64Encode(lawyerSignImg) : null,
        'clientSignature': null,
        'date': _dateController.text,
        'timestamp': FieldValue.serverTimestamp(),
      });

      await FirebaseFirestore.instance.collection('notifications').add({
        'userId': _resolvedClientId,
        'receiverId': _resolvedClientId,
        'senderId': uid,
        'docId': docRef.id,
        'caseId': widget.requestId ?? "",
        'title': 'Vakalatnama Signature Required',
        'body': 'Your lawyer has sent Vakalatnama. Please enter your password to sign and accept.',
        'type': 'vakalatnama',
        'action': 'sign_vakalatnama',
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Vakalatnama sent to client successfully!"),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Error"),
            content: Text(e.toString()),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("OK"),
              )
            ],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("VAKALAT NAMA", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: navyBlue,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoadingTeam
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Text("VAKALAT NAMA FORM", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: navyBlue)),
            ),
            const SizedBox(height: 20),
            TextField(controller: _courtController, decoration: const InputDecoration(labelText: "IN THE HONOURABLE COURT OF:", hintText: "e.g. Islamabad High Court")),
            const SizedBox(height: 12),
            TextField(controller: _caseNoController, decoration: const InputDecoration(labelText: "CASE NO / YEAR:", hintText: "e.g. 1234/2026")),
            const SizedBox(height: 12),
            TextField(controller: _petitionerController, decoration: const InputDecoration(labelText: "PETITIONER / PLAINTIFF:", hintText: "Name of Client")),
            const SizedBox(height: 12),
            const Center(child: Text("VERSUS", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
            const SizedBox(height: 12),
            TextField(controller: _respondentController, decoration: const InputDecoration(labelText: "RESPONDENT / DEFENDANT:", hintText: "Name of Opposing Party")),
            const SizedBox(height: 12),

            // Editable Lead Lawyer Field
            TextField(
              controller: _leadLawyerController,
              decoration: const InputDecoration(
                labelText: "LEAD ADVOCATE NAME:",
                hintText: "Enter lead lawyer name",
              ),
            ),
            const SizedBox(height: 12),

            // Editable Supporting Counsels Field
            TextField(
              controller: _supportingLawyersController,
              decoration: const InputDecoration(
                labelText: "SUPPORTING COUNSEL(S) (Comma separated):",
                hintText: "e.g. Aslam, Husnain",
              ),
            ),
            const SizedBox(height: 20),

            const Text(
              "KNOW ALL TO WHOM these presents shall come that I, the undersigned appoint the above-named Advocate(s) to be the advocates in the above mentioned case / proceedings to do all the following acts, deeds and things or any of these i.e. to say:",
              style: TextStyle(fontSize: 13, color: Colors.black87),
            ),
            const SizedBox(height: 10),
            const Text("1. To act, appear and plead in the above mentioned case in this court / authority or any other court in which the same may be tried or heard in the first instance or in appeal or revision or review or execution or in any stage of its proceedings until its final decision."),
            const SizedBox(height: 6),
            const Text("2. To present pleading, appeals, cross objections, petitions, applications for executions, review, revision, compromise or other petitions or affidavit or other documents as shall be deemed necessary or advisable in the said case / proceedings."),
            const SizedBox(height: 6),
            const Text("3. To withdraw or compromise the said case / petition or submit to arbitration any differences or disputes that shall arise ancillary or akin or in any manner relating to the said case / proceedings."),
            const SizedBox(height: 6),
            const Text("4. To receive money and grant receipts and discharge thereof and to do all other acts and things which may be necessary to be done of the progress in the course of the case / petition / proceedings."),
            const SizedBox(height: 10),
            const Text(
              "And I hereby agree to ratify, whatever the advocate or his associate, assistant shall do in this behalf AND I personally or through attorney appear in the court at the time of call on each and every date of hearing and will also inform the advocate. The advocate / counsel will not responsible for any default due to non-appearance of the undersigned in the court. We are responsible to pay the entire fee before the appearance of the advocate / counsel in the court and if the undersigned could not pay the same, the advocate / counsel will be at liberty not to proceed the case / petition etc.",
              style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.black54),
            ),
            const SizedBox(height: 20),
            TextField(controller: _dateController, decoration: const InputDecoration(labelText: "DATED:"), readOnly: true),
            const SizedBox(height: 20),

            const Text("Lead Advocate's Signature (Sign Below):", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Container(
              decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(10)),
              child: Signature(controller: _lawyerSignController, height: 130, backgroundColor: Colors.white),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => _lawyerSignController.clear(),
                child: Text("Clear Signature", style: TextStyle(color: navyBlue)),
              ),
            ),
            const SizedBox(height: 20),
            const Text("Client's Signature Status:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade300)),
              child: const Text("Client will enter account password to unlock signature pad on their device.", style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: navyBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                onPressed: _isSaving ? null : _saveDocument,
                icon: const Icon(Icons.send, color: Colors.white),
                label: _isSaving
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text("SEND TO CLIENT FOR SIGNATURE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}