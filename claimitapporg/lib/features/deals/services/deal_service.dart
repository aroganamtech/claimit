// ─────────────────────────────────────────────────────────────────────────────
// DealService
//
// ARCHITECTURE NOTE
// ─────────────────
// Data is served from in-memory dummy maps below.
// When the real backend is ready:
//   1. Replace _fetchFromApi() with actual http / dio calls.
//   2. Keep the same public API (Future<List<DealDto>>).
//
// JSON shape per deal:
//   { id, name, location, offer, distance, type, image_url,
//     description, address, phone, timing, rating, reviews,
//     deal_group }   ← 'nearby' | 'brand'
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';

class DealDto {
  final String id;
  final String name;
  final String location;
  final String offer;
  final String distance;
  final String type;
  final String imageUrl;
  final String description;
  final String address;
  final String phone;
  final String timing;
  final double rating;
  final int reviews;
  final String dealGroup; // 'nearby' | 'brand'

  const DealDto({
    required this.id,
    required this.name,
    required this.location,
    required this.offer,
    required this.distance,
    required this.type,
    required this.imageUrl,
    required this.description,
    required this.address,
    required this.phone,
    required this.timing,
    required this.rating,
    required this.reviews,
    required this.dealGroup,
  });

  factory DealDto.fromJson(Map<String, dynamic> j) => DealDto(
        id: j['id'] as String,
        name: j['name'] as String,
        location: j['location'] as String,
        offer: j['offer'] as String,
        distance: j['distance'] as String,
        type: j['type'] as String,
        imageUrl: j['image_url'] as String,
        description: j['description'] as String? ?? '',
        address: j['address'] as String? ?? '',
        phone: j['phone'] as String? ?? '',
        timing: j['timing'] as String? ?? '',
        rating: (j['rating'] as num).toDouble(),
        reviews: j['reviews'] as int? ?? 0,
        dealGroup: j['deal_group'] as String? ?? 'nearby',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'location': location,
        'offer': offer,
        'distance': distance,
        'type': type,
        'image_url': imageUrl,
        'description': description,
        'address': address,
        'phone': phone,
        'timing': timing,
        'rating': rating,
        'reviews': reviews,
        'deal_group': dealGroup,
      };
}

class DealService {
  DealService._();
  static final DealService instance = DealService._();

  static const _delay = Duration(milliseconds: 350);

  // ── Public API ─────────────────────────────────────────────────────────────

  /// GET /api/deals
  Future<List<DealDto>> fetchAllDeals() async {
    await Future.delayed(_delay);
    return _fetchFromApi();
  }

  /// GET /api/deals?group=nearby
  Future<List<DealDto>> fetchNearbyDeals() async {
    await Future.delayed(_delay);
    return _fetchFromApi().where((d) => d.dealGroup == 'nearby').toList();
  }

  /// GET /api/deals?group=brand
  Future<List<DealDto>> fetchBrandDeals() async {
    await Future.delayed(_delay);
    return _fetchFromApi().where((d) => d.dealGroup == 'brand').toList();
  }

  /// GET /api/deals/:id
  Future<DealDto?> fetchDealById(String id) async {
    await Future.delayed(_delay);
    try {
      return _fetchFromApi().firstWhere((d) => d.id == id);
    } catch (_) {
      return null;
    }
  }

  // ── Private: dummy data source ─────────────────────────────────────────────

  List<DealDto> _fetchFromApi() =>
      _dealJsonDummy.map(DealDto.fromJson).toList();

