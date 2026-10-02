import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/coordination_request.dart';
import '../models/lawyer_profile.dart';
import '../models/case_model.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import '../utils/client_notification_helper.dart';
import '../utils/client_app_config.dart';

class CoordinationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get currentUid => _auth.currentUser?.uid;

  Stream<List<CoordinationRequest>> getAcceptedRequests(String uid) {
    return _firestore
        .collection('coordination_requests')
        .where('status', isEqualTo: 'Accepted')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => CoordinationRequest.fromFirestore(doc))
            .where((req) => req.senderId == uid || req.receiverId == uid || req.users.contains(uid))
            .toList());
  }

  Stream<List<CoordinationRequest>> getIncomingRequests(String uid) {
    return _firestore
        .collection('coordination_requests')
        .where('receiverId', isEqualTo: uid)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => CoordinationRequest.fromFirestore(doc))
            .toList());
  }

  Stream<List<LawyerProfile>> getVerifiedLawyers(String currentUid) {
    return _firestore.collection('verified_lawyers').snapshots().map((snapshot) =>
        snapshot.docs
            .where((doc) => doc.id != currentUid)
            .map((doc) => LawyerProfile.fromFirestore(doc))
            .where((profile) => profile.isApproved)
            .toList());
  }

  Future<List<CaseModel>> getActiveCasesForCurrentLawyer() async {
    var casesSnapshot = await _firestore.collection('suit_a_file_request').get();
    return casesSnapshot.docs
        .where((doc) {
          var data = doc.data();
          String lawyerId = (data['lawyerid'] ?? data['lawyerId'] ?? data['leadLawyerId'] ?? '').toString().trim();
          List assigned = data['assignedLawyers'] ?? [];
          String status = (data['status'] ?? 'active').toString().toLowerCase().trim();
          return (lawyerId == currentUid || assigned.contains(currentUid)) &&
              (status == 'active' || status == 'accepted');
        })
        .map((doc) => CaseModel.fromFirestore(doc))
        .toList();
  }

  Future<void> sendCoordinationRequest({
    required String targetLawyerId,
    required String targetLawyerName,
    required String caseId,
    required String clientName,
  }) async {
    var currentLawyerDoc = await _firestore.collection('verified_lawyers').doc(currentUid).get();
    String senderName = currentLawyerDoc.data()?['fullName'] ?? currentLawyerDoc.data()?['name'] ?? "Lawyer";

    await _firestore.collection('coordination_requests').add({
      'senderId': currentUid,
      'senderName': senderName,
      'receiverId': targetLawyerId,
      'receiverName': targetLawyerName,
      'caseId': caseId,
      'clientName': clientName,
      'status': 'Pending',
      'isGroup': true,
      'users': [currentUid, targetLawyerId],
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Notifications
    await NotificationHelper.sendPushNotification(
      targetLawyerId,
      "New Coordination Request",
      "$senderName has invited you to coordinate on a case for $clientName.",
      {
        'type': 'coordination_request',
        'senderId': currentUid,
        'caseId': caseId,
      },
    );

    await _firestore.collection('notifications').add({
      'userId': targetLawyerId,
      'title': 'New Coordination Request',
      'body': '$senderName has invited you to coordinate on a case for $clientName.',
      'createdAt': FieldValue.serverTimestamp(),
      'type': 'coordination_request',
      'senderId': currentUid,
      'caseId': caseId,
      'isRead': false,
    });
  }

  Future<void> handleRequest(CoordinationRequest request, bool accept) async {
    if (accept) {
      var lawyerDoc = await _firestore.collection('verified_lawyers').doc(currentUid).get();
      String supportingLawyerName = lawyerDoc.data()?['fullName'] ?? lawyerDoc.data()?['name'] ?? "Supporting Lawyer";

      await _firestore.collection('coordination_requests').doc(request.id).update({
        'status': 'Accepted',
        'assignedLawyers': FieldValue.arrayUnion([currentUid, request.senderId]),
        'supportingLawyerName': supportingLawyerName,
      });

      // Sync Case
      await _syncCaseWithSupportingLawyer(request.caseId, supportingLawyerName);

      // Handle Team Chat & Client
      await _activateTeamChat(request, supportingLawyerName);
    } else {
      await _firestore.collection('coordination_requests').doc(request.id).update({'status': 'Rejected'});
    }
  }

  Future<void> _syncCaseWithSupportingLawyer(String caseId, String supportingLawyerName) async {
    var updateData = {
      'assignedLawyers': FieldValue.arrayUnion([currentUid]),
      'supportingLawyerId': currentUid,
      'supportingLawyerName': supportingLawyerName,
      'teamNames': FieldValue.arrayUnion([supportingLawyerName]),
    };

    var suitRef = _firestore.collection('suit_a_file_request').doc(caseId);
    if ((await suitRef.get()).exists) await suitRef.update(updateData);

    var caseRef = _firestore.collection('cases').doc(caseId);
    if ((await caseRef.get()).exists) await caseRef.update(updateData);
  }

  Future<void> _activateTeamChat(CoordinationRequest request, String supportingLawyerName) async {
    var suitSnap = await _firestore.collection('suit_a_file_request').doc(request.caseId).get();
    String? clientId = suitSnap.data()?['clientId'] ?? suitSnap.data()?['userId'] ?? suitSnap.data()?['created_by'];

    if (clientId != null && clientId.isNotEmpty) {
      await _firestore.collection('coordination_requests').doc(request.id).update({
        'users': FieldValue.arrayUnion([clientId])
      });

      var groupChatQuery = await _firestore.collection('group_chats').where('caseId', isEqualTo: request.caseId).get();
      for (var doc in groupChatQuery.docs) {
        await doc.reference.update({
          'users': FieldValue.arrayUnion([clientId, currentUid, request.senderId])
        });
      }

      // Notifications to Client & Main Lawyer
      await _notifyTeamChatActive(clientId, request.caseId, request.senderName, request.senderId);
    }
  }

  Future<void> _notifyTeamChatActive(String clientId, String caseId, String senderName, String senderId) async {
    String clientTitle = 'Case Team Formed';
    String clientBody = '$senderName has added a supporting lawyer to your case.';
    await _firestore.collection('notifications').add({
      'receiverId': clientId,
      'senderId': currentUid,
      'title': clientTitle,
      'body': clientBody,
      'type': 'team_chat_active',
      'caseId': caseId,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await NotificationHelper.sendPushNotification(clientId, clientTitle, clientBody, {'type': 'team_chat_active', 'caseId': caseId});

    String mainLawyerTitle = 'Coordination Request Accepted';
    String mainLawyerBody = 'A lawyer has accepted your coordination request.';
    await _firestore.collection('notifications').add({
      'receiverId': senderId,
      'senderId': currentUid,
      'title': mainLawyerTitle,
      'body': mainLawyerBody,
      'type': 'coordination_accepted',
      'caseId': caseId,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await NotificationHelper.sendPushNotification(senderId, mainLawyerTitle, mainLawyerBody, {'type': 'coordination_accepted', 'caseId': caseId});
  }

  Future<void> removeLawyerFromTeam(String caseId, String lawyerIdToRemove, String lawyerName) async {
    final batch = _firestore.batch();

    // 1. Remove lawyer from assignedLawyers list and track removed lawyers
    var caseRef = _firestore.collection('cases').doc(caseId);
    var suitRef = _firestore.collection('suit_a_file_request').doc(caseId);

    if ((await caseRef.get()).exists) {
      batch.update(caseRef, {
        'assignedLawyers': FieldValue.arrayRemove([lawyerIdToRemove]),
        'removedLawyers': FieldValue.arrayUnion([lawyerIdToRemove])
      });
    }
    if ((await suitRef.get()).exists) {
      batch.update(suitRef, {
        'assignedLawyers': FieldValue.arrayRemove([lawyerIdToRemove]),
        'removedLawyers': FieldValue.arrayUnion([lawyerIdToRemove])
      });
    }

    // 2. Update group chats to block access
    var groupChatQuery = await _firestore
        .collection('group_chats')
        .where('caseId', isEqualTo: caseId)
        .get();

    for (var gDoc in groupChatQuery.docs) {
      batch.update(gDoc.reference, {
        'removedLawyers': FieldValue.arrayUnion([lawyerIdToRemove]),
        'users': FieldValue.arrayRemove([lawyerIdToRemove])
      });
    }

    // 3. Delete coordination requests
    var reqQuery = await _firestore
        .collection('coordination_requests')
        .where('caseId', isEqualTo: caseId)
        .get();

    for (var doc in reqQuery.docs) {
      var rData = doc.data();
      if (rData['receiverId'] == lawyerIdToRemove || rData['senderId'] == lawyerIdToRemove) {
        batch.delete(doc.reference);
      }
    }

    await batch.commit();
  }

  Future<void> uploadPrivateLawyerDocument({
    required String caseId,
    required String title,
    required String notes,
    required PlatformFile? file,
  }) async {
    String fileUrl = '';
    if (file != null) {
      fileUrl = await uploadToCloudinary(file) ?? '';
      if (fileUrl.isEmpty) throw Exception("Cloudinary upload failed");
    }

    await _firestore
        .collection('cases')
        .doc(caseId)
        .collection('lawyer_private_documents')
        .add({
      'title': title,
      'notes': notes,
      'fileName': file?.name ?? 'No File Attached',
      'fileSize': file != null ? '${(file.size / 1024).toStringAsFixed(1)} KB' : '',
      'fileUrl': fileUrl,
      'sharedBy': currentUid,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot> getPrivateLawyerDocumentsStream(String caseId) {
    return _firestore
        .collection('cases')
        .doc(caseId)
        .collection('lawyer_private_documents')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<String?> uploadToCloudinary(PlatformFile file) async {
    final String cloudName = AppConfig.cloudinaryCloudName;
    final String uploadPreset = AppConfig.cloudinaryUploadPreset;

    try {
      final uri = Uri.parse("https://api.cloudinary.com/v1_1/$cloudName/auto/upload");
      var request = http.MultipartRequest("POST", uri);
      request.fields['upload_preset'] = uploadPreset;

      if (kIsWeb) {
        if (file.bytes == null) return null;
        request.files.add(http.MultipartFile.fromBytes('file', file.bytes!, filename: file.name));
      } else {
        if (file.path == null) return null;
        request.files.add(await http.MultipartFile.fromPath('file', file.path!));
      }
      var response = await request.send();
      if (response.statusCode == 200) {
        var responseData = await response.stream.toBytes();
        var jsonMap = jsonDecode(String.fromCharCodes(responseData));
        return jsonMap['secure_url'];
      }
      return null;
    } catch (e) {
      debugPrint("Cloudinary Upload Error: $e");
      return null;
    }
  }

  Future<void> uploadCaseDocument({
    required String caseId,
    required String title,
    required PlatformFile file,
  }) async {
    String? fileUrl = await uploadToCloudinary(file);
    if (fileUrl == null || fileUrl.isEmpty) throw Exception("Cloudinary upload failed");

    var lawyerDoc = await _firestore.collection('verified_lawyers').doc(currentUid).get();
    String lawyerName = lawyerDoc.data()?['fullName'] ?? lawyerDoc.data()?['name'] ?? "Supporting Lawyer";

    // 1. Save inside cases/{caseId}/documents
    await _firestore
        .collection('cases')
        .doc(caseId)
        .collection('documents')
        .add({
      'title': title,
      'fileName': file.name,
      'fileUrl': fileUrl,
      'uploadedBy': lawyerName,
      'uploadedById': currentUid,
      'uploadedByRole': 'Supporting Lawyer',
      'createdAt': FieldValue.serverTimestamp(),
    });

    // 2. Save inside global root 'documents' collection
    var caseDocFetch = await _firestore.collection('cases').doc(caseId).get();
    if (caseDocFetch.exists && caseDocFetch.data() != null) {
      var cData = caseDocFetch.data()!;
      String clientId = (cData['clientId'] ?? cData['clientid'] ?? cData['userId'] ?? '').toString();
      String leadLawyerId = (cData['lawyerid'] ?? cData['lawyerId'] ?? cData['leadLawyerId'] ?? '').toString();

      await _firestore.collection('documents').add({
        'caseId': caseId,
        'clientId': clientId,
        'lawyerId': leadLawyerId,
        'title': title,
        'fileName': file.name,
        'fileUrl': fileUrl,
        'uploadedBy': lawyerName,
        'uploadedById': currentUid,
        'uploadedByRole': 'Supporting Lawyer',
        'senderId': clientId,
        'receiverId': leadLawyerId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 3. Send Notification to Client
      String notifTitle = 'New Case Document';
      String notifBody = '$lawyerName has uploaded a new document: $title';

      await _firestore.collection('notifications').add({
        'receiverId': clientId,
        'userId': clientId,
        'senderId': currentUid,
        'title': notifTitle,
        'body': notifBody,
        'type': 'document_upload',
        'caseId': caseId,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await NotificationHelper.sendPushNotification(clientId, notifTitle, notifBody, {
        'type': 'document_upload',
        'caseId': caseId,
      });
    }
  }
}
