class UserModel {
  final String id;
  final String fullName;
  final String phone;
  final String? email;
  final String? avatarUrl;
  final String? location;       // selected area / locality
  final String? dateOfBirth;
  final String? address;
  final String? city;
  final String? state;
  final String? pincode;
  final String? aadharNumber;
  final String? panNumber;
  final bool isVerified;
  final DateTime createdAt;

  UserModel({
    required this.id,
    required this.fullName,
    required this.phone,
    this.email,
    this.avatarUrl,
    this.location,
    this.dateOfBirth,
    this.address,
    this.city,
    this.state,
    this.pincode,
    this.aadharNumber,
    this.panNumber,
    this.isVerified = false,
    required this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['_id'] ?? json['id'] ?? '',
      fullName: json['full_name'] ?? '',
      phone: json['phone'] ?? '',
      email: json['email'],
      avatarUrl: json['avatar_url'],
      location: json['location'],
      dateOfBirth: json['date_of_birth'],
      address: json['address'],
      city: json['city'],
      state: json['state'],
      pincode: json['pincode'],
      aadharNumber: json['aadhar_number'],
      panNumber: json['pan_number'],
      isVerified: json['is_verified'] ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': fullName,
      'phone': phone,
      'email': email,
      'avatar_url': avatarUrl,
      'location': location,
      'date_of_birth': dateOfBirth,
      'address': address,
      'city': city,
      'state': state,
      'pincode': pincode,
      'aadhar_number': aadharNumber,
      'pan_number': panNumber,
      'is_verified': isVerified,
      'created_at': createdAt.toIso8601String(),
    };
  }

  UserModel copyWith({
    String? fullName,
    String? email,
    String? avatarUrl,
    String? location,
    String? dateOfBirth,
    String? address,
    String? city,
    String? state,
    String? pincode,
    String? aadharNumber,
    String? panNumber,
  }) {
    return UserModel(
      id: id,
      fullName: fullName ?? this.fullName,
      phone: phone,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      location: location ?? this.location,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      address: address ?? this.address,
      city: city ?? this.city,
      state: state ?? this.state,
      pincode: pincode ?? this.pincode,
      aadharNumber: aadharNumber ?? this.aadharNumber,
      panNumber: panNumber ?? this.panNumber,
      isVerified: isVerified,
      createdAt: createdAt,
    );
  }
}
