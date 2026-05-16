import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class HearingDetailsScreen extends StatefulWidget {
  final String caseId;
  final String clientName;
  final String? clientId;

  const HearingDetailsScreen({
    super.key, 
    required this.caseId, 
    this.clientName = "Client",
    this.clientId,
  });

  @override
  State<HearingDetailsScreen> createState() => _HearingDetailsScreenState();
}

class _HearingDetailsScreenState extends State<HearingDetailsScreen> with AutomaticKeepAliveClientMixin {
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _timeController = TextEditingController();
  final TextEditingController _courtController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  String _status = 'Upcoming';
  bool _isLoading = false;
  bool _isFetching = true;
  String? _resolvedClientId; 

  final Color navyBlue = const Color(0xFF101D3D);
  final Color goldColor = const Color(0xFFC5A358);

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _resolvedClientId = widget.clientId;
    _loadExistingHearingData();
  }

  void _loadExistingHearingData() async {
    if (widget.caseId.isEmpty) return;
    try {
      // 1. Hearings collection se data load karein
      var doc = await FirebaseFirestore.instance.collection('Hearings').doc(widget.caseId).get();
      if (doc.exists && mounted) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data != null) {
          setState(() {
            _dateController.text = data['hearing_date'] ?? "";
            _timeController.text = data['hearing_time'] ?? "";
            _courtController.text = data['court_location'] ?? "";
            _descController.text = data['description'] ?? "";
            _status = data['status'] ?? "Upcoming";
            if (_resolvedClientId == null) _resolvedClientId = data['clientId'] ?? data['userId'];
          });
        }
      }

      // 2. Fetch Client ID if missing (Essential for Sync)
      if (_resolvedClientId == null || _resolvedClientId!.isEmpty) {
        // chat collection check karein
        var chatDoc = await FirebaseFirestore.instance.collection('chat').doc(widget.caseId).get();
        if (chatDoc.exists) {
          _resolvedClientId = chatDoc.data()?['clientId'] ?? chatDoc.data()?['userId'];
        }
        
        // Agar ID abhi bhi nahi mili, client ke naam se lookup karein
        if (_resolvedClientId == null || _resolvedClientId!.isEmpty) {
           var chatQuery = await FirebaseFirestore.instance.collection('chat')
              .where('clientName', isEqualTo: widget.clientName).limit(1).get();
          if (chatQuery.docs.isNotEmpty) {
            _resolvedClientId = chatQuery.docs.first.get('clientId') ?? chatQuery.docs.first.get('userId');
          }
        }
      }
    } catch (e) {
      debugPrint("Sync Error: $e");
    } finally {
      if (mounted) setState(() => _isFetching = false);
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000), 
      lastDate: DateTime(2101),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.dark(primary: goldColor, onPrimary: navyBlue, surface: navyBlue, onSurface: Colors.white),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _dateController.text = DateFormat('yyyy-MM-dd').format(picked));
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.dark(primary: goldColor, onPrimary: navyBlue, surface: navyBlue, onSurface: Colors.white),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      if (mounted) setState(() => _timeController.text = picked.format(context));
    }
  }

  Future<void> updateHearing() async {
    if (_dateController.text.isEmpty || _timeController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select Date and Time')),
      );
      return;
    }

    if (_resolvedClientId == null || _resolvedClientId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: Link to Client ID failed. Check case status.'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      String? uid = FirebaseAuth.instance.currentUser?.uid;
      
      final hearingData = {
        'case_id': widget.caseId,
        'clientId': _resolvedClientId, 
        'userId': _resolvedClientId,   // Support both fields
        'client_name': widget.clientName,
        'lawyerid': uid?.trim(),
        'lawyerId': uid?.trim(),
        'hearing_date': _dateController.text,
        'hearing_time': _timeController.text,
        'court_location': _courtController.text,
        'description': _descController.text,
        'status': _status,
        'last_updated': FieldValue.serverTimestamp(),
      };

      // A. Save to Hearings collection
      await FirebaseFirestore.instance.collection('Hearings').doc(widget.caseId).set(hearingData, SetOptions(merge: true));

      // B. ALSO update 'chat' collection (the main case doc) so it shows on client dashboard home
      await FirebaseFirestore.instance.collection('chat').doc(widget.caseId).set({
        'next_hearing_date': _dateController.text,
        'next_hearing_time': _timeController.text,
        'next_hearing_court': _courtController.text,
        'lastMessage': 'New hearing: ${_dateController.text}',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // C. Notification for Client
      await FirebaseFirestore.instance.collection('notifications').add({
        'userId': _resolvedClientId,
        'title': 'New Hearing Set',
        'body': 'Your hearing is scheduled for ${_dateController.text} at ${_timeController.text}.',
        'type': 'hearing',
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hearing successfully sent to ${widget.clientName}!'), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_isFetching) return Scaffold(backgroundColor: navyBlue, body: const Center(child: CircularProgressIndicator(color: Colors.white)));

    return Scaffold(
      backgroundColor: navyBlue,
      appBar: AppBar(
        title: Text("Schedule Hearing: ${widget.clientName}", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(25),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLabel("Hearing Date"),
            _buildTextField(_dateController, Icons.calendar_today, onTap: () => _selectDate(context), readOnly: true),
            const SizedBox(height: 15),
            _buildLabel("Hearing Time"),
            _buildTextField(_timeController, Icons.access_time, onTap: () => _selectTime(context), readOnly: true),
            const SizedBox(height: 15),
            _buildLabel("Court Name/Location"),
            _buildTextField(_courtController, Icons.gavel),
            const SizedBox(height: 15),
            _buildLabel("Hearing Details"),
            TextField(
              controller: _descController,
              maxLines: 4,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Enter hearing details...',
                hintStyle: const TextStyle(color: Colors.white24),
                filled: true, fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 15),
            _buildLabel("Status"),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _status, isExpanded: true, dropdownColor: navyBlue, style: const TextStyle(color: Colors.white),
                  items: ['Upcoming', 'Completed', 'Postponed'].map((val) => DropdownMenuItem(value: val, child: Text(val))).toList(),
                  onChanged: (val) => setState(() => _status = val!),
                ),
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity, height: 55,
              child: ElevatedButton(
                onPressed: _isLoading ? null : updateHearing,
                style: ElevatedButton.styleFrom(backgroundColor: goldColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("SET HEARING FOR CLIENT", style: TextStyle(color: Color(0xFF101D3D), fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) => Padding(padding: const EdgeInsets.only(bottom: 8.0), child: Text(text, style: const TextStyle(color: Colors.white70, fontSize: 12)));

  Widget _buildTextField(TextEditingController controller, IconData icon, {VoidCallback? onTap, bool readOnly = false}) {
    return TextField(
      controller: controller, readOnly: readOnly, onTap: onTap,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: goldColor, size: 20),
        filled: true, fillColor: Colors.white.withOpacity(0.05),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }
}
