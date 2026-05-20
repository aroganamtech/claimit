class ReelItem {
  final String id;
  final String shopName;
  final String shopLocation;
  final String shopCategory;
  final String caption;
  final String offer;
  final String videoUrl;
  final String thumbnailUrl;
  final int likeCount;
  final int viewCount;
  final String tag;

  /// Whether the currently logged-in user has already liked this reel.
  /// Returned by the backend based on the JWT — used to show the red heart.
  final bool likedByMe;

  const ReelItem({
    required this.id,
    required this.shopName,
    required this.shopLocation,
    required this.shopCategory,
    required this.caption,
    required this.offer,
    required this.videoUrl,
    required this.thumbnailUrl,
    required this.likeCount,
    required this.viewCount,
    required this.tag,
    this.likedByMe = false,
  });

  factory ReelItem.fromJson(Map<String, dynamic> j) => ReelItem(
        id: j['id'] as String? ?? '',
        shopName: j['shop_name'] as String? ?? '',
        shopLocation: j['shop_location'] as String? ?? '',
        shopCategory: j['shop_category'] as String? ?? '',
        caption: j['caption'] as String? ?? '',
        offer: j['offer'] as String? ?? '',
        videoUrl: j['video_url'] as String? ?? '',
        thumbnailUrl: j['thumbnail_url'] as String? ?? '',
        likeCount: (j['like_count'] as num?)?.toInt() ?? 0,
        viewCount: (j['view_count'] as num?)?.toInt() ?? 0,
        tag: j['tag'] as String? ?? '',
        likedByMe: j['liked_by_me'] as bool? ?? false,
      );
}
