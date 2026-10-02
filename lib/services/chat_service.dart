import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:rxdart/rxdart.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static final Map<String, Map<String, dynamic>> _userCache = {};
  String? get currentUserId => _auth.currentUser?.uid;

  /// Optimized Message Sending with Batch Write
  Future<void> sendMessage({
    required String chatId,
    required String text,
    required String senderName,
    required String senderRole,
    required String targetCollection,
    String? receiverId,
    Map<String, dynamic>? replyTo,
    Map<String, dynamic>? extraChatData,
  }) async {
    if (currentUserId == null || text.trim().isEmpty) return;

    final batch = _firestore.batch();
    final chatDocRef = _firestore.collection(targetCollection).doc(chatId);
    final msgRef = chatDocRef.collection('messages').doc();

    final msgData = {
      'senderId': currentUserId,
      'receiverId': receiverId,
      'text': text,
      'message': text,
      'timestamp': FieldValue.serverTimestamp(),
      'isSeen': false,
      'isRead': false,
      'readBy': [currentUserId],
      'senderName': senderName,
      'senderRole': senderRole,
      'replyTo': replyTo,
      'deletedFor': [],
      'isDeletedForEveryone': false,
    };

    batch.set(msgRef, msgData);
    
    final Map<String, dynamic> chatUpdate = {
      'lastMessage': text,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'lastSenderId': currentUserId,
      ...extraChatData ?? {},
    };
    
    batch.set(chatDocRef, chatUpdate, SetOptions(merge: true));
    await batch.commit();
  }

  /// Bulk Mark as Read
  Future<void> markAsRead(String chatId, String targetCollection) async {
    final uid = currentUserId;
    if (uid == null) return;

    try {
      final query = await _firestore
          .collection(targetCollection)
          .doc(chatId)
          .collection('messages')
          .where('isRead', isEqualTo: false)
          .get();

      if (query.docs.isEmpty) return;

      final batch = _firestore.batch();
      for (var doc in query.docs) {
        final data = doc.data();
        if (data['senderId'] != uid) {
          batch.update(doc.reference, {
            'isRead': true,
            'isSeen': true,
            'readBy': FieldValue.arrayUnion([uid])
          });
        }
      }
      
      batch.update(_firestore.collection(targetCollection).doc(chatId), {
        'unreadCount.$uid': 0,
        'isRead': true
      });

      await batch.commit();
    } catch (e) {
      debugPrint("MarkRead Error: $e");
    }
  }

  /// Delete message logic (Centralized)
  Future<void> deleteMessage({
    required String chatId,
    required String messageId,
    required String targetCollection,
    required bool forEveryone,
  }) async {
    final uid = currentUserId;
    if (uid == null) return;

    final msgRef = _firestore
        .collection(targetCollection)
        .doc(chatId)
        .collection('messages')
        .doc(messageId);

    if (forEveryone) {
      await msgRef.update({
        'text': 'This message was deleted',
        'message': 'This message was deleted',
        'isDeleted': true,
        'isDeletedForEveryone': true,
        'replyTo': null,
        'replyToMessage': null,
      });
    } else {
      await msgRef.update({
        'deletedFor': FieldValue.arrayUnion([uid]),
      });
    }
  }

  /// Single location to fetch profiles (Cached)
  Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    if (_userCache.containsKey(uid)) return _userCache[uid];

    try {
      DocumentSnapshot doc = await _firestore.collection('verified_lawyers').doc(uid).get();
      if (!doc.exists) doc = await _firestore.collection('verified_lawyer').doc(uid).get();
      if (!doc.exists) doc = await _firestore.collection('users').doc(uid).get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        _userCache[uid] = data;
        return data;
      }
    } catch (e) {
      debugPrint("Profile Fetch Error: $e");
    }
    return null;
  }

  /// Stream messages for a specific chat
  Stream<QuerySnapshot> getMessagesStream(String chatId, String targetCollection) {
    return _firestore
        .collection(targetCollection)
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  /// Get or Create Group Chat ID for a case
  Future<String> getOrCreateGroupChatId(String caseId, String clientName) async {
    final query = await _firestore
        .collection('group_chats')
        .where('caseId', isEqualTo: caseId)
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) {
      return query.docs.first.id;
    } else {
      final docRef = await _firestore.collection('group_chats').add({
        'caseId': caseId,
        'clientName': clientName,
        'isGroup': true,
        'createdAt': FieldValue.serverTimestamp(),
        'users': [],
      });
      return docRef.id;
    }
  }

  /// Shared method to close cases
  Future<void> closeCase(String chatId, String? requestId) async {
    final batch = _firestore.batch();
    
    // Update main chat
    batch.update(_firestore.collection('chat').doc(chatId), {'status': 'closed'});
    
    // Update requests if exist
    if (requestId != null) {
      batch.update(_firestore.collection('suit_a_file_request').doc(requestId), {'status': 'closed'});
      batch.update(_firestore.collection('consultation_request').doc(requestId), {'status': 'closed'});
    }
    
    await batch.commit().catchError((e) => debugPrint("Close Case Error: $e"));
  }

  /// Accept consultation and initialize chat
  Future<void> acceptConsultation({
    required String docId,
    required Map<String, dynamic> data,
    required String collection,
  }) async {
    final uid = currentUserId;
    if (uid == null) return;

    final batch = _firestore.batch();

    // 1. Update request status
    batch.update(_firestore.collection(collection).doc(docId), {
      'status': 'Accepted',
    });

    // 2. Initialize chat document
    String chatType = (data['type'] ?? 'Consultation').toString().toLowerCase();
    
    final chatDocRef = _firestore.collection('chat').doc(docId);
    batch.set(chatDocRef, {
      'lawyerId': uid,
      'clientId': data['clientId'],
      'clientName': data['clientName'],
      'status': 'Active',
      'type': chatType,
      'lastMessage': '$chatType started',
      'updatedAt': FieldValue.serverTimestamp(),
      'users': [data['clientId'], uid],
    }, SetOptions(merge: true));

    await batch.commit();
  }

  /// Shared method to check case status
  Stream<bool> getCaseStatusStream(String chatId, String targetCollection, {String? requestId}) {
    // 1. Listen to the chat document itself
    final chatStream = _firestore.collection(targetCollection).doc(chatId).snapshots().map((doc) {
      if (!doc.exists) return false;
      String status = (doc.data()?['status'] ?? '').toString().toLowerCase();
      return status == 'closed' || status == 'completed';
    });

    // 2. Listen to potential request documents
    final String reqId = requestId ?? chatId;
    final List<String> requestCols = ['suit_a_file_request', 'consultation_request', 'coordination_requests'];
    
    final List<Stream<bool>> streams = [chatStream];
    
    for (String col in requestCols) {
      streams.add(_firestore.collection(col).doc(reqId).snapshots().map((doc) {
        if (!doc.exists) return false;
        String status = (doc.data()?['status'] ?? '').toString().toLowerCase();
        return status == 'closed' || status == 'completed';
      }));
    }

    return Rx.combineLatest(streams, (List<bool> statuses) => statuses.any((element) => element));
  }
}
