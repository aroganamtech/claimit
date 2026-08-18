/// Claimit Select in-app chat models.
///
/// A conversation is always shaped from the *caller's* perspective by the
/// backend — [otherName]/[otherPhotoUrl] are the person on the other side,
/// whichever role the caller happens to have in that thread.

class SelectConversation {
  final String id;
  final String professionalId;
  final String otherName;
  final String otherRole;
  final String otherPhotoUrl;
  final String lastMessage;
  final String lastMessageAt;   // ISO-8601, may be empty
  final int unreadCount;
  /// True when the caller is the listed professional in this thread (i.e. a
  /// customer messaged them), false when the caller is the customer.
  final bool iAmProfessional;

  const SelectConversation({
    required this.id,
    required this.professionalId,
    required this.otherName,
    required this.otherRole,
    required this.otherPhotoUrl,
    required this.lastMessage,
    required this.lastMessageAt,
    required this.unreadCount,
    required this.iAmProfessional,
  });

  factory SelectConversation.fromJson(Map<String, dynamic> j) {
    return SelectConversation(
      id: (j['id'] ?? '').toString(),
      professionalId: (j['professional_id'] ?? '').toString(),
      otherName: (j['other_name'] ?? '').toString(),
      otherRole: (j['other_role'] ?? '').toString(),
      otherPhotoUrl: (j['other_photo_url'] ?? '').toString(),
      lastMessage: (j['last_message'] ?? '').toString(),
      lastMessageAt: (j['last_message_at'] ?? '').toString(),
      unreadCount: (j['unread_count'] as num?)?.toInt() ?? 0,
      iAmProfessional: j['i_am_professional'] == true,
    );
  }
}

class SelectMessage {
  final String id;
  final String text;
  final String senderId;
  final bool isMine;
  final String createdAt;   // ISO-8601, may be empty

  const SelectMessage({
    required this.id,
    required this.text,
    required this.senderId,
    required this.isMine,
    required this.createdAt,
  });

  /// "14:32" — best-effort; returns empty if the server sent no timestamp.
  String get timeLabel {
    if (createdAt.trim().isEmpty) return '';
    final dt = DateTime.tryParse(createdAt);
    if (dt == null) return '';
    final local = dt.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  factory SelectMessage.fromJson(Map<String, dynamic> j) {
    return SelectMessage(
      id: (j['id'] ?? '').toString(),
      text: (j['text'] ?? '').toString(),
      senderId: (j['sender_id'] ?? '').toString(),
      isMine: j['is_mine'] == true,
      createdAt: (j['created_at'] ?? '').toString(),
    );
  }
}
