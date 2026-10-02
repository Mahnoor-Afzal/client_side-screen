import 'package:flutter/material.dart';
import '../services/coordination_service.dart';
import '../models/coordination_request.dart';
import '../models/lawyer_profile.dart';
import '../models/case_model.dart';

class CoordinationViewModel extends ChangeNotifier {
  final CoordinationService _service = CoordinationService();
  
  String _searchQuery = "";
  String get searchQuery => _searchQuery;

  void updateSearchQuery(String query) {
    _searchQuery = query.toLowerCase();
    notifyListeners();
  }

  String? get currentUid => _service.currentUid;

  Stream<List<CoordinationRequest>> get acceptedRequests => _service.getAcceptedRequests(currentUid ?? "");
  Stream<List<CoordinationRequest>> get incomingRequests => _service.getIncomingRequests(currentUid ?? "");
  Stream<List<LawyerProfile>> get verifiedLawyers => _service.getVerifiedLawyers(currentUid ?? "");

  Future<List<CaseModel>> getActiveCases() => _service.getActiveCasesForCurrentLawyer();

  Future<void> sendRequest({
    required String targetLawyerId,
    required String targetLawyerName,
    required String caseId,
    required String clientName,
  }) async {
    await _service.sendCoordinationRequest(
      targetLawyerId: targetLawyerId,
      targetLawyerName: targetLawyerName,
      caseId: caseId,
      clientName: clientName,
    );
  }

  Future<void> handleRequest(CoordinationRequest request, bool accept) async {
    await _service.handleRequest(request, accept);
  }
}
