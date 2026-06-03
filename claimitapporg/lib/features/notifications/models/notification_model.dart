class NotificationModel {
  final String id;
  final String userId;
  final String title;
  final String message;
  final String type;
  final bool isRead;
  final String? claimId;
  final String? reviewId;   // set for bill_review_approved / bill_review_rejected
  final DateTime createdAt;

  NotificationModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.message,
    required this.type,
    required this.isRead,
    this.claimId,
    this.reviewId,
    required this.createdAt,
  });

  bool get isBillReviewApproved => type == 'bill_review_approved';
  bool get isBillReviewRejected => type == 'bill_review_rejected';
  bool get isBillReview         => isBillReviewApproved || isBillReviewRejected;

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id:       json['_id'] ?? json['id'] ?? '',
      userId:   json['user_id'] ?? '',
      title:    json['title'] ?? json['heading'] ?? '',
      // backends use either 'message' or 'body'
      message:  json['message'] ?? json['body'] ?? json['description'] ?? '',
      type:     json['type'] ?? 'info',
      // backends use either 'is_read' or 'read'
      isRead:   json['is_read'] ?? json['read'] ?? false,
      claimId:  json['claim_id'],
      reviewId: json['review_id'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
    );
  }
}
