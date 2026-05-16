import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class VakalatnamaScreen extends StatefulWidget {
  final String requestId;
  final String lawyerName;

  const VakalatnamaScreen({
    super.key,
    required final this.requestId,
    required final this.lawyerName,
  });

  @override
  State<VakalatnamaScreen> createState() => _VakalatnamaScreenState();
}

class _VakalatnamaScreenState extends State<VakalatnamaScreen> {
  bool _isSigned = false;
  final Color navyBlue = const Color(0xFF001F3F);
  final Color gold = const Color(0xFFD4AF37);

  Future<void> _submitVakalatnama() async {
    if (!_isSigned) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please sign the Vakalatnama first.")),
      );
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('suit_a_file_request')
          .doc(widget.requestId)
          .update({
        'status': 'Active',
        'signedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Vakalatnama submitted. Your case is now Active!")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: navyBlue,
        title: const Text("Vakalatnama", style: TextStyle(color: Color(0xFFD4AF37))),
        iconTheme: const IconThemeData(color: Color(0xFFD4AF37)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "POWER OF ATTORNEY / VAKALATNAMA",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Text(
              "I hereby appoint ${widget.lawyerName} as my legal representative to act on my behalf in the legal proceedings as described in the case request. I authorize the said advocate to appear, plead, and act in all matters related to this case.",
              style: const TextStyle(fontSize: 16, height: 1.5),
            ),
            const SizedBox(height: 40),
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(10),
              ),
              child: _isSigned 
                ? Center(child: Text("Signed digitally", style: TextStyle(color: navyBlue, fontWeight: FontWeight.bold, fontSize: 18)))
                : Center(child: Text("Sign here", style: TextStyle(color: Colors.grey.shade400))),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Checkbox(
                  value: _isSigned,
                  onChanged: (val) => setState(() => _isSigned = val ?? false),
                  activeColor: navyBlue,
                ),
                const Expanded(
                  child: Text("I agree to the terms and authorize digital signature."),
                ),
              ],
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _submitVakalatnama,
                style: ElevatedButton.styleFrom(
                  backgroundColor: navyBlue,
                  foregroundColor: gold,
                ),
                child: const Text("SUBMIT VAKALATNAMA", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