  static const List<Map<String, dynamic>> _dealJsonDummy = [
    // ── Nearby deals ─────────────────────────────────────────────────────────
    {
      'id': 'd1', 'deal_group': 'nearby',
      'name': 'Smile Dentist', 'location': 'Padi, Chennai',
      'offer': '25% Off on All Treatments', 'distance': '6 Km', 'type': 'Clinic',
      'image_url': 'https://images.unsplash.com/photo-1588776814546-ec7eb8e02bb5?w=700&q=80',
      'description': 'Smile Dentist offers world-class dental care with experienced professionals. Get 25% off on all treatments including cleaning, fillings, and orthodontics.',
      'address': '12, 3rd Street, Padi, Chennai - 600050',
      'phone': '+91 98765 43210', 'timing': 'Mon–Sat: 9am – 8pm',
      'rating': 4.5, 'reviews': 128,
    },
    {
      'id': 'd2', 'deal_group': 'nearby',
      'name': 'CK Bakers', 'location': 'Anna Nagar, Chennai',
      'offer': 'Buy 2 Get 1 Free on Cakes', 'distance': '3 Km', 'type': 'Bakery',
      'image_url': 'https://images.unsplash.com/photo-1568254183919-78a4f43a2877?w=700&q=80',
      'description': 'CK Bakers is Anna Nagar\'s favourite bakery since 1995. Freshly baked breads, cakes and pastries every day.',
      'address': '45, 2nd Avenue, Anna Nagar, Chennai - 600040',
      'phone': '+91 98765 12345', 'timing': 'Daily: 7am – 10pm',
      'rating': 4.3, 'reviews': 312,
    },
    {
      'id': 'd3', 'deal_group': 'nearby',
      'name': 'India Mart', 'location': 'Padi, Chennai',
      'offer': '25% Off on All Grocery', 'distance': '2 Km', 'type': 'Supermarket',
      'image_url': 'https://images.unsplash.com/photo-1534723452862-4c874018d66d?w=700&q=80',
      'description': 'Your one-stop shop for all groceries. Fresh vegetables, fruits, dairy and household essentials — all under one roof.',
      'address': '89, Industrial Estate, Padi, Chennai - 600050',
      'phone': '+91 44 2651 1234', 'timing': 'Daily: 8am – 9pm',
      'rating': 4.1, 'reviews': 245,
    },
    {
      'id': 'd4', 'deal_group': 'nearby',
      'name': 'Fitness First', 'location': 'Velachery, Chennai',
      'offer': '50% Off on 3-Month Membership', 'distance': '8 Km', 'type': 'Gym',
      'image_url': 'https://images.unsplash.com/photo-1534438327276-14e5300c3a48?w=700&q=80',
      'description': 'State-of-the-art gym with premium equipment, personal trainers and group classes.',
      'address': '100 Feet Road, Velachery, Chennai - 600042',
      'phone': '+91 98400 55555', 'timing': 'Mon–Sat: 5am – 11pm | Sun: 6am – 9pm',
      'rating': 4.6, 'reviews': 189,
    },
    {
      'id': 'd5', 'deal_group': 'nearby',
      'name': 'Naturals Salon', 'location': 'Nungambakkam, Chennai',
      'offer': '30% Off on All Hair Services', 'distance': '5 Km', 'type': 'Salon',
      'image_url': 'https://images.unsplash.com/photo-1521590832167-7bcbfaa6381f?w=700&q=80',
      'description': 'Naturals is India\'s leading salon chain. Expert stylists, premium products and the latest trends.',
      'address': '22, Khader Nawaz Khan Rd, Nungambakkam, Chennai - 600006',
      'phone': '+91 44 4390 1234', 'timing': 'Daily: 9am – 8pm',
      'rating': 4.4, 'reviews': 421,
    },
    // ── Brand deals ───────────────────────────────────────────────────────────
    {
      'id': 'd6', 'deal_group': 'brand',
      'name': 'T. Nagar Silks', 'location': 'T. Nagar, Chennai',
      'offer': 'Flat 20% Off on Sarees', 'distance': '10 Km', 'type': 'Clothing',
      'image_url': 'https://images.unsplash.com/photo-1583391733956-6c78276477e2?w=700&q=80',
      'description': 'T. Nagar\'s most trusted silk saree brand since 1978. Premium Kancheepuram silks at factory prices.',
      'address': '140, Usman Road, T. Nagar, Chennai - 600017',
      'phone': '+91 44 2434 5678', 'timing': 'Daily: 10am – 9pm',
      'rating': 4.7, 'reviews': 876,
    },
    {
      'id': 'd7', 'deal_group': 'brand',
      'name': 'Adyar Ananda Bhavan', 'location': 'Adyar, Chennai',
      'offer': '10% Off on All Sweet Boxes', 'distance': '7 Km', 'type': 'Restaurant',
      'image_url': 'https://images.unsplash.com/photo-1517244683847-7456b63c5969?w=700&q=80',
      'description': 'A&B — the iconic South Indian sweet and snack chain. Authentic recipes since 1988.',
      'address': '16, 4th Main Road, Adyar, Chennai - 600020',
      'phone': '+91 44 2441 5252', 'timing': 'Daily: 7am – 10pm',
      'rating': 4.5, 'reviews': 1240,
    },
    {
      'id': 'd8', 'deal_group': 'brand',
      'name': 'Anna Nagar Electronics', 'location': 'Anna Nagar, Chennai',
      'offer': 'Up to 15% Off on Appliances', 'distance': '4 Km', 'type': 'Electronics',
      'image_url': 'https://images.unsplash.com/photo-1550009158-9ebf69173e03?w=700&q=80',
      'description': 'Chennai\'s largest multi-brand electronics store. TVs, refrigerators, washing machines — all brands, best prices.',
      'address': 'Plot 5, 5th Avenue, Anna Nagar, Chennai - 600040',
      'phone': '+91 98400 11111', 'timing': 'Mon–Sat: 9am – 9pm',
      'rating': 4.2, 'reviews': 567,
    },
    {
      'id': 'd9', 'deal_group': 'brand',
      'name': 'MedPlus Pharmacy', 'location': 'Porur, Chennai',
      'offer': '10% Off on All Medicines', 'distance': '2 Km', 'type': 'Pharmacy',
      'image_url': 'https://images.unsplash.com/photo-1584308666744-24d5c474f2ae?w=700&q=80',
      'description': 'MedPlus is one of India\'s largest pharmacy chains. Licensed pharmacists and genuine medicines.',
      'address': '7, Arcot Road, Porur, Chennai - 600116',
      'phone': '+91 1800 102 6454', 'timing': 'Daily: 8am – 10pm',
      'rating': 4.3, 'reviews': 389,
    },
  ];
}
