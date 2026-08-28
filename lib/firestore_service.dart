import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // --- Users Management (Merged Clients, Pending Lawyers, Verified Lawyers) ---
  Stream<List<Map<String, dynamic>>> getUsers() {
    final controller = StreamController<List<Map<String, dynamic>>>();
    List<Map<String, dynamic>> clients = [];
    List<Map<String, dynamic>> pendingLawyers = [];
    List<Map<String, dynamic>> verifiedLawyers = [];

    void syncData() {
      if (!controller.isClosed) {
        controller.add([...clients, ...pendingLawyers, ...verifiedLawyers]);
      }
    }

    final clientsSub = _db.collection('users').snapshots().listen((snap) {
      clients = snap.docs.map((doc) => {'id': doc.id, 'role': 'Client', ...doc.data()}).toList();
      syncData();
    });

    final pendingSub = _db.collection('lawyers').snapshots().listen((snap) {
      pendingLawyers = snap.docs.map((doc) => {'id': doc.id, 'role': 'Lawyer', 'isVerified': false, ...doc.data()}).toList();
      syncData();
    });

    final verifiedSub = _db.collection('verified_lawyers').snapshots().listen((snap) {
      verifiedLawyers = snap.docs.map((doc) => {'id': doc.id, 'role': 'Lawyer', 'isVerified': true, ...doc.data()}).toList();
      syncData();
    });

    controller.onCancel = () {
      clientsSub.cancel();
      pendingSub.cancel();
      verifiedSub.cancel();
    };

    return controller.stream;
  }

  // --- Case Management ---
  Stream<List<Map<String, dynamic>>> getCases() {
    return _db.collection('Case request').snapshots().map((s) =>
        s.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }

  Stream<List<Map<String, dynamic>>> getCaseRequests() => getCases(); // Added for consistency with case_requests.dart

  // --- Complaints Logic (Matching Image Structure) ---
  Stream<List<Map<String, dynamic>>> getComplaints() {
    return _db.collection('complaints').snapshots().map((s) =>
        s.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }

  Future<void> updateComplaintStatus({
    required String complaintId,
    required String status,
    required String? clientId,
    required String title,
    required String message,
    required String type,
    bool hasStrike = false, // Added parameter for strike tracking
  }) async {
    Map<String, dynamic> updateData = {'status': status};
    if (hasStrike) {
      updateData['hasStrike'] = true;
      updateData['actionTaken'] = 'Struck';
    }

    await _db.collection('complaints').doc(complaintId).update(updateData);

    if (clientId != null && clientId.isNotEmpty && clientId != 'null') {
      await _db.collection('notifications').add({
        'userId': clientId,
        'title': title,
        'body': message,
        'type': type,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> issueStrike({
    required String lawyerId,
    required String complaintId,
    required String reason,
  }) async {
    DocumentReference lawyerRef = _db.collection('lawyers').doc(lawyerId);
    DocumentSnapshot lawyerDoc = await lawyerRef.get();

    // Check verified_lawyers if not found in lawyers
    if (!lawyerDoc.exists) {
      DocumentReference verifiedRef = _db.collection('verified_lawyers').doc(lawyerId);
      DocumentSnapshot verifiedDoc = await verifiedRef.get();
      if (verifiedDoc.exists) {
        lawyerRef = verifiedRef;
        lawyerDoc = verifiedDoc;
      }
    }

    int currentStrikes = 0;
    if (lawyerDoc.exists) {
      final data = lawyerDoc.data() as Map<String, dynamic>?;
      if (data != null) {
        currentStrikes = data['strikesCount'] ?? 0;
      }
    }

    int newStrikes = currentStrikes + 1;

    Map<String, dynamic> updateData = {
      'strikesCount': newStrikes,
    };

    if (newStrikes >= 3) {
      updateData['isBlocked'] = true;
      updateData['status'] = 'blocked';
    }

    await lawyerRef.set(updateData, SetOptions(merge: true));

    // Updated to set hasStrike flag in Firestore
    await _db.collection('complaints').doc(complaintId).update({
      'status': 'Resolved',
      'hasStrike': true,
      'actionTaken': 'Struck',
    });

    await _db.collection('notifications').add({
      'userId': lawyerId,
      'lawyerId': lawyerId,
      'title': 'Strike Issued',
      'body': 'A strike has been issued against your account. Reason: $reason. Total strikes: $newStrikes/3',
      'message': 'A strike has been issued against your account. Reason: $reason. Total strikes: $newStrikes/3',
      'type': 'strike_issued',
      'createdAt': FieldValue.serverTimestamp(),
      'isRead': false,
    });
  }

  // --- Lawyer Verification Methods ---
  Stream<List<Map<String, dynamic>>> getPendingLawyers() => _db.collection('lawyers').snapshots().map((s) => s.docs.map((d) => {'id': d.id, 'role': 'Lawyer', ...d.data()}).toList());
  Stream<List<Map<String, dynamic>>> getVerifiedLawyers() => _db.collection('verified_lawyers').snapshots().map((s) => s.docs.map((d) => {'id': d.id, 'role': 'Lawyer', ...d.data()}).toList());

  Future<void> approveLawyer(String lawyerId, Map<String, dynamic> lawyerData) async {
    Map<String, dynamic> data = Map.from(lawyerData);
    data.remove('id'); data.remove('role');
    await _db.collection('verified_lawyers').doc(lawyerId).set({
      ...data,
      'isVerified': true,
      'status': 'Active',
      'createdAt': FieldValue.serverTimestamp(), // Added for sorting
    });
    await _db.collection('lawyers').doc(lawyerId).delete();
  }

  Future<void> rejectLawyer(String id) => _db.collection('lawyers').doc(id).delete();

  Future<void> updateUserStatus(String id, String r, String s, bool v) async {
    String col = r.toLowerCase() == 'lawyer' ? (v ? 'verified_lawyers' : 'lawyers') : 'users';
    await _db.collection(col).doc(id).update({
      'status': s,
      'isBlocked': s.toLowerCase() == 'blocked',
    });
  }

  Future<void> deleteUser(String id, String r, bool v) async {
    String col = r.toLowerCase() == 'lawyer' ? (v ? 'verified_lawyers' : 'lawyers') : 'users';
    await _db.collection(col).doc(id).delete();
  }
}