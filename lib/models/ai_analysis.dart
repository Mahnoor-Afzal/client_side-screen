class AiAnalysis {
  final bool isLegal;
  final String? caseType;
  final String? category;
  final String? bestLawyer;
  final String? reason;
  final String? priorityLevel;
  final String? nextStep;
  final String? message;

  AiAnalysis({
    required this.isLegal,
    this.caseType,
    this.category,
    this.bestLawyer,
    this.reason,
    this.priorityLevel,
    this.nextStep,
    this.message,
  });

  factory AiAnalysis.fromJson(Map<String, dynamic> json) {
    return AiAnalysis(
      isLegal: json['is_legal'] ?? false,
      caseType: json['case_type'],
      category: json['category'],
      bestLawyer: json['best_lawyer'],
      reason: json['reason'],
      priorityLevel: json['priority_level'],
      nextStep: json['next_step'],
      message: json['message'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'is_legal': isLegal,
      'case_type': caseType,
      'category': category,
      'best_lawyer': bestLawyer,
      'reason': reason,
      'priority_level': priorityLevel,
      'next_step': nextStep,
      'message': message,
    };
  }
}
