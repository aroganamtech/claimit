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
  // Structured address (Local Finds) — same shape as the website form.
  final String country;
  final String state;
  final String district;
  final String city;
  final String paymentMethod;
  final List<String> photos; // base64 strings
  final bool isAvailable;
  final String createdAt;

  // "classified" = Local Classifieds item/service post (fee Rs.250)
  // "local_find" = Local Finds business directory listing (fee Rs.730/year)
  final String listingType;
  final String businessName; // Local Finds only
  final String whatsapp;     // Local Finds only (optional)
  final String email;        // Local Finds only (optional)
  final String website;      // Local Finds only (optional)
  final String social;       // Local Finds only (optional)
  final String plan;         // Local Finds only: free | standard | premium
  final double? latitude;
  final double? longitude;
  final String paymentLinkId;
  final double amountPaid;

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
    this.country = '',
    this.state = '',
    this.district = '',
    this.city = '',
    this.paymentMethod = '',
    this.photos = const [],
    this.isAvailable = true,
    this.createdAt = '',
    this.listingType = 'classified',
    this.businessName = '',
    this.whatsapp = '',
    this.email = '',
    this.website = '',
    this.social = '',
    this.plan = 'free',
    this.latitude,
    this.longitude,
    this.paymentLinkId = '',
    this.amountPaid = 0,
  });

  bool get isLocalFind => listingType == 'local_find';

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
        country: j['country'] as String? ?? '',
        state: j['state'] as String? ?? '',
        district: j['district'] as String? ?? '',
        city: j['city'] as String? ?? '',
        paymentMethod: j['payment_method'] as String? ?? '',
        photos: (j['photos'] as List?)?.map((e) => e.toString()).toList() ?? [],
        isAvailable: j['is_available'] as bool? ?? true,
        createdAt: j['created_at']?.toString() ?? '',
        listingType: j['listing_type'] as String? ?? 'classified',
        businessName: j['business_name'] as String? ?? '',
        whatsapp: j['whatsapp'] as String? ?? '',
        email: j['email'] as String? ?? '',
        website: j['website'] as String? ?? '',
        social: j['social'] as String? ?? '',
        plan: j['plan'] as String? ?? 'free',
        latitude: (j['latitude'] as num?)?.toDouble(),
        longitude: (j['longitude'] as num?)?.toDouble(),
        paymentLinkId: j['payment_link_id'] as String? ?? '',
        amountPaid: (j['amount_paid'] as num?)?.toDouble() ?? 0,
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
        'country': country,
        'state': state,
        'district': district,
        'city': city,
        'payment_method': paymentMethod,
        'photos': photos,
        'listing_type': listingType,
        'business_name': businessName,
        'whatsapp': whatsapp,
        'email': email,
        'website': website,
        'social': social,
        'plan': plan,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        'payment_link_id': paymentLinkId,
        'amount_paid': amountPaid,
      };
}
