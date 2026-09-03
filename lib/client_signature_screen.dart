import 'package:flutter/material.dart';
import 'package:signature/signature.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'dart:typed_data';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'client_pdf_helper.dart';
import 'client_app_config.dart';
import 'client_notification_helper.dart';

class SignatureScreen extends StatefulWidget {
  final String? docId;
  final String title;
  final bool isProfileSetup;

  const SignatureScreen({
    super.key,
    this.docId,
    required this.title,
    this.isProfileSetup = false,
  });

  @override
  State<SignatureScreen> createState() => _SignatureScreenState();
}

class _SignatureScreenState extends State<SignatureScreen> {
  late SignatureController _controller;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _controller = SignatureController(
      penStrokeWidth: 3,
      penColor: Colors.black,
      exportBackgroundColor: Colors.white,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _saveSignature() async {
    if (_controller.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please provide a signature first")),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final Uint8List? signatureData = await _controller.toPngBytes();
      if (signatureData != null) {
        final String? currentUid = FirebaseAuth.instance.currentUser?.uid;
        if (currentUid == null) return;

        final String fileName = 'signature_${currentUid}_${DateTime.now().millisecondsSinceEpoch}.png';
        final cloudinary = CloudinaryPublic('gasafl8q', 'ml_default', cache: false);

        CloudinaryResponse response = await cloudinary.uploadFile(
          CloudinaryFile.fromBytesData(
            signatureData,
            identifier: fileName,
            folder: widget.isProfileSetup ? 'profile_signatures' : 'signatures/${widget.docId}',
          ),
        );

        final String downloadUrl = response.secureUrl;
        final String base64Signature = base64Encode(signatureData);

        bool isLawyer = false;
        DocumentSnapshot lawyerDoc = await FirebaseFirestore.instance.collection('verified_lawyers').doc(currentUid).get();
        if (lawyerDoc.exists) isLawyer = true;

        if (widget.isProfileSetup) {
          await FirebaseFirestore.instance.collection('verified_lawyers').doc(currentUid).update({
            'digitalSignatureUrl': downloadUrl,
            'digitalSignatureBase64': base64Signature,
            'hasDigitalSignature': true,
          });
        } else if (widget.docId != null) {
          DocumentReference docRef = FirebaseFirestore.instance.collection('documents').doc(widget.docId);
          DocumentSnapshot docSnap = await docRef.get();

          Map<String, dynamic> updateData = {};

          if (isLawyer) {
            updateData = {
              'lawyerSignatureUrl': downloadUrl,
              'lawyerSignature': base64Signature,
              'status': 'Signed and Submitted',
              'lawyerSignedAt': FieldValue.serverTimestamp(),
              'senderType': 'lawyer',
              'senderId': currentUid,
            };
          } else {
            updateData = {
              'signatureUrl': downloadUrl,
              'clientSignature': base64Signature,
              'status': 'Signed and Submitted',
              'signedAt': FieldValue.serverTimestamp(),
              'actionRequired': FieldValue.delete(),
              'senderType': 'client',
              'senderId': currentUid,
            };
          }

          if (docSnap.exists) {
            Map<String, dynamic> data = docSnap.data() as Map<String, dynamic>;
            String? otherPartyId = isLawyer ? data['clientId'] : data['lawyerId'];

            if (!isLawyer && otherPartyId != null) {
              updateData['receiverId'] = otherPartyId;
            }

            await docRef.update(updateData);

            if (otherPartyId != null) {
              String senderName = isLawyer ? (data['lawyerName'] ?? 'Advocate') : (data['clientName'] ?? 'Client');

              await FirebaseFirestore.instance.collection('notifications').add({
                'userId': otherPartyId,
                'title': isLawyer ? 'Vakalatnama Signed by Advocate' : 'Vakalatnama Signed',
                'body': '$senderName has signed the Vakalatnama.',
                'createdAt': FieldValue.serverTimestamp(),
                'type': 'vakalatnama_signed',
                'docId': widget.docId,
                'isRead': false,
                'senderId': currentUid,
                'senderName': senderName,
              });

              await NotificationHelper.sendPushNotification(
                otherPartyId,
                isLawyer ? 'Vakalatnama Signed by Advocate' : 'Vakalatnama Signed!',
                '$senderName has signed the Vakalatnama.',
                {
                  'type': 'vakalatnama_signed',
                  'docId': widget.docId ?? '',
                  'click_action': 'FLUTTER_NOTIFICATION_CLICK',
                },
              );
            }

            try {
              String courtName = data['courtName'] ?? "";
              String caseNo = data['caseNo'] ?? "";
              String clientName = data['clientName'] ?? data['userName'] ?? "Client";
              String respondentName = data['respondentName'] ?? data['respondent'] ?? "";
              String lawyerName = data['lawyerName'] ?? data['advocateName'] ?? "Advocate";
              String? legalText = data['legalText'];
              String? docDate = data['createdAt'] != null
                  ? (data['createdAt'] as Timestamp).toDate().toString().split(' ')[0]
                  : null;

              Uint8List updatedPdfBytes = await PdfHelper.generateVakalatnama(
                courtName: courtName,
                caseNo: caseNo,
                clientName: clientName,
                respondentName: respondentName,
                lawyerName: lawyerName,
                date: docDate,
                legalText: legalText,
                lawyerSignatureBase64: isLawyer ? base64Signature : data['lawyerSignature'],
                clientSignatureBase64: isLawyer ? data['clientSignature'] : base64Signature,
              );

              CloudinaryResponse cloudinaryResponse = await cloudinary.uploadFile(
                CloudinaryFile.fromBytesData(
                  updatedPdfBytes,
                  identifier: 'vakalatnama_updated_${widget.docId}_${DateTime.now().millisecondsSinceEpoch}.pdf',
                  folder: 'documents/${data['clientId'] ?? currentUid}',
                ),
              );

              await docRef.update({
                'fileUrl': cloudinaryResponse.secureUrl,
                'fileSize': updatedPdfBytes.length,
              });
              debugPrint("PDF updated with signatures.");
            } catch (pdfErr) {
              debugPrint("Error updating PDF with signature: $pdfErr");
            }
          }
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(widget.isProfileSetup ? "Profile signature saved!" : "Vakalatnama signed successfully!")),
          );
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error saving signature: $e")),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color navyBlue = Color(0xFF001F3F);
    const Color gold = Color(0xFFD4AF37);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: navyBlue,
        title: Text(widget.title, style: const TextStyle(color: gold)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.clear, color: gold),
            onPressed: () => _controller.clear(),
            tooltip: 'Clear Signature',
          ),
        ],
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              "Please sign inside the box below",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: navyBlue),
            ),
          ),
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: navyBlue.withValues(alpha: 0.2), width: 2),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Signature(
                        controller: _controller,
                        backgroundColor: Colors.white,
                      ),
                    ),
                  ),
                  IgnorePointer(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 40, left: 24, right: 24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Row(
                            children: [
                              Text(
                                "X",
                                style: TextStyle(
                                  color: navyBlue.withValues(alpha: 0.1),
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Container(
                                  height: 1,
                                  color: navyBlue.withValues(alpha: 0.1),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Sign above the line",
                            style: TextStyle(
                              color: navyBlue.withValues(alpha: 0.3),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSaving ? null : () => _controller.clear(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: const BorderSide(color: navyBlue),
                    ),
                    child: const Text("Clear", style: TextStyle(color: navyBlue)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveSignature,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: navyBlue,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(color: gold, strokeWidth: 2),
                    )
                        : const Text("Sign & Submit", style: TextStyle(color: gold)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
