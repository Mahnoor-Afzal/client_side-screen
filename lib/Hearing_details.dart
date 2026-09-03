import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
  // Step 1 Controllers
  final TextEditingController _caseNumberController = TextEditingController();
  final TextEditingController _caseTypeController = TextEditingController();
  final TextEditingController _caseYearController = TextEditingController();
  final TextEditingController _courtNameController = TextEditingController();
  final TextEditingController _judgeNameController = TextEditingController();

  String? _selectedDistrict;

  final List<String> _punjabDistricts = const [
    'Attock', 'Bahawalnagar', 'Bahawalpur', 'Bhakkar', 'Chakwal', 'Chiniot',
    'D.G.Khan', 'Faisalabad', 'Gujranwala', 'Gujrat', 'Hafizabad', 'Jhang',
    'Jhelum', 'Kasur', 'Khanewal', 'Khushab', 'Lahore', 'Layyah', 'Lodhran',
    'M.B.Din', 'Mianwali', 'Multan', 'Muzaffargarh', 'Nankana Sahib', 'Narowal',
    'Okara', 'Pakpattan', 'R.Y.Khan', 'Rajanpur', 'Rawalpindi', 'Sahiwal',
    'Sargodha', 'Sheikhupura', 'Sialkot', 'T.T.Singh', 'Vehari',
  ];

  // Step 2 Controllers
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _timeController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  // Automated/State Status
  String _status = 'Pending';
  String _scrapingStatus = 'Pending';
  bool _isLoading = false;
  bool _isScraping = false;
  bool _hasTriggeredFetch = false;
  bool _isStep1Saved = false;

  String? _resolvedClientId;
  StreamSubscription<DocumentSnapshot>? _caseSubscription;

  final Color navyBlue = const Color(0xFF101D3D);
  final Color goldColor = const Color(0xFFC5A358);

  @override
  bool get wantKeepAlive => true;

  bool get _isHighOrSupremeCourt {
    String court = _courtNameController.text.trim().toLowerCase();
    return court.contains('high') || court.contains('supreme');
  }

  @override
  void initState() {
    super.initState();
    _resolvedClientId = widget.clientId;

    _caseNumberController.addListener(_onFieldEdited);
    _caseTypeController.addListener(_onFieldEdited);
    _caseYearController.addListener(_onFieldEdited);
    _courtNameController.addListener(_onFieldEdited);
    _judgeNameController.addListener(_onFieldEdited);

    _loadExistingCaseData();
  }

  void _onFieldEdited() {
    if (_isStep1Saved) {
      setState(() {
        _isStep1Saved = false;
      });
    }
  }

  @override
  void dispose() {
    _caseSubscription?.cancel();
    _caseNumberController.dispose();
    _caseTypeController.dispose();
    _caseYearController.dispose();
    _courtNameController.dispose();
    _judgeNameController.dispose();
    _dateController.dispose();
    _timeController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  String _safeFormatDate(dynamic dateVal) {
    if (dateVal == null) return '';
    if (dateVal is Timestamp) {
      DateTime dt = dateVal.toDate();
      return "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}";
    }
    return dateVal.toString();
  }

  Future<void> _loadExistingCaseData() async {
    setState(() => _isLoading = true);
    try {
      if (_resolvedClientId == null || _resolvedClientId!.isEmpty) {
        var chatDoc = await FirebaseFirestore.instance.collection('chat').doc(widget.caseId).get();
        if (chatDoc.exists && mounted) {
          _resolvedClientId = chatDoc.data()?['clientId'] ?? chatDoc.data()?['userId'];
        }
      }

      var caseDoc = await FirebaseFirestore.instance.collection('cases').doc(widget.caseId).get();
      if (caseDoc.exists && mounted) {
        final data = caseDoc.data();
        if (data != null) {
          setState(() {
            _caseNumberController.text = (data['caseNumber'] ?? "").toString();
            _caseTypeController.text = (data['caseType'] ?? "").toString();
            _caseYearController.text = (data['caseYear'] ?? "").toString();
            _courtNameController.text = (data['courtName'] ?? "").toString();
            _judgeNameController.text = (data['judgeName'] ?? "").toString();
            _selectedDistrict = data['district'];

            if (_resolvedClientId == null || _resolvedClientId!.isEmpty) {
              _resolvedClientId = data['clientId'] ?? data['userId'];
            }
          });
        }
      }

      if (_isHighOrSupremeCourt) {
        var hearingDoc = await FirebaseFirestore.instance.collection('Hearings').doc(widget.caseId).get();
        if (hearingDoc.exists && mounted) {
          final hData = hearingDoc.data();
          if (hData != null) {
            setState(() {
              _dateController.text = _safeFormatDate(hData['hearingDate']);
              _timeController.text = (hData['hearingTime'] ?? "").toString();
              _descriptionController.text = (hData['hearingDescription'] ?? "").toString();
              _status = hData['status'] ?? 'Manual';
              _scrapingStatus = '';
              if (_caseNumberController.text.isNotEmpty) {
                _isStep1Saved = true;
                _hasTriggeredFetch = true;
              }
            });
          }
        }
      } else {
        var caseDoc = await FirebaseFirestore.instance.collection('cases').doc(widget.caseId).get();
        if (caseDoc.exists && mounted) {
          final data = caseDoc.data();
          if (data != null) {
            setState(() {
              String fetchedDate = _safeFormatDate(data['nextHearingDate'] ?? data['hearingDate']);
              String fetchedTime = (data['hearingTime'] ?? "").toString();

              if (fetchedDate.isNotEmpty || fetchedTime.isNotEmpty) {
                _dateController.text = fetchedDate;
                _timeController.text = fetchedTime;
                _status = data['status'] ?? 'Active';
                _scrapingStatus = data['scrapingStatus'] ?? 'Synced';
                _isStep1Saved = true;
                _hasTriggeredFetch = true;
                _listenToCaseScrapingUpdates(widget.caseId);
              } else {
                _dateController.clear();
                _timeController.clear();
                _status = data['status'] ?? 'Pending';
                _scrapingStatus = data['scrapingStatus'] ?? 'Pending';
                _hasTriggeredFetch = true;
                _isStep1Saved = true;
                _listenToCaseScrapingUpdates(widget.caseId);
              }
            });
          }
        }
      }
    } catch (e) {
      debugPrint("Error loading initial data: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _listenToCaseScrapingUpdates(String docId) {
    if (_isHighOrSupremeCourt) return;
    _caseSubscription?.cancel();
    _caseSubscription = FirebaseFirestore.instance
        .collection('cases')
        .doc(docId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists && mounted) {
        final data = snapshot.data();
        if (data != null) {
          setState(() {
            String fetchedDate = _safeFormatDate(data['nextHearingDate'] ?? data['hearingDate']);
            String fetchedTime = (data['hearingTime'] ?? "").toString();

            if (fetchedDate.isNotEmpty || fetchedTime.isNotEmpty) {
              _dateController.text = fetchedDate;
              _timeController.text = fetchedTime;
              _status = 'Active';
              _scrapingStatus = 'Synced';
            } else {
              _dateController.clear();
              _timeController.clear();
              _status = 'Pending';
              _scrapingStatus = 'Pending';
            }
          });
        }
      }
    });
  }

  bool _validateCaseYear() {
    String yearText = _caseYearController.text.trim();
    if (yearText.isEmpty) return true;
    int? year = int.tryParse(yearText);
    int currentYear = DateTime.now().year;
    if (year == null || year > currentYear) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Case year cannot be greater than $currentYear.'), backgroundColor: Colors.red),
      );
      return false;
    }
    return true;
  }

  Future<void> _submitCaseAndTriggerScraper() async {
    String inputCaseNum = _caseNumberController.text.trim();
    if (inputCaseNum.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter Case Number.')),
      );
      return;
    }

    if (!_isHighOrSupremeCourt && _selectedDistrict == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select District.')),
      );
      return;
    }

    if (!_validateCaseYear()) return;

    bool isHighSupreme = _isHighOrSupremeCourt;

    setState(() {
      _isScraping = !isHighSupreme;
      _hasTriggeredFetch = true;
      if (!isHighSupreme) {
        _scrapingStatus = 'Pending';
        _status = 'Pending';
        _dateController.clear();
        _timeController.clear();
        _descriptionController.clear();
      } else {
        _scrapingStatus = '';
        _status = 'Manual';
      }
    });

    try {
      String? uid = FirebaseAuth.instance.currentUser?.uid;

      final Map<String, dynamic> casePayload = {
        'caseId': widget.caseId,
        'caseNumber': inputCaseNum,
        'caseType': _caseTypeController.text.trim(),
        'caseYear': _caseYearController.text.trim(),
        'courtName': _courtNameController.text.trim(),
        'district': _selectedDistrict ?? '',
        'judgeName': _judgeNameController.text.trim(),
        'clientName': widget.clientName,
        'clientId': _resolvedClientId,
        'lawyerId': uid?.trim(),
        'status': isHighSupreme ? 'Manual' : 'Pending',
        'isSaved': false,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (!isHighSupreme) {
        casePayload['scrapingStatus'] = 'Pending';
        casePayload['nextHearingDate'] = '';
        casePayload['hearingTime'] = '';
        casePayload['hearingDescription'] = '';
      }

      await FirebaseFirestore.instance.collection('cases').doc(widget.caseId).set(casePayload, SetOptions(merge: true));

      if (!isHighSupreme) {
        _listenToCaseScrapingUpdates(widget.caseId);
      }

      if (mounted) {
        setState(() => _isStep1Saved = true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isHighSupreme
                ? "Case Details Saved! Enter hearing details manually."
                : "Case Details Saved! Automated scraping triggered..."),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Request Failed: $e"), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isScraping = false);
    }
  }

  // MANUAL UPDATE: Saves ONLY in 'Hearings' collection and notifies client
  Future<void> updateHearing() async {
    if (_dateController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select or enter next hearing date.')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      String? uid = FirebaseAuth.instance.currentUser?.uid;
      String courtLocationStr = "${_courtNameController.text.trim()}${_selectedDistrict != null ? ', $_selectedDistrict' : ''}";

      final hearingData = {
        'caseId': widget.caseId,
        'caseNumber': _caseNumberController.text.trim(),
        'caseType': _caseTypeController.text.trim(),
        'caseYear': _caseYearController.text.trim(),
        'courtName': _courtNameController.text.trim(),
        'courtLocation': courtLocationStr,
        'district': _selectedDistrict ?? '',
        'judgeName': _judgeNameController.text.trim(),
        'clientId': _resolvedClientId,
        'clientName': widget.clientName,
        'lawyerId': uid?.trim(),
        'hearingDate': _dateController.text,
        'hearingTime': _timeController.text,
        'hearingDescription': _descriptionController.text.trim(),
        'status': 'Manual',
        'isSaved': true,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // 1. Save main document in Hearings collection
      await FirebaseFirestore.instance.collection('Hearings').doc(widget.caseId).set(hearingData, SetOptions(merge: true));

      // 2. Save entry in history subcollection
      await FirebaseFirestore.instance
          .collection('Hearings')
          .doc(widget.caseId)
          .collection('history')
          .add({
        'hearingDate': _dateController.text,
        'hearingTime': _timeController.text,
        'hearingDescription': _descriptionController.text.trim().isNotEmpty ? _descriptionController.text.trim() : 'Manual hearing update',
        'courtLocation': courtLocationStr,
        'judgeName': _judgeNameController.text.trim(),
        'createdTimeStamp': FieldValue.serverTimestamp(),
      });

      // 3. Send Notification to Client
      if (_resolvedClientId != null && _resolvedClientId!.isNotEmpty) {
        await FirebaseFirestore.instance.collection('notifications').add({
          'receiverId': _resolvedClientId,
          'senderId': uid,
          'title': 'New Manual Hearing Scheduled',
          'body': 'Your hearing for case #${_caseNumberController.text.trim()} has been scheduled on ${_dateController.text} at ${_timeController.text}.',
          'type': 'hearing_update',
          'caseId': widget.caseId,
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Hearing details saved in Hearings and notification sent to client!'), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Scraped Hearing Save Function (Updates cases collection for automated scraping)
  Future<void> _saveScrapedHearingDetails() async {
    if (_dateController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hearing date available to save.')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      String? uid = FirebaseAuth.instance.currentUser?.uid;
      String courtLocationStr = "${_courtNameController.text.trim()}${_selectedDistrict != null ? ', $_selectedDistrict' : ''}";

      final hearingData = {
        'caseId': widget.caseId,
        'caseNumber': _caseNumberController.text.trim(),
        'caseType': _caseTypeController.text.trim(),
        'caseYear': _caseYearController.text.trim(),
        'courtName': _courtNameController.text.trim(),
        'courtLocation': courtLocationStr,
        'district': _selectedDistrict ?? '',
        'judgeName': _judgeNameController.text.trim(),
        'clientId': _resolvedClientId,
        'clientName': widget.clientName,
        'lawyerId': uid?.trim(),
        'hearingDate': _dateController.text,
        'hearingTime': _timeController.text,
        'hearingDescription': _descriptionController.text.trim(),
        'status': 'Active',
        'isSaved': true,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // 1. Save main document in Hearings
      await FirebaseFirestore.instance.collection('Hearings').doc(widget.caseId).set(hearingData, SetOptions(merge: true));

      // 2. Save entry in history subcollection
      await FirebaseFirestore.instance
          .collection('Hearings')
          .doc(widget.caseId)
          .collection('history')
          .add({
        'hearingDate': _dateController.text,
        'hearingTime': _timeController.text,
        'hearingDescription': _descriptionController.text.trim().isNotEmpty ? _descriptionController.text.trim() : 'Scraped Hearing Update',
        'courtLocation': courtLocationStr,
        'judgeName': _judgeNameController.text.trim(),
        'createdTimeStamp': FieldValue.serverTimestamp(),
      });

      // 3. Update cases collection for scraped workflow tracking
      await FirebaseFirestore.instance.collection('cases').doc(widget.caseId).set({
        'nextHearingDate': _dateController.text,
        'hearingTime': _timeController.text,
        'status': 'Active',
        'isSaved': true,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Scraped hearing details and history saved successfully!'), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickDate() async {
    DateTime now = DateTime.now();
    DateTime today = DateTime(now.year, now.month, now.day);

    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: today,
      firstDate: today,
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _dateController.text = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      });
    }
  }

  Future<void> _pickTime() async {
    TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      if (mounted) {
        setState(() {
          _timeController.text = picked.format(context);
        });
      }
    }
  }

  Widget _buildStatusBanner() {
    if (_isHighOrSupremeCourt || !_hasTriggeredFetch) return const SizedBox.shrink();
    bool isDone = (_scrapingStatus == 'Synced' || _scrapingStatus == 'Updated') && _dateController.text.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
          color: isDone ? Colors.green.withValues(alpha: 0.2) : Colors.orange.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isDone ? Colors.green : Colors.orange)
      ),
      child: Row(
        children: [
          isDone
              ? const Icon(Icons.check_circle, color: Colors.green, size: 20)
              : const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.orange, strokeWidth: 2)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isDone ? "Status: Hearing Details Synced / Ready" : "Status: Pending Scraper (Searching cause list...)",
              style: TextStyle(color: isDone ? Colors.green : Colors.orange, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, IconData icon, {bool readOnly = false, String hint = ""}) {
    return TextField(
      controller: controller,
      readOnly: readOnly,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: goldColor, size: 20),
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.05),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500)),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.05),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    bool isHighSupreme = _isHighOrSupremeCourt;

    return Scaffold(
      backgroundColor: navyBlue,
      appBar: AppBar(
        title: Text("Hearing Details: ${widget.clientName}", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(25),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("STEP 1: CASE INFORMATION", style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel("Case Number"),
                      TextField(controller: _caseNumberController, style: const TextStyle(color: Colors.white), decoration: _inputDecoration("e.g. 1234")),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel("Case Type"),
                      TextField(controller: _caseTypeController, style: const TextStyle(color: Colors.white), decoration: _inputDecoration("e.g. Civil")),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel("Case Year"),
                      TextField(controller: _caseYearController, keyboardType: TextInputType.number, maxLength: 4, inputFormatters: [FilteringTextInputFormatter.digitsOnly], style: const TextStyle(color: Colors.white), decoration: _inputDecoration("e.g. 2024").copyWith(counterText: "")),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel("Court Name"),
                      TextField(
                        controller: _courtNameController,
                        style: const TextStyle(color: Colors.white),
                        decoration: _inputDecoration("e.g. District Court / High Court"),
                        onChanged: (val) {
                          setState(() {});
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel("District"),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(12)),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedDistrict,
                            hint: const Text("Select District", style: TextStyle(color: Colors.white24, fontSize: 13)),
                            isExpanded: true,
                            dropdownColor: navyBlue,
                            style: const TextStyle(color: Colors.white),
                            items: _punjabDistricts.map((dist) => DropdownMenuItem(value: dist, child: Text(dist, style: const TextStyle(fontSize: 13)))).toList(),
                            onChanged: (val) {
                              setState(() {
                                _selectedDistrict = val;
                                _isStep1Saved = false;
                              });
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel("Judge Name"),
                      TextField(controller: _judgeNameController, style: const TextStyle(color: Colors.white), decoration: _inputDecoration("e.g. Uzair")),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 25),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                onPressed: (_isScraping || _isStep1Saved) ? null : _submitCaseAndTriggerScraper,
                icon: _isScraping
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.amber, strokeWidth: 2))
                    : Icon(_isStep1Saved ? Icons.check_circle : Icons.save, color: _isStep1Saved ? Colors.grey : goldColor),
                label: Text(
                  _isScraping
                      ? "SAVING & SCRAPING..."
                      : (_isStep1Saved ? "DETAILS SAVED" : "SAVE DETAILS"),
                  style: TextStyle(
                      color: _isStep1Saved ? Colors.grey : goldColor,
                      fontWeight: FontWeight.bold
                  ),
                ),
                style: OutlinedButton.styleFrom(
                    side: BorderSide(color: _isStep1Saved ? Colors.grey : goldColor, width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                ),
              ),
            ),

            if (_hasTriggeredFetch) ...[
              const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Divider(color: Colors.white24)),
              _buildStatusBanner(),
              Text(
                isHighSupreme ? "STEP 2: MANUAL HEARING DETAILS" : "STEP 2: AUTOMATED / SCRAPED HEARING DETAILS",
                style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 15),
              _buildLabel("Next Hearing Date"),
              GestureDetector(
                onTap: isHighSupreme ? _pickDate : null,
                child: AbsorbPointer(
                  absorbing: isHighSupreme,
                  child: _buildTextField(
                    _dateController,
                    Icons.calendar_today,
                    readOnly: !isHighSupreme,
                    hint: isHighSupreme ? "Tap to select hearing date" : "Waiting for scraper...",
                  ),
                ),
              ),
              const SizedBox(height: 15),
              _buildLabel("Hearing Time"),
              GestureDetector(
                onTap: isHighSupreme ? _pickTime : null,
                child: AbsorbPointer(
                  absorbing: isHighSupreme,
                  child: _buildTextField(
                    _timeController,
                    Icons.access_time,
                    readOnly: !isHighSupreme,
                    hint: isHighSupreme ? "Tap to select hearing time" : "Waiting for scraper...",
                  ),
                ),
              ),
              const SizedBox(height: 15),

              if (isHighSupreme) ...[
                _buildLabel("Hearing Description"),
                TextField(
                  controller: _descriptionController,
                  maxLines: 3,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration("Enter case hearing details/notes..."),
                ),
              ] else ...[
                _buildLabel("Hearing Status"),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(12)),
                  child: Text(
                    _status,
                    style: TextStyle(
                      color: _status == 'Pending' ? Colors.amber : (_status == 'Active' ? Colors.green : Colors.white),
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 35),

              SizedBox(
                width: double.infinity,
                height: 55,
                child: isHighSupreme
                    ? ElevatedButton(
                  onPressed: _isLoading ? null : updateHearing,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: goldColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                    "UPDATE DETAILS",
                    style: TextStyle(
                        color: Color(0xFF101D3D),
                        fontWeight: FontWeight.bold,
                        fontSize: 16),
                  ),
                )
                    : OutlinedButton.icon(
                  onPressed: _isLoading ? null : _saveScrapedHearingDetails,
                  icon: Icon(
                    _status == 'Active' ? Icons.check_circle : Icons.hourglass_top,
                    color: _status == 'Active' ? Colors.green : Colors.amber,
                  ),
                  label: Text(
                    _status == 'Active' ? "SAVE HEARING DETAILS" : "SAVE HEARING DETAILS",
                    style: TextStyle(
                      color: _status == 'Active' ? Colors.green : Colors.amber,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: _status == 'Active' ? Colors.green : Colors.amber,
                      width: 1.5,
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}