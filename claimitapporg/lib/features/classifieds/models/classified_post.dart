class ClassifiedPost {
  final String id;
  final String userId;
  final String userName;
  final String userPhone;
  final String category;
  final String subcategory;
  final String title;
  final String description;
  final double price;
  final int yearsOfExp;
  final String pincode;
  final String area;
  final String address;
  final String paymentMethod;
  final List<String> photos; // base64 strings
  final bool isAvailable;
  final String createdAt;

  const ClassifiedPost({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userPhone,
    required this.category,
    required this.subcategory,
    required this.title,
    required this.description,
    required this.price,
    required this.yearsOfExp,
    required this.pincode,
    required this.area,
    required this.address,
    this.paymentMethod = '',
    this.photos = const [],
    this.isAvailable = true,
    this.createdAt = '',
  });

  factory ClassifiedPost.fromJson(Map<String, dynamic> j) => ClassifiedPost(
        id: j['id'] as String? ?? '',
        userId: j['user_id'] as String? ?? '',
        userName: j['user_name'] as String? ?? '',
        userPhone: j['user_phone'] as String? ?? '',
        category: j['category'] as String? ?? '',
        subcategory: j['subcategory'] as String? ?? '',
        title: j['title'] as String? ?? '',
        description: j['description'] as String? ?? '',
        price: (j['price'] as num?)?.toDouble() ?? 0,
        yearsOfExp: (j['years_of_exp'] as num?)?.toInt() ?? 0,
        pincode: j['pincode'] as String? ?? '',
        area: j['area'] as String? ?? '',
        address: j['address'] as String? ?? '',
        paymentMethod: j['payment_method'] as String? ?? '',
        photos: (j['photos'] as List?)?.map((e) => e.toString()).toList() ?? [],
        isAvailable: j['is_available'] as bool? ?? true,
        createdAt: j['created_at']?.toString() ?? '',
      );

  Map<String, dynamic> toJson() => {
        'category': category,
        'subcategory': subcategory,
        'title': title,
        'description': description,
        'price': price,
        'years_of_exp': yearsOfExp,
        'pincode': pincode,
        'area': area,
        'address': address,
        'payment_method': paymentMethod,
        'photos': photos,
      };
}
