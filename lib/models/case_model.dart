import 'package:cloud_firestore/cloud_firestore.dart';

class CaseModel {
  final String id;
  final String clientName;
  final String caseType;
  final String leadLawyerId;
  final String leadLawyerName;
  final String? clientId;
  final List<String> assignedLawyers;
  final String status;
  final String? fileUrl;
  final String? fileName;
  final String? vakalatnamaUrl;
  final DateTime? createdAt;

  CaseModel({
    required this.id,
    required this.clientName,
    required this.caseType,
    required this.leadLawyerId,
    required this.leadLawyerName,
    this.clientId,
    required this.assignedLawyers,
    required this.status,
    this.fileUrl,
    this.fileName,
    this.vakalatnamaUrl,
    this.createdAt,
  });

  factory CaseModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return CaseModel(
      id: doc.id,
      clientName: data['clientName'] ?? data['client_name'] ?? data['userName'] ?? "Client",
      caseType: data['caseType'] ?? data['category'] ?? "Assigned Case",
      leadLawyerId: data['lawyerid'] ?? data['lawyerId'] ?? data['leadLawyerId'] ?? '',
      leadLawyerName: data['leadLawyerName'] ?? data['lawyerName'] ?? "Lead Lawyer",
      clientId: data['clientId'] ?? data['clientid'] ?? data['userId'],
      assignedLawyers: List<String>.from(data['assignedLawyers'] ?? []),
      status: data['status'] ?? 'active',
      fileUrl: data['fileUrl'],
      fileName: data['fileName'] ?? data['documentTitle'],
      vakalatnamaUrl: data['vakalatnamaUrl'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? (data['timestamp'] as Timestamp?)?.toDate(),
    );
  }
}
