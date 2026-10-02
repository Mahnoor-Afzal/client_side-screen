import 'package:cloud_firestore/cloud_firestore.dart';

class CoordinationRequest {
  final String id;
  final String senderId;
  final String senderName;
  final String receiverId;
  final String receiverName;
  final String caseId;
  final String clientName;
  final String status;
  final bool isGroup;
  final List<String> users;
  final DateTime? createdAt;

  CoordinationRequest({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.receiverId,
    required this.receiverName,
    required this.caseId,
    required this.clientName,
    required this.status,
    required this.isGroup,
    required this.users,
    this.createdAt,
  });

  factory CoordinationRequest.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return CoordinationRequest(
      id: doc.id,
      senderId: data['senderId'] ?? '',
      senderName: data['senderName'] ?? '',
      receiverId: data['receiverId'] ?? '',
      receiverName: data['receiverName'] ?? '',
      caseId: data['caseId'] ?? '',
      clientName: data['clientName'] ?? '',
      status: data['status'] ?? 'Pending',
      isGroup: data['isGroup'] ?? false,
      users: List<String>.from(data['users'] ?? []),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'senderId': senderId,
      'senderName': senderName,
      'receiverId': receiverId,
      'receiverName': receiverName,
      'caseId': caseId,
      'clientName': clientName,
      'status': status,
      'isGroup': isGroup,
      'users': users,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
    };
  }
}
