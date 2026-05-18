class PolicyModel {
  final String id;
  final String userId;
  final String policyNumber;
  final String policyType;
  final String insurerName;
  final double premiumAmount;
  final double sumInsured;
  final DateTime startDate;
  final DateTime endDate;
  final String status;
  final List<String> coverages;

  PolicyModel({
    required this.id,
    required this.userId,
    required this.policyNumber,
    required this.policyType,
    required this.insurerName,
    required this.premiumAmount,
    required this.sumInsured,
    required this.startDate,
    required this.endDate,
    required this.status,
    required this.coverages,
  });

  factory PolicyModel.fromJson(Map<String, dynamic> json) {
    return PolicyModel(
      id: json['_id'] ?? json['id'] ?? '',
      userId: json['user_id'] ?? '',
      policyNumber: json['policy_number'] ?? '',
      policyType: json['policy_type'] ?? '',
      insurerName: json['insurer_name'] ?? '',
      premiumAmount: (json['premium_amount'] ?? 0).toDouble(),
      sumInsured: (json['sum_insured'] ?? 0).toDouble(),
      startDate: json['start_date'] != null
          ? DateTime.parse(json['start_date'])
          : DateTime.now(),
      endDate: json['end_date'] != null
          ? DateTime.parse(json['end_date'])
          : DateTime.now(),
      status: json['status'] ?? 'active',
      coverages: List<String>.from(json['coverages'] ?? []),
    );
  }

  bool get isActive => status == 'active' && endDate.isAfter(DateTime.now());
  
  int get daysToExpiry => endDate.difference(DateTime.now()).inDays;
}
