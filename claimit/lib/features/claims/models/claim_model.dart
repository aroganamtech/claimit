class ClaimModel {
  final String id;
  final String userId;
  final String claimNumber;
  final String claimType;
  final String policyNumber;
  final String description;
  final double claimAmount;
  final String status;
  final List<String> documents;
  final List<ClaimTimelineEvent> timeline;
  final DateTime incidentDate;
  final DateTime submittedAt;
  final DateTime? updatedAt;
  final String? rejectionReason;
  final double? approvedAmount;
  final String? assignedAgent;

  ClaimModel({
    required this.id,
    required this.userId,
    required this.claimNumber,
    required this.claimType,
    required this.policyNumber,
    required this.description,
    required this.claimAmount,
    required this.status,
    required this.documents,
    required this.timeline,
    required this.incidentDate,
    required this.submittedAt,
    this.updatedAt,
    this.rejectionReason,
    this.approvedAmount,
    this.assignedAgent,
  });

  factory ClaimModel.fromJson(Map<String, dynamic> json) {
    return ClaimModel(
      id: json['_id'] ?? json['id'] ?? '',
      userId: json['user_id'] ?? '',
      claimNumber: json['claim_number'] ?? '',
      claimType: json['claim_type'] ?? '',
      policyNumber: json['policy_number'] ?? '',
      description: json['description'] ?? '',
      claimAmount: (json['claim_amount'] ?? 0).toDouble(),
      status: json['status'] ?? 'pending',
      documents: List<String>.from(json['documents'] ?? []),
      timeline: (json['timeline'] as List<dynamic>? ?? [])
          .map((e) => ClaimTimelineEvent.fromJson(e))
          .toList(),
      incidentDate: json['incident_date'] != null
          ? DateTime.parse(json['incident_date'])
          : DateTime.now(),
      submittedAt: json['submitted_at'] != null
          ? DateTime.parse(json['submitted_at'])
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
      rejectionReason: json['rejection_reason'],
      approvedAmount: json['approved_amount']?.toDouble(),
      assignedAgent: json['assigned_agent'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'claim_number': claimNumber,
      'claim_type': claimType,
      'policy_number': policyNumber,
      'description': description,
      'claim_amount': claimAmount,
      'status': status,
      'documents': documents,
      'incident_date': incidentDate.toIso8601String(),
      'submitted_at': submittedAt.toIso8601String(),
    };
  }

  String get statusLabel {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'under_review':
        return 'Under Review';
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      case 'settled':
        return 'Settled';
      default:
        return status;
    }
  }
}

class ClaimTimelineEvent {
  final String status;
  final String message;
  final DateTime timestamp;
  final String? updatedBy;

  ClaimTimelineEvent({
    required this.status,
    required this.message,
    required this.timestamp,
    this.updatedBy,
  });

  factory ClaimTimelineEvent.fromJson(Map<String, dynamic> json) {
    return ClaimTimelineEvent(
      status: json['status'] ?? '',
      message: json['message'] ?? '',
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
      updatedBy: json['updated_by'],
    );
  }
}
