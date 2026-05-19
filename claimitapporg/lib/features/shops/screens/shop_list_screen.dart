import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../models/shop_category.dart';
import '../../../shared/widgets/shop_filter_sheet.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ShopItem data model
// Replace API call with real backend fetch when DB is ready.
// ─────────────────────────────────────────────────────────────────────────────

class ShopItem {
  final int id;
  final String name;
  final String location;

  /// Category IDs this shop belongs to (matches ShopCategory.id values)
  final List<int> categoryIds;

  final int discount; // percentage
  final double rating;
  final int addedDaysAgo;

  /// Unsplash URL — replaced by fallback if offline / fails
  final String imageUrl;
  final Color fallbackColor;
  final IconData fallbackIcon;

  final bool hasRewards;
  final bool hasRedeem;

  final String address;
  final String timing;
  final String phone;

  const ShopItem({
    required this.id,
    required this.name,
    required this.location,
    required this.categoryIds,
    required this.discount,
    required this.rating,
    required this.addedDaysAgo,
    required this.imageUrl,
    required this.fallbackColor,
    required this.fallbackIcon,
    this.hasRewards = true,
    this.hasRedeem = true,
    this.address = '',
    this.timing = '',
    this.phone = '',
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Dummy shop data  (JSON-ready — each entry maps to a backend document)
// Category IDs:
//   1 = New deals  2 = Groceries  3 = Supermarket  4 = Pharmacy  5 = Salon
//   6 = Gym        7 = Restaurant 8 = Cafes        9 = Clothing 10 = Department
//  11 = Electronics 12 = Books   13 = Toys        14 = Baby    15 = Home Decor
//  16 = Furniture  17 = Spa      18 = Schools     19 = Colleges 20 = Tutoring
//  21 = Clinics    22 = Hospitals 23 = Pets       24 = Sports  25 = Travel
//  26 = Mobile & Accessories     27 = Computer & Laptop
//  28 = Gifts      29 = Jewellery 30 = Shoes
// ─────────────────────────────────────────────────────────────────────────────

const _allShops = <ShopItem>[
  // ── Groceries / Supermarket ──────────────────────────────────────────────
  ShopItem(
    id: 1,
    name: 'Indian mart',
    location: 'Padi, Chennai',
    categoryIds: [1, 2, 3],
    discount: 30,
    rating: 4.2,
    addedDaysAgo: 2,
    imageUrl: 'https://images.unsplash.com/photo-1534723452862-4c874018d66d?w=400&q=80',
    fallbackColor: Color(0xFFE8F5E9),
    fallbackIcon: Icons.store_mall_directory_rounded,
    hasRewards: true,
    hasRedeem: true,
    address: '89, Industrial Estate, Padi, Chennai - 600050',
    timing: 'Daily: 8am – 9pm',
    phone: '+91 44 2651 1234',
  ),
  ShopItem(
    id: 2,
    name: 'Annachi supermarket',
    location: 'Padi, Chennai',
    categoryIds: [2, 3],
    discount: 20,
    rating: 3.8,
    addedDaysAgo: 5,
    imageUrl: 'https://images.unsplash.com/photo-1542838132-92c53300491e?w=400&q=80',
    fallbackColor: Color(0xFFFFF3E0),
    fallbackIcon: Icons.shopping_basket_rounded,
    hasRewards: true,
    hasRedeem: true,
    address: '12, 3rd Street, Padi, Chennai - 600050',
    timing: 'Daily: 7am – 10pm',
    phone: '+91 98765 43210',
  ),
  ShopItem(
    id: 3,
    name: 'Rathan super store',
    location: 'Padi, Chennai',
    categoryIds: [2, 3],
    discount: 55,
    rating: 4.5,
    addedDaysAgo: 1,
    imageUrl: 'https://images.unsplash.com/photo-1578916171728-46686eac8d58?w=400&q=80',
    fallbackColor: Color(0xFFE3F2FD),
    fallbackIcon: Icons.store_rounded,
    hasRewards: true,
    hasRedeem: false,
    address: '45, 2nd Avenue, Padi, Chennai - 600050',
    timing: 'Mon–Sat: 8am – 9pm',
    phone: '+91 98400 55555',
  ),
  ShopItem(
    id: 4,
    name: 'Grace supermarket',
    location: 'Padi, Chennai',
    categoryIds: [2, 3],
    discount: 10,
    rating: 3.5,
    addedDaysAgo: 10,
    imageUrl: 'https://images.unsplash.com/photo-1604719312566-8912e9227c6a?w=400&q=80',
    fallbackColor: Color(0xFFE8F5E9),
    fallbackIcon: Icons.store_mall_directory_rounded,
    hasRewards: false,
    hasRedeem: true,
    address: '78, Main Road, Padi, Chennai - 600050',
    timing: 'Daily: 9am – 9pm',
    phone: '+91 44 2651 5678',
  ),
  ShopItem(
    id: 5,
    name: 'Big bazar',
    location: 'Padi, Chennai',
    categoryIds: [2, 3, 9, 10],
    discount: 30,
    rating: 4.0,
    addedDaysAgo: 3,
    imageUrl: 'https://images.unsplash.com/photo-1607082348824-0a96f2a4b9da?w=400&q=80',
    fallbackColor: Color(0xFFE8EAF6),
    fallbackIcon: Icons.apartment_rounded,
    hasRewards: true,
    hasRedeem: true,
    address: '100, High Road, Padi, Chennai - 600050',
    timing: 'Daily: 10am – 10pm',
    phone: '+91 44 2651 9999',
  ),
  ShopItem(
    id: 6,
    name: 'Reliance mart',
    location: 'Padi, Chennai',
    categoryIds: [2, 3, 10],
    discount: 20,
    rating: 4.3,
    addedDaysAgo: 7,
    imageUrl: 'https://images.unsplash.com/photo-1534438327276-14e5300c3a48?w=400&q=80',
    fallbackColor: Color(0xFFE3F2FD),
    fallbackIcon: Icons.store_rounded,
    hasRewards: true,
    hasRedeem: true,
    address: '5, 5th Avenue, Anna Nagar, Chennai - 600040',
    timing: 'Daily: 9am – 9pm',
    phone: '+91 1800 102 0000',
  ),
  ShopItem(
    id: 7,
    name: 'Kandha super store',
    location: 'Padi, Chennai',
    categoryIds: [1, 2],
    discount: 50,
    rating: 4.8,
    addedDaysAgo: 0,
    imageUrl: 'https://images.unsplash.com/photo-1518843875459-f738682238a6?w=400&q=80',
    fallbackColor: Color(0xFFE8F5E9),
    fallbackIcon: Icons.shopping_basket_rounded,
    hasRewards: true,
    hasRedeem: true,
    address: '22, North Street, Padi, Chennai - 600050',
    timing: 'Daily: 7am – 9pm',
    phone: '+91 98765 11111',
  ),
  ShopItem(
    id: 8,
    name: 'Daily Fresh',
    location: 'Anna Nagar, Chennai',
    categoryIds: [1, 2],
    discount: 60,
    rating: 4.9,
    addedDaysAgo: 0,
    imageUrl: 'https://images.unsplash.com/photo-1567306226416-28f0efdc88ce?w=400&q=80',
    fallbackColor: Color(0xFFE8F5E9),
    fallbackIcon: Icons.eco_rounded,
    hasRewards: true,
    hasRedeem: true,
    address: '15, 1st Main Road, Anna Nagar, Chennai - 600040',
    timing: 'Daily: 6am – 11pm',
    phone: '+91 98400 99999',
  ),

  // ── Pharmacy ─────────────────────────────────────────────────────────────
  ShopItem(
    id: 9,
    name: 'Apollo Pharmacy',
    location: 'Anna Nagar, Chennai',
    categoryIds: [4],
    discount: 20,
    rating: 4.5,
    addedDaysAgo: 3,
    imageUrl: 'https://images.unsplash.com/photo-1584308666744-24d5c474f2ae?w=400&q=80',
    fallbackColor: Color(0xFFE8EAF6),
    fallbackIcon: Icons.local_pharmacy_rounded,
    hasRewards: true,
    hasRedeem: true,
    address: '7, 7th Avenue, Anna Nagar, Chennai - 600040',
    timing: 'Daily: 8am – 10pm',
    phone: '+91 1800 599 0189',
  ),
  ShopItem(
    id: 10,
    name: 'MedPlus',
    location: 'Anna Nagar, Chennai',
    categoryIds: [4],
    discount: 10,
    rating: 4.1,
    addedDaysAgo: 6,
    imageUrl: 'https://images.unsplash.com/photo-1585435557343-3b092031a831?w=400&q=80',
    fallbackColor: Color(0xFFF3E5F5),
    fallbackIcon: Icons.medication_rounded,
    hasRewards: true,
    hasRedeem: false,
    address: '14, Arcot Road, Porur, Chennai - 600116',
    timing: 'Daily: 8am – 10pm',
    phone: '+91 1800 102 6454',
  ),
  ShopItem(
    id: 11,
    name: 'Wellness Forever',
    location: 'Padi, Chennai',
    categoryIds: [4],
    discount: 30,
    rating: 3.9,
    addedDaysAgo: 2,
    imageUrl: 'https://images.unsplash.com/photo-1576671081837-49000212a370?w=400&q=80',
    fallbackColor: Color(0xFFE0F7FA),
    fallbackIcon: Icons.local_pharmacy_rounded,
    hasRewards: false,
    hasRedeem: true,
    address: '9, 3rd Cross, Padi, Chennai - 600050',
    timing: 'Mon–Sat: 9am – 8pm',
    phone: '+91 98765 22222',
  ),
  ShopItem(
    id: 12,
    name: 'Netmeds Pharmacy',
    location: 'T Nagar, Chennai',
    categoryIds: [1, 4],
    discount: 50,
    rating: 4.6,
    addedDaysAgo: 1,
    imageUrl: 'https://images.unsplash.com/photo-1471864190281-a93a3070b6de?w=400&q=80',
    fallbackColor: Color(0xFFE8F5E9),
    fallbackIcon: Icons.medication_liquid_rounded,
    hasRewards: true,
    hasRedeem: true,
    address: '55, Usman Road, T Nagar, Chennai - 600017',
    timing: 'Daily: 8am – 9pm',
    phone: '+91 98400 33333',
  ),

  // ── Salon ─────────────────────────────────────────────────────────────────
  ShopItem(
    id: 13,
    name: 'Style Studio',
    location: 'Anna Nagar, Chennai',
    categoryIds: [5],
    discount: 50,
    rating: 4.7,
    addedDaysAgo: 1,
    imageUrl: 'https://images.unsplash.com/photo-1560869713-7d0a29430803?w=400&q=80',
    fallbackColor: Color(0xFFF3E5F5),
    fallbackIcon: Icons.content_cut_rounded,
    hasRewards: true,
    hasRedeem: true,
    address: '11, 2nd Street, Anna Nagar, Chennai - 600040',
    timing: 'Daily: 9am – 8pm',
    phone: '+91 98765 33333',
  ),
  ShopItem(
    id: 14,
    name: 'Green Trends',
    location: 'Padi, Chennai',
    categoryIds: [5],
    discount: 20,
    rating: 4.2,
    addedDaysAgo: 4,
    imageUrl: 'https://images.unsplash.com/photo-1521590832167-7bcbfaa6381f?w=400&q=80',
    fallbackColor: Color(0xFFE8F5E9),
    fallbackIcon: Icons.content_cut_rounded,
    hasRewards: true,
    hasRedeem: true,
    address: '3, 5th Main Road, Padi, Chennai - 600050',
    timing: 'Daily: 9am – 7pm',
    phone: '+91 98765 44444',
  ),
  ShopItem(
    id: 15,
    name: 'Naturals Salon',
    location: 'Anna Nagar, Chennai',
    categoryIds: [5],
    discount: 30,
    rating: 4.4,
    addedDaysAgo: 2,
    imageUrl: 'https://images.unsplash.com/photo-1487412947147-5cebf100ffc2?w=400&q=80',
    fallbackColor: Color(0xFFFCE4EC),
    fallbackIcon: Icons.content_cut_rounded,
    hasRewards: false,
    hasRedeem: true,
    address: '22, KNK Road, Nungambakkam, Chennai - 600006',
    timing: 'Daily: 9am – 8pm',
    phone: '+91 44 4390 1234',
  ),
  ShopItem(
    id: 16,
    name: 'Jawed Habib',
    location: 'Nungambakkam, Chennai',
    categoryIds: [1, 5],
    discount: 50,
    rating: 4.3,
    addedDaysAgo: 0,
    imageUrl: 'https://images.unsplash.com/photo-1597002973885-8c90683fa6e6?w=400&q=80',
    fallbackColor: Color(0xFFF3E5F5),
    fallbackIcon: Icons.spa_rounded,
    hasRewards: true,
    hasRedeem: true,
    address: '40, Khader Nawaz Khan Rd, Nungambakkam, Chennai - 600006',
    timing: 'Daily: 10am – 8pm',
    phone: '+91 98400 77777',
  ),

  // ── Gym ───────────────────────────────────────────────────────────────────
  ShopItem(
    id: 17,
    name: "Gold's Gym",
    location: 'Padi, Chennai',
    categoryIds: [6],
    discount: 50,
    rating: 4.6,
    addedDaysAgo: 1,
    imageUrl: 'https://images.unsplash.com/photo-1534438327276-14e5300c3a48?w=400&q=80',
    fallbackColor: Color(0xFFE3F2FD),
    fallbackIcon: Icons.fitness_center_rounded,
    hasRewards: true,
    hasRedeem: true,
    address: '100 Feet Road, Padi, Chennai - 600050',
    timing: 'Mon–Sat: 5am – 11pm | Sun: 6am – 9pm',
    phone: '+91 98400 55555',
  ),
  ShopItem(
    id: 18,
    name: 'Fitness First',
    location: 'Velachery, Chennai',
    categoryIds: [1, 6],
    discount: 50,
    rating: 4.5,
    addedDaysAgo: 2,
    imageUrl: 'https://images.unsplash.com/photo-1571902943202-507ec2618e8f?w=400&q=80',
    fallbackColor: Color(0xFFE8EAF6),
    fallbackIcon: Icons.fitness_center_rounded,
    hasRewards: true,
    hasRedeem: false,
    address: '100 Feet Road, Velachery, Chennai - 600042',
    timing: 'Mon–Sat: 5am – 11pm | Sun: 6am – 9pm',
    phone: '+91 98400 66666',
  ),
  ShopItem(
    id: 19,
    name: 'Anytime Fitness',
    location: 'Anna Nagar, Chennai',
    categoryIds: [6],
    discount: 30,
    rating: 4.4,
    addedDaysAgo: 5,
    imageUrl: 'https://images.unsplash.com/photo-1517836357463-d25dfeac3438?w=400&q=80',
    fallbackColor: Color(0xFFE0F7FA),
    fallbackIcon: Icons.fitness_center_rounded,
    hasRewards: true,
    hasRedeem: true,
    address: '20, 6th Avenue, Anna Nagar, Chennai - 600040',
    timing: 'Daily: 24 hours',
    phone: '+91 98765 55555',
  ),

  // ── Restaurant ────────────────────────────────────────────────────────────
  ShopItem(
    id: 20,
    name: 'Saravana Bhavan',
    location: 'Anna Nagar, Chennai',
    categoryIds: [7],
    discount: 10,
    rating: 4.6,
    addedDaysAgo: 8,
    imageUrl: 'https://images.unsplash.com/photo-1517244683847-7456b63c5969?w=400&q=80',
    fallbackColor: Color(0xFFFFF3E0),
    fallbackIcon: Icons.restaurant_rounded,
    hasRewards: true,
    hasRedeem: true,
    address: '77, 2nd Avenue, Anna Nagar, Chennai - 600040',
    timing: 'Daily: 7am – 10pm',
    phone: '+91 44 2626 1234',
  ),
  ShopItem(
    id: 21,
    name: 'Murugan Idli Shop',
    location: 'Padi, Chennai',
    categoryIds: [7],
    discount: 20,
    rating: 4.3,
    addedDaysAgo: 5,
    imageUrl: 'https://images.unsplash.com/photo-1565299507177-b0ac66763828?w=400&q=80',
    fallbackColor: Color(0xFFFCE4EC),
    fallbackIcon: Icons.restaurant_rounded,
    hasRewards: true,
    hasRedeem: false,
    address: '25, Industrial Estate, Padi, Chennai - 600050',
    timing: 'Daily: 6am – 10pm',
    phone: '+91 98765 66666',
  ),
  ShopItem(
    id: 22,
    name: 'Adyar Ananda Bhavan',
    location: 'Adyar, Chennai',
    categoryIds: [1, 7],
    discount: 15,
    rating: 4.5,
    addedDaysAgo: 3,
    imageUrl: 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?w=400&q=80',
    fallbackColor: Color(0xFFFFF8E1),
    fallbackIcon: Icons.restaurant_rounded,
    hasRewards: true,
    hasRedeem: true,
    address: '16, 4th Main Road, Adyar, Chennai - 600020',
    timing: 'Daily: 7am – 10pm',
    phone: '+91 44 2441 5252',
  ),

  // ── Cafes ─────────────────────────────────────────────────────────────────
  ShopItem(
    id: 23,
    name: 'Cafe Coffee Day',
    location: 'Anna Nagar, Chennai',
    categoryIds: [8],
    discount: 30,
    rating: 4.2,
    addedDaysAgo: 2,
    imageUrl: 'https://images.unsplash.com/photo-1501339847302-ac426a4a7cbb?w=400&q=80',
    fallbackColor: Color(0xFFEFEBE9),
    fallbackIcon: Icons.local_cafe_rounded,
    hasRewards: true,
    hasRedeem: true,
    address: '5, 5th Avenue, Anna Nagar, Chennai - 600040',
    timing: 'Daily: 8am – 10pm',
    phone: '+91 98400 88888',
  ),
  ShopItem(
    id: 24,
    name: 'Starbucks',
    location: 'Nungambakkam, Chennai',
    categoryIds: [1, 8],
    discount: 20,
    rating: 4.5,
    addedDaysAgo: 5,
    imageUrl: 'https://images.unsplash.com/photo-1461023058943-07fcbe16d735?w=400&q=80',
    fallbackColor: Color(0xFFE8F5E9),
    fallbackIcon: Icons.local_cafe_rounded,
    hasRewards: false,
    hasRedeem: true,
    address: '14, Khader Nawaz Khan Rd, Nungambakkam, Chennai - 600006',
    timing: 'Daily: 7am – 11pm',
    phone: '+91 1800 123 5678',
  ),

  // ── Clothing ──────────────────────────────────────────────────────────────
  ShopItem(
    id: 25,
    name: "Pothy's",
    location: 'T Nagar, Chennai',
    categoryIds: [9],
    discount: 30,
    rating: 4.1,
    addedDaysAgo: 3,
    imageUrl: 'https://images.unsplash.com/photo-1528360983277-13d401cdc186?w=400&q=80',
    fallbackColor: Color(0xFFF9FBE7),
    fallbackIcon: Icons.checkroom_rounded,
    hasRewards: true,
    hasRedeem: true,
    address: '140, Usman Road, T Nagar, Chennai - 600017',
    timing: 'Daily: 10am – 9pm',
    phone: '+91 44 2434 5678',
  ),
  ShopItem(
    id: 26,
    name: 'Kumaran Silks',
    location: 'T Nagar, Chennai',
    categoryIds: [9],
    discount: 20,
    rating: 4.4,
    addedDaysAgo: 6,
    imageUrl: 'https://images.unsplash.com/photo-1583391733956-6c78276477e2?w=400&q=80',
    fallbackColor: Color(0xFFFCE4EC),
    fallbackIcon: Icons.checkroom_rounded,
    hasRewards: false,
    hasRedeem: true,
    address: '12, Nageswara Road, T Nagar, Chennai - 600017',
    timing: 'Daily: 10am – 9pm',
    phone: '+91 44 2434 9999',
  ),
  ShopItem(
    id: 27,
    name: 'Zudio',
    location: 'Anna Nagar, Chennai',
    categoryIds: [1, 9],
    discount: 50,
    rating: 4.0,
    addedDaysAgo: 1,
    imageUrl: 'https://images.unsplash.com/photo-1551232864-3f0890e580d9?w=400&q=80',
    fallbackColor: Color(0xFFF1F8E9),
    fallbackIcon: Icons.checkroom_rounded,
    hasRewards: true,
    hasRedeem: true,
    address: '23, Shanthi Colony, Anna Nagar, Chennai - 600040',
    timing: 'Daily: 10am – 10pm',
    phone: '+91 98400 11122',
  ),

  // ── Electronics ───────────────────────────────────────────────────────────
  ShopItem(
    id: 28,
    name: 'Poorvika Mobiles',
    location: 'Anna Nagar, Chennai',
    categoryIds: [11, 26],
    discount: 10,
    rating: 4.0,
    addedDaysAgo: 4,
    imageUrl: 'https://images.unsplash.com/photo-1550009158-9ebf69173e03?w=400&q=80',
    fallbackColor: Color(0xFFE8EAF6),
    fallbackIcon: Icons.smartphone_rounded,
    hasRewards: true,
    hasRedeem: true,
    address: '5, 5th Avenue, Anna Nagar, Chennai - 600040',
    timing: 'Mon–Sat: 9am – 9pm',
    phone: '+91 98400 11111',
  ),
  ShopItem(
    id: 29,
    name: 'Sangeetha Mobiles',
    location: 'Padi, Chennai',
    categoryIds: [11, 26],
    discount: 20,
    rating: 3.8,
    addedDaysAgo: 7,
    imageUrl: 'https://images.unsplash.com/photo-1565849904461-04a58ad377e0?w=400&q=80',
    fallbackColor: Color(0xFFE3F2FD),
    fallbackIcon: Icons.devices_rounded,
    hasRewards: true,
    hasRedeem: false,
    address: '88, Industrial Estate, Padi, Chennai - 600050',
    timing: 'Mon–Sat: 9am – 8pm',
    phone: '+91 98765 77777',
  ),
  ShopItem(
    id: 30,
    name: 'Croma',
    location: 'Anna Nagar, Chennai',
    categoryIds: [1, 11, 26, 27],
    discount: 15,
    rating: 4.3,
    addedDaysAgo: 2,
    imageUrl: 'https://images.unsplash.com/photo-1481487196290-c152efe083f5?w=400&q=80',
    fallbackColor: Color(0xFFE8EAF6),
    fallbackIcon: Icons.devices_rounded,
    hasRewards: true,
    hasRedeem: true,
    address: 'Plot 5, 12th Main Road, Anna Nagar, Chennai - 600040',
    timing: 'Daily: 10am – 9pm',
    phone: '+91 1800 267 6744',
  ),

  // ── Books ─────────────────────────────────────────────────────────────────
  ShopItem(
    id: 31,
    name: 'Landmark Books',
    location: 'Anna Nagar, Chennai',
    categoryIds: [12],
    discount: 10,
    rating: 4.3,
    addedDaysAgo: 3,
    imageUrl: 'https://images.unsplash.com/photo-1524578271613-d9c925a6b1ed?w=400&q=80',
    fallbackColor: Color(0xFFE8F5E9),
    fallbackIcon: Icons.menu_book_rounded,
    hasRewards: true,
    hasRedeem: true,
    address: '7, 7th Main Road, Anna Nagar, Chennai - 600040',
    timing: 'Daily: 10am – 9pm',
    phone: '+91 98765 88888',
  ),

  // ── Jewellery ─────────────────────────────────────────────────────────────
  ShopItem(
    id: 32,
    name: 'GRT Jewellers',
    location: 'T Nagar, Chennai',
    categoryIds: [29],
    discount: 20,
    rating: 4.5,
    addedDaysAgo: 6,
    imageUrl: 'https://images.unsplash.com/photo-1515562141207-7a88fb7ce338?w=400&q=80',
    fallbackColor: Color(0xFFFCE4EC),
    fallbackIcon: Icons.diamond_rounded,
    hasRewards: true,
    hasRedeem: true,
    address: '145, Usman Road, T Nagar, Chennai - 600017',
    timing: 'Daily: 10am – 9pm',
    phone: '+91 44 2814 5678',
  ),

  // ── Sports ────────────────────────────────────────────────────────────────
  ShopItem(
    id: 33,
    name: 'Decathlon',
    location: 'Velachery, Chennai',
    categoryIds: [24],
    discount: 15,
    rating: 4.4,
    addedDaysAgo: 2,
    imageUrl: 'https://images.unsplash.com/photo-1517649763962-0c623066013b?w=400&q=80',
    fallbackColor: Color(0xFFE8F5E9),
    fallbackIcon: Icons.sports_soccer_rounded,
    hasRewards: true,
    hasRedeem: false,
    address: 'Velachery Main Road, Velachery, Chennai - 600042',
    timing: 'Daily: 10am – 9pm',
    phone: '+91 98400 22233',
  ),

  // ── Travel ────────────────────────────────────────────────────────────────
  ShopItem(
    id: 34,
    name: 'Thomas Cook',
    location: 'Anna Nagar, Chennai',
    categoryIds: [25],
    discount: 25,
    rating: 4.2,
    addedDaysAgo: 3,
    imageUrl: 'https://images.unsplash.com/photo-1436491865332-7a61a109cc05?w=400&q=80',
    fallbackColor: Color(0xFFE3F2FD),
    fallbackIcon: Icons.luggage_rounded,
    hasRewards: false,
    hasRedeem: true,
    address: '8, 8th Avenue, Anna Nagar, Chennai - 600040',
    timing: 'Mon–Sat: 9am – 7pm',
    phone: '+91 98765 99999',
  ),

  // ── Spa ───────────────────────────────────────────────────────────────────
  ShopItem(
    id: 35,
    name: 'O2 Spa',
    location: 'Nungambakkam, Chennai',
    categoryIds: [17],
    discount: 30,
    rating: 4.6,
    addedDaysAgo: 1,
    imageUrl: 'https://images.unsplash.com/photo-1540555700478-4be289fbecef?w=400&q=80',
    fallbackColor: Color(0xFFF1F8E9),
    fallbackIcon: Icons.spa_rounded,
    hasRewards: true,
    hasRedeem: true,
    address: '6, Khader Nawaz Khan Rd, Nungambakkam, Chennai - 600006',
    timing: 'Daily: 10am – 9pm',
    phone: '+91 98400 44444',
  ),

  // ── Pets ─────────────────────────────────────────────────────────────────
  ShopItem(
    id: 36,
    name: 'Pet Junction',
    location: 'Anna Nagar, Chennai',
    categoryIds: [23],
    discount: 20,
    rating: 4.3,
    addedDaysAgo: 4,
    imageUrl: 'https://images.unsplash.com/photo-1601758174493-645502eb2700?w=400&q=80',
    fallbackColor: Color(0xFFE8F5E9),
    fallbackIcon: Icons.pets_rounded,
    hasRewards: true,
    hasRedeem: true,
    address: '33, 3rd Avenue, Anna Nagar, Chennai - 600040',
    timing: 'Daily: 10am – 8pm',
    phone: '+91 98765 00000',
  ),

  // ── Clinics ───────────────────────────────────────────────────────────────
  ShopItem(
    id: 37,
    name: 'Smile Dentist',
    location: 'Padi, Chennai',
    categoryIds: [21],
    discount: 25,
    rating: 4.5,
    addedDaysAgo: 3,
    imageUrl: 'https://images.unsplash.com/photo-1588776814546-ec7eb8e02bb5?w=400&q=80',
    fallbackColor: Color(0xFFE3F2FD),
    fallbackIcon: Icons.local_hospital_rounded,
    hasRewards: true,
    hasRedeem: true,
    address: '12, 3rd Street, Padi, Chennai - 600050',
    timing: 'Mon–Sat: 9am – 8pm',
    phone: '+91 98765 43210',
  ),

  // ── Home Decor / Furniture ────────────────────────────────────────────────
  ShopItem(
    id: 38,
    name: 'Home Centre',
    location: 'Anna Nagar, Chennai',
    categoryIds: [15, 16],
    discount: 20,
    rating: 4.1,
    addedDaysAgo: 5,
    imageUrl: 'https://images.unsplash.com/photo-1555041469-a586c61ea9bc?w=400&q=80',
    fallbackColor: Color(0xFFFFF8E1),
    fallbackIcon: Icons.weekend_rounded,
    hasRewards: true,
    hasRedeem: true,
    address: '100, 4th Avenue, Anna Nagar, Chennai - 600040',
    timing: 'Daily: 10am – 9pm',
    phone: '+91 98765 11000',
  ),

  // ── Gifts ─────────────────────────────────────────────────────────────────
  ShopItem(
    id: 39,
    name: 'Archies Gallery',
    location: 'Anna Nagar, Chennai',
    categoryIds: [28],
    discount: 30,
    rating: 4.0,
    addedDaysAgo: 7,
    imageUrl: 'https://images.unsplash.com/photo-1549465220-1a8b9238cd48?w=400&q=80',
    fallbackColor: Color(0xFFFCE4EC),
    fallbackIcon: Icons.card_giftcard_rounded,
    hasRewards: false,
    hasRedeem: true,
    address: '18, 1st Avenue, Anna Nagar, Chennai - 600040',
    timing: 'Daily: 10am – 9pm',
    phone: '+91 98765 22000',
  ),

  // ── Shoes ─────────────────────────────────────────────────────────────────
  ShopItem(
    id: 40,
    name: 'Bata',
    location: 'T Nagar, Chennai',
    categoryIds: [30],
    discount: 20,
    rating: 4.0,
    addedDaysAgo: 5,
    imageUrl: 'https://images.unsplash.com/photo-1542291026-7eec264c27ff?w=400&q=80',
    fallbackColor: Color(0xFFE3F2FD),
    fallbackIcon: Icons.directions_run_rounded,
    hasRewards: true,
    hasRedeem: true,
    address: '90, Usman Road, T Nagar, Chennai - 600017',
    timing: 'Daily: 10am – 9pm',
    phone: '+91 98765 33000',
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// All categories — mirrors dashboard_screen._allCategories so the filter
// sheet shows the same icons the home screen shows (all 30, swipeable).
// ─────────────────────────────────────────────────────────────────────────────

// FilterCat, filterCats — imported from shared/widgets/shop_filter_sheet.dart

// ─────────────────────────────────────────────────────────────────────────────
// Public accessor — used by SearchScreen and backend service layer
// ─────────────────────────────────────────────────────────────────────────────

List<ShopItem> getShopDatabase() => List.unmodifiable(_allShops);

// ─────────────────────────────────────────────────────────────────────────────
// ShopListScreen
// ─────────────────────────────────────────────────────────────────────────────

class ShopListScreen extends StatefulWidget {
  final ShopCategory category;
  const ShopListScreen({super.key, required this.category});

  @override
  State<ShopListScreen> createState() => _ShopListScreenState();
}

class _ShopListScreenState extends State<ShopListScreen> {
  bool _isRewards = true;

  bool _showSearch = false;
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  // Applied filters
  String? _sort;         // 'recently_added' | '30_disc' | '50_above' | '20_disc' | '10_disc' | 'last_7_days'
  int? _filterCatId;
  double? _minRating;
  String? _priceSort;    // 'high_to_low' | 'low_to_high'

  final Set<int> _favorites = {};

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<ShopItem> get _filteredShops {
    // If the filter sheet has a category selected, it REPLACES the screen's
    // base category so the user can switch from e.g. Groceries → Salon.
    final baseCatId = _filterCatId ?? widget.category.id;

    var shops = _allShops
        .where((s) => s.categoryIds.contains(baseCatId))
        .toList();

    // Rewards / Redeem tab
    if (_isRewards) {
      shops = shops.where((s) => s.hasRewards).toList();
    } else {
      shops = shops.where((s) => s.hasRedeem).toList();
    }

    // Search
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      shops = shops
          .where((s) =>
              s.name.toLowerCase().contains(q) ||
              s.location.toLowerCase().contains(q))
          .toList();
    }

    // Sort / discount chips
    if (_sort == 'recently_added') {
      shops = [...shops]..sort((a, b) => a.addedDaysAgo.compareTo(b.addedDaysAgo));
    } else if (_sort == '30_disc') {
      shops = shops.where((s) => s.discount == 30).toList();
    } else if (_sort == '50_above') {
      shops = shops.where((s) => s.discount >= 50).toList();
    } else if (_sort == '20_disc') {
      shops = shops.where((s) => s.discount == 20).toList();
    } else if (_sort == '10_disc') {
      shops = shops.where((s) => s.discount == 10).toList();
    } else if (_sort == 'last_7_days') {
      shops = shops.where((s) => s.addedDaysAgo <= 7).toList();
    }

    // Minimum rating
    if (_minRating != null) {
      shops = shops.where((s) => s.rating >= _minRating!).toList();
    }

    // Price / discount sort
    if (_priceSort == 'high_to_low') {
      shops = [...shops]..sort((a, b) => b.discount.compareTo(a.discount));
    } else if (_priceSort == 'low_to_high') {
      shops = [...shops]..sort((a, b) => a.discount.compareTo(b.discount));
    }

    return shops;
  }

  /// Label shown in the AppBar — switches to the filter category's name
  /// when the user has selected a different category in the filter sheet.
  String get _activeTitle {
    if (_filterCatId != null) {
      try {
        return filterCats
            .firstWhere((c) => c.id == _filterCatId)
            .label
            .replaceAll('\n', ' ');
      } catch (_) {}
    }
    return widget.category.name;
  }

  int get _filterCount {
    int c = 0;
    if (_sort != null) c++;
    if (_filterCatId != null) c++;
    if (_minRating != null) c++;
    if (_priceSort != null) c++;
    return c;
  }

  void _openFilter() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ShopFilterSheet(
        initialSort: _sort,
        initialCatId: _filterCatId,
        initialRating: _minRating,
        initialPrice: _priceSort,
        onApply: (sort, catId, rating, price) {
          setState(() {
            _sort = sort;
            _filterCatId = catId;
            _minRating = rating;
            _priceSort = price;
          });
        },
      ),
    );
  }

  // ── AppBar ────────────────────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(56),
      child: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        shadowColor: Colors.black12,
        surfaceTintColor: Colors.transparent,
        leading: GestureDetector(
          onTap: () => context.pop(),
          child: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Color(0xFF2563EB), size: 20),
        ),
        title: _showSearch
            ? TextField(
                controller: _searchCtrl,
                autofocus: true,
                onChanged: (v) => setState(() => _searchQuery = v),
                decoration: InputDecoration(
                  hintText: 'Search $_activeTitle…',
                  hintStyle:
                      const TextStyle(fontSize: 14, color: Color(0xFF9CA3AF)),
                  border: InputBorder.none,
                  isDense: true,
                ),
                style: const TextStyle(fontSize: 16),
              )
            : Text(
                _activeTitle,
                style: const TextStyle(
                  color: Color(0xFF2563EB),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
        actions: [
          // Filter button
          GestureDetector(
            onTap: _openFilter,
            child: Container(
              margin: const EdgeInsets.only(right: 6),
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFE5E7EB)),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.tune_rounded,
                      size: 14, color: Color(0xFF374151)),
                  const SizedBox(width: 4),
                  const Text('Filter',
                      style: TextStyle(
                          fontSize: 13, color: Color(0xFF374151))),
                  if (_filterCount > 0) ...[
                    const SizedBox(width: 4),
                    Container(
                      width: 16,
                      height: 16,
                      decoration: const BoxDecoration(
                        color: Color(0xFF2563EB),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '$_filterCount',
                        style: const TextStyle(
                          fontSize: 9,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          // Search toggle
          IconButton(
            icon: Icon(
              _showSearch ? Icons.close_rounded : Icons.search_rounded,
              color: const Color(0xFF1E3A8A),
              size: 24,
            ),
            onPressed: () {
              setState(() {
                _showSearch = !_showSearch;
                if (!_showSearch) {
                  _searchCtrl.clear();
                  _searchQuery = '';
                }
              });
            },
          ),
        ],
      ),
    );
  }

  // ── Rewards / Redeem tab ──────────────────────────────────────────────────
  Widget _buildTabToggle() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Container(
        height: 44,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          children: [
            _TabBtn(
                label: 'Rewards',
                active: _isRewards,
                onTap: () => setState(() => _isRewards = true)),
            _TabBtn(
                label: 'Redeem',
                active: !_isRewards,
                onTap: () => setState(() => _isRewards = false)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shops = _filteredShops;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildTabToggle(),
          const Divider(height: 1, color: Color(0xFFF3F4F6)),
          Expanded(
            child: shops.isEmpty
                ? _buildEmpty()
                : ListView.builder(
                    itemCount: shops.length,
                    padding: const EdgeInsets.only(top: 4, bottom: 16),
                    itemBuilder: (_, i) => _ShopCard(
                      shop: shops[i],
                      isFav: _favorites.contains(shops[i].id),
                      onToggleFav: () {
                        setState(() {
                          if (_favorites.contains(shops[i].id)) {
                            _favorites.remove(shops[i].id);
                          } else {
                            _favorites.add(shops[i].id);
                          }
                        });
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.store_outlined, size: 72, color: Colors.grey.shade200),
          const SizedBox(height: 16),
          Text(
            'No shops found',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade500),
          ),
          const SizedBox(height: 6),
          Text(
            'Try adjusting your filters',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab button
// ─────────────────────────────────────────────────────────────────────────────

class _TabBtn extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _TabBtn(
      {required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: double.infinity,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? const Color(0xFF2563EB) : Colors.transparent,
            borderRadius: BorderRadius.circular(26),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: active ? Colors.white : const Color(0xFF6B7280),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shop card
// ─────────────────────────────────────────────────────────────────────────────

class _ShopCard extends StatelessWidget {
  final ShopItem shop;
  final bool isFav;
  final VoidCallback onToggleFav;
  const _ShopCard(
      {required this.shop,
      required this.isFav,
      required this.onToggleFav});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/shop-detail', extra: shop),
      child: _buildCard(context),
    );
  }

  Widget _buildCard(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Circular shop image
          ClipOval(
            child: SizedBox(
              width: 64,
              height: 64,
              child: CachedNetworkImage(
                imageUrl: shop.imageUrl,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  color: shop.fallbackColor,
                  alignment: Alignment.center,
                  child: Icon(shop.fallbackIcon,
                      size: 28, color: Colors.grey.shade400),
                ),
                errorWidget: (_, __, ___) => Container(
                  color: shop.fallbackColor,
                  alignment: Alignment.center,
                  child: Icon(shop.fallbackIcon,
                      size: 28, color: Colors.grey.shade400),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  shop.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF111827),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Icon(Icons.location_on_rounded,
                        size: 12, color: Color(0xFF9CA3AF)),
                    const SizedBox(width: 2),
                    Text(
                      shop.location,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF6B7280)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    // Discount badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${shop.discount}% OFF',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF2563EB),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Rating
                    const Icon(Icons.star_rounded,
                        size: 14, color: Color(0xFFF59E0B)),
                    const SizedBox(width: 2),
                    Text(
                      shop.rating.toStringAsFixed(1),
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF374151)),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Favorite heart
          GestureDetector(
            onTap: onToggleFav,
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE5E7EB)),
                color: Colors.white,
              ),
              alignment: Alignment.center,
              child: Icon(
                isFav
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                size: 17,
                color: isFav
                    ? Colors.redAccent
                    : const Color(0xFF9CA3AF),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

