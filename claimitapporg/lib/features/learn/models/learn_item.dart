/// A single "Learn Claimit" lesson — a question + its answer video.
/// Admin adds these from the web panel; GET /learn returns the list.
class LearnItem {
  final String id;
  final String question;
  final String videoUrl;
  final int likeCount;

  /// Whether the currently logged-in user has already liked this lesson.
  final bool likedByMe;

  const LearnItem({
    required this.id,
    required this.question,
    required this.videoUrl,
    required this.likeCount,
    this.likedByMe = false,
  });

  factory LearnItem.fromJson(Map<String, dynamic> j) => LearnItem(
        id: j['id'] as String? ?? '',
        question: j['question'] as String? ?? '',
        videoUrl: j['video_url'] as String? ?? '',
        likeCount: (j['like_count'] as num?)?.toInt() ?? 0,
        likedByMe: j['liked_by_me'] as bool? ?? false,
      );
}
