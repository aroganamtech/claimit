class FeedbackModel {
  final String id;
  final String category;     // feedback | complaint | suggestion
  final String subject;
  final String message;
  final String status;       // open | replied | closed
  final String? adminReply;
  final DateTime createdAt;
  final DateTime? repliedAt;

  FeedbackModel({
    required this.id,
    required this.category,
    required this.subject,
    required this.message,
    required this.status,
    this.adminReply,
    required this.createdAt,
    this.repliedAt,
  });

  bool get hasReply => (adminReply ?? '').isNotEmpty;

  factory FeedbackModel.fromJson(Map<String, dynamic> json) {
    return FeedbackModel(
      id:        json['id'] ?? json['_id'] ?? '',
      category:  json['category'] ?? 'feedback',
      subject:   json['subject'] ?? '',
      message:   json['message'] ?? '',
      status:    json['status'] ?? 'open',
      adminReply: json['admin_reply'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      repliedAt: json['replied_at'] != null
          ? DateTime.tryParse(json['replied_at'].toString())
          : null,
    );
  }
}
