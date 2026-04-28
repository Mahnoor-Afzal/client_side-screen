import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/services.dart';

class PdfHelper {
  static Future<Uint8List> generateVakalatnama({
    required String courtName,
    required String caseNo,
    required String clientName,
    required String respondentName,
    required String lawyerName,
    String? lawyerSignatureBase64,
    String? clientSignatureBase64,
    String? date,
    String? legalText,
    List<String>? supportingLawyers,
  }) async {
    final pdf = pw.Document();

    pw.MemoryImage? lawyerSign;
    pw.MemoryImage? clientSign;

    if (lawyerSignatureBase64 != null && lawyerSignatureBase64.isNotEmpty && lawyerSignatureBase64 != "null") {
      try {
        lawyerSign = pw.MemoryImage(base64Decode(lawyerSignatureBase64));
      } catch (e) {
        debugPrint("Error decoding lawyer signature: $e");
      }
    }

    if (clientSignatureBase64 != null && clientSignatureBase64.isNotEmpty && clientSignatureBase64 != "null") {
      try {
        clientSign = pw.MemoryImage(base64Decode(clientSignatureBase64));
      } catch (e) {
        debugPrint("Error decoding client signature: $e");
      }
    }

    String allAdvocatesText = lawyerName.toUpperCase();
    if (supportingLawyers != null && supportingLawyers.isNotEmpty) {
      allAdvocatesText += ", ${supportingLawyers.join(', ').toUpperCase()}";
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 50, vertical: 40),
        build: (pw.Context context) => [
          pw.Center(
            child: pw.Text(
              "VAKALAT NAMA",
              style: pw.TextStyle(
                fontSize: 20,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromInt(0xFF1A237E), // Navy Blue
              ),
            ),
          ),
          pw.SizedBox(height: 25),
          pw.Text("IN THE HONOURABLE COURT OF: ${courtName.toUpperCase()}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
          pw.SizedBox(height: 6),
          pw.Text("CASE NO / YEAR: ${caseNo.toUpperCase()}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
          pw.SizedBox(height: 6),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text("PETITIONER / PLAINTIFF: ${clientName.toUpperCase()}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
              pw.Padding(
                padding: const pw.EdgeInsets.only(right: 60),
                child: pw.Text("VERSUS", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.grey700)),
              ),
            ],
          ),
          pw.SizedBox(height: 6),
          pw.Text("RESPONDENT / DEFENDANT: ${respondentName.toUpperCase()}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
          pw.SizedBox(height: 15),
          pw.RichText(
            text: pw.TextSpan(
              style: const pw.TextStyle(fontSize: 10),
              children: [
                pw.TextSpan(text: "KNOW ALL TO WHOM these presents shall come that I, the undersigned appoint: ", style: pw.TextStyle(fontStyle: pw.FontStyle.italic)),
                pw.TextSpan(
                  text: allAdvocatesText,
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF1A237E)),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 15),
          pw.Text(
            "to be the advocates in the above mentioned case / proceedings to do all the following acts, deeds and things or any of these i.e. to say:",
            style: const pw.TextStyle(fontSize: 10),
          ),
          pw.SizedBox(height: 10),
          ...[
            "1. To act, appear and plead in the above mentioned case in this court / authority or any other court in which the same may be tried or heard in the first instance or in appeal or revision or review or execution or in any stage of its proceedings until its final decision.",
            "2. To present pleading, appeals, cross objections, petitions, applications for executions, review, revision, compromise or other petitions or affidavit or other documents as shall be deemed necessary or advisable in the said case / proceedings.",
            "3. To withdraw or compromise the said case / petition or submit to arbitration any differences or disputes that shall arise ancillary or akin or in any manner relating to the said case / proceedings.",
            "4. To receive money and grant receipts and discharge thereof and to do all other acts and things which may be necessary to be done of the progress in the course of the case / petition / proceedings.",
          ].map((item) => pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 6),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(child: pw.Text(item, style: const pw.TextStyle(fontSize: 9.5), textAlign: pw.TextAlign.justify)),
              ],
            ),
          )),
          pw.SizedBox(height: 10),
          pw.Text(
            "And I hereby agree to ratify, whatever the advocate or his associate, assistant shall do in this behalf AND I personally or through attorney appear in the court at the time of call on each and every date of hearing and will also inform the advocate. The advocate / counsel will not responsible for any default due to non-appearance of the undersigned in the court. We are responsible to pay the entire fee before the appearance of the advocate / counsel in the court and if the undersigned could not pay the same, the advocate / counsel will be at liberty not to proceed the case / petition etc.",
            style: pw.TextStyle(fontSize: 9.5, fontStyle: pw.FontStyle.italic),
            textAlign: pw.TextAlign.justify,
          ),
          pw.SizedBox(height: 20),
          pw.Text("DATED: ${date ?? DateTime.now().toString().split(' ')[0]}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
          pw.SizedBox(height: 40),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text("Signature / Thumb Impression of Client(s):", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                  pw.SizedBox(height: 10),
                  if (clientSign != null)
                    pw.Image(clientSign, height: 35)
                  else
                    pw.SizedBox(height: 35),
                  pw.Container(width: 160, height: 1, color: PdfColors.black),
                  pw.SizedBox(height: 4),
                  pw.Text(clientSignatureBase64 != null && clientSignatureBase64 != "null" ? clientName : "Waiting for Client signature", 
                         style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text("Advocate's Signature:", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                  pw.SizedBox(height: 5),
                  if (lawyerSign != null)
                    pw.Image(lawyerSign, height: 35)
                  else
                    pw.SizedBox(height: 35),
                  pw.Container(width: 160, height: 1, color: PdfColors.black),
                  pw.SizedBox(height: 4),
                  pw.Text(lawyerName.toUpperCase(), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                ],
              ),
            ],
          ),
        ],
      ),
    );

    return pdf.save();
  }
}
