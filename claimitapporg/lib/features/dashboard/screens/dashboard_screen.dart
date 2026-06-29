import 'dart:convert';
// import 'dart:async';
// import 'package:flutter/material.dart';
// import 'package:cached_network_image/cached_network_image.dart';
// import 'package:go_router/go_router.dart';
// import 'package:smooth_page_indicator/smooth_page_indicator.dart';

// // ─────────────────────────────────────────────────────────────────────────────
// // Mock data  (replace with live API calls once backend is wired up)
// // ─────────────────────────────────────────────────────────────────────────────

// final _banners = [
//   _BannerData(
//     imageUrl:
//         'https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?w=700&q=80',
//     gradient: const LinearGradient(
//         colors: [Color(0xFFE65100), Color(0xFFFF8F00)]),
//     headline: 'FOOD MAKES LIFE GOOD!',
//     sub: 'Exclusive deals near you',
//   ),
//   _BannerData(
//     imageUrl:
//         'https://images.unsplash.com/photo-1607082348824-0a96f2a4b9da?w=700&q=80',
//     gradient: const LinearGradient(
//         colors: [Color(0xFF1565C0), Color(0xFF2563EB)]),
//     headline: 'BEST DEALS NEAR YOU!',
//     sub: 'Up to 50% off today',
//   ),
//   _BannerData(
//     imageUrl:
//         'https://images.unsplash.com/photo-1542838132-92c53300491e?w=700&q=80',
//     gradient: const LinearGradient(
//         colors: [Color(0xFF2E7D32), Color(0xFF43A047)]),
//     headline: 'SAVE MORE TODAY!',
//     sub: 'Fresh grocery deals',
//   ),
//   _BannerData(
//     imageUrl:
//         'https://images.unsplash.com/photo-1483985988355-763728e1935b?w=700&q=80',
//     gradient: const LinearGradient(
//         colors: [Color(0xFF6A1B9A), Color(0xFFAB47BC)]),
//     headline: 'EXCLUSIVE OFFERS!',
//     sub: 'Shop and save big',
//   ),
// ];

// final _categories = [
//   _CatData(
//     label: 'New deals',
//     icon: Icons.local_offer_rounded,
//     color: Color(0xFFEF4444),
//     isNew: true,
//   ),
//   _CatData(
//     label: 'Groceries',
//     icon: Icons.shopping_basket_rounded,
//     color: Color(0xFF10B981),
//   ),
//   _CatData(
//     label: 'Supermarket',
//     icon: Icons.store_rounded,
//     color: Color(0xFF3B82F6),
//   ),
//   _CatData(
//     label: 'Salon',
//     icon: Icons.content_cut_rounded,
//     color: Color(0xFFF59E0B),
//   ),
//   _CatData(
//     label: 'Gym',
//     icon: Icons.fitness_center_rounded,
//     color: Color(0xFF8B5CF6),
//   ),
//   _CatData(
//     label: 'Restaurant',
//     icon: Icons.restaurant_rounded,
//     color: Color(0xFFEC4899),
//   ),
//   _CatData(
//     label: 'Pharmacy',
//     icon: Icons.local_pharmacy_rounded,
//     color: Color(0xFF06B6D4),
//   ),
// ];

// final _nearbyDeals = [
//   DealData(
//     name: 'Smile Dentist',
//     location: 'Padi, Chennai',
//     offer: '25 % Offer on All grocery',
//     distance: '6Km',
//     type: 'Superstore',
//     imageUrl:
//         'https://images.unsplash.com/photo-1588776814546-ec7eb8e02bb5?w=300&q=80',
//     fallbackColor: const Color(0xFFE3F2FD),
//     fallbackIcon: Icons.local_hospital_rounded,
//   ),
//   DealData(
//     name: 'Ck Bakers',
//     location: 'Anna nagar, Chennai',
//     offer: '25 % Offer on All grocery',
//     distance: '6Km',
//     type: 'Bakery',
//     imageUrl:
//         'https://images.unsplash.com/photo-1568254183919-78a4f43a2877?w=300&q=80',
//     fallbackColor: const Color(0xFFFFF3E0),
//     fallbackIcon: Icons.bakery_dining_rounded,
//   ),
//   DealData(
//     name: 'India mart',
//     location: 'Padi, Chennai',
//     offer: '25 % Offer on All grocery',
//     distance: '6Km',
//     type: 'Mart',
//     imageUrl:
//         'https://images.unsplash.com/photo-1534723452862-4c874018d66d?w=300&q=80',
//     fallbackColor: const Color(0xFFE8F5E9),
//     fallbackIcon: Icons.store_mall_directory_rounded,
//   ),
//   DealData(
//     name: 'Green Grocers',
//     location: 'Velachery, Chennai',
//     offer: '15 % Off on Fresh Produce',
//     distance: '4Km',
//     type: 'Grocery',
//     imageUrl:
//         'https://images.unsplash.com/photo-1518843875459-f738682238a6?w=300&q=80',
//     fallbackColor: const Color(0xFFE8F5E9),
//     fallbackIcon: Icons.eco_rounded,
//   ),
//   DealData(
//     name: 'Healthy Bites',
//     location: 'Nungambakkam, Chennai',
//     offer: '20 % Off on All Meals',
//     distance: '7Km',
//     type: 'Restaurant',
//     imageUrl:
//         'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?w=300&q=80',
//     fallbackColor: const Color(0xFFFCE4EC),
//     fallbackIcon: Icons.restaurant_rounded,
//   ),
// ];

// final _brandDeals = [
//   DealData(
//     name: 'Fresh Mart',
//     location: 'T. Nagar, Chennai',
//     offer: '30 % Offer on Fresh Vegetables',
//     distance: '3Km',
//     type: 'Supermarket',
//     imageUrl:
//         'https://images.unsplash.com/photo-1542838132-92c53300491e?w=300&q=80',
//     fallbackColor: const Color(0xFFE8F5E9),
//     fallbackIcon: Icons.store_rounded,
//   ),
//   DealData(
//     name: 'Style Studio',
//     location: 'Adyar, Chennai',
//     offer: '20 % Off on All Services',
//     distance: '8Km',
//     type: 'Salon',
//     imageUrl:
//         'https://images.unsplash.com/photo-1560869713-7d0a29430803?w=300&q=80',
//     fallbackColor: const Color(0xFFF3E5F5),
//     fallbackIcon: Icons.content_cut_rounded,
//   ),
//   DealData(
//     name: 'FitZone Gym',
//     location: 'Anna nagar, Chennai',
//     offer: '40 % Off on 3-Month Plan',
//     distance: '5Km',
//     type: 'Gym',
//     imageUrl:
//         'https://images.unsplash.com/photo-1534438327276-14e5300c3a48?w=300&q=80',
//     fallbackColor: const Color(0xFFE3F2FD),
//     fallbackIcon: Icons.fitness_center_rounded,
//   ),
//   DealData(
//     name: 'MedPlus Pharmacy',
//     location: 'Porur, Chennai',
//     offer: '10 % Off on All Medicines',
//     distance: '2Km',
//     type: 'Pharmacy',
//     imageUrl:
//         'https://images.unsplash.com/photo-1584308666744-24d5c474f2ae?w=300&q=80',
//     fallbackColor: const Color(0xFFE8EAF6),
//     fallbackIcon: Icons.local_pharmacy_rounded,
//   ),
// ];

// // ─────────────────────────────────────────────────────────────────────────────
// // Data model classes
// // ─────────────────────────────────────────────────────────────────────────────

// class _BannerData {
//   final String imageUrl;
//   final LinearGradient gradient;
//   final String headline;
//   final String sub;
//   const _BannerData({
//     required this.imageUrl,
//     required this.gradient,
//     required this.headline,
//     required this.sub,
//   });
// }

// class _CatData {
//   final String label;
//   final IconData icon;
//   final bool isNew;
//   final Color color;
//   const _CatData({
//     required this.label,
//     required this.icon,
//     required this.color,
//     this.isNew = false,
//   });
// }

// class DealData {
//   final String name;
//   final String location;
//   final String offer;
//   final String distance;
//   final String type;
//   final String imageUrl;
//   final Color fallbackColor;
//   final IconData fallbackIcon;
//   const DealData({
//     required this.name,
//     required this.location,
//     required this.offer,
//     required this.distance,
//     required this.type,
//     required this.imageUrl,
//     required this.fallbackColor,
//     required this.fallbackIcon,
//   });
// }

// // ─────────────────────────────────────────────────────────────────────────────
// // Screen
// // ─────────────────────────────────────────────────────────────────────────────

// class DashboardScreen extends StatefulWidget {
//   const DashboardScreen({super.key});

//   @override
//   State<DashboardScreen> createState() => _DashboardScreenState();
// }

// class _DashboardScreenState extends State<DashboardScreen>
//     with WidgetsBindingObserver {
//   final PageController _bannerCtrl = PageController();
//   Timer? _bannerTimer;
//   int _currentBanner = 0;
//   bool _isNearby = true;
//   int _selectedCategory = 0;

//   @override
//   void initState() {
//     super.initState();
//     // Auto-scroll banner every 4 seconds
//     _bannerTimer = Timer.periodic(const Duration(seconds: 4), (_) {
//       if (!_bannerCtrl.hasClients) return;
//       final next = (_currentBanner + 1) % _activeBanners.length;
//       _bannerCtrl.animateToPage(
//         next,
//         duration: const Duration(milliseconds: 500),
//         curve: Curves.easeInOut,
//       );
//     });
//   }

//   @override
//   void dispose() {
//     _bannerTimer?.cancel();
//     _bannerCtrl.dispose();
//     super.dispose();
//   }

//   // ── Custom white AppBar ──────────────────────────────────────────────────
//   PreferredSizeWidget _buildAppBar() {
//   return PreferredSize(
//     preferredSize: const Size.fromHeight(76),
//     child: Container(
//       color: Colors.white,
//       child: SafeArea(
//         bottom: false,
//         child: Padding(
//           padding: const EdgeInsets.symmetric(
//             horizontal: 12,
//             vertical: 8,
//           ),
//           child: Row(
//             children: [
//               // ── Logo ─────────────────────────────
//               Row(
//                 children: [
//                   Container(
//                     width: 36,
//                     height: 36,
//                     decoration: const BoxDecoration(
//                       color: Color(0xFFF4B400),
//                       shape: BoxShape.circle,
//                     ),
//                     child: const Center(
//                       child: Text(
//                         'C',
//                         style: TextStyle(
//                           color: Colors.white,
//                           fontSize: 20,
//                           fontWeight: FontWeight.bold,
//                         ),
//                       ),
//                     ),
//                   ),

//                   const SizedBox(width: 6),

//                   const Text(
//                     'claimit',
//                     style: TextStyle(
//                       fontSize: 22,
//                       fontWeight: FontWeight.w700,
//                       color: Color(0xFF1565C0),
//                     ),
//                   ),
//                 ],
//               ),

//               const Spacer(),

//               // ── Location ────────────────────────
//               Row(
//                 children: const [
//                   Text(
//                     'Anna Nagar',
//                     style: TextStyle(
//                       fontSize: 15,
//                       fontWeight: FontWeight.w600,
//                       color: Colors.black,
//                     ),
//                   ),
//                   SizedBox(width: 2),
//                   Icon(
//                     Icons.keyboard_arrow_down_rounded,
//                     size: 20,
//                   ),
//                 ],
//               ),

//               const Spacer(),

//               // ── Search ──────────────────────────
//               Container(
//                 width: 38,
//                 height: 38,
//                 decoration: BoxDecoration(
//                   shape: BoxShape.circle,
//                   border: Border.all(
//                     color: const Color(0xFFE5E7EB),
//                   ),
//                 ),
//                 child: IconButton(
//                   icon: const Icon(
//                     Icons.search,
//                     size: 20,
//                     color: Color(0xFF1565C0),
//                   ),
//                   onPressed: () {},
//                   padding: EdgeInsets.zero,
//                 ),
//               ),

//               const SizedBox(width: 8),

//               // ── Notification ───────────────────
//               const Icon(
//                 Icons.notifications_none_rounded,
//                 size: 26,
//                 color: Color(0xFF1565C0),
//               ),
//             ],
//           ),
//         ),
//       ),
//     ),
//   );
// }
//   // PreferredSizeWidget _buildAppBar() {
//   //   return PreferredSize(
//   //     preferredSize: const Size.fromHeight(60),
//   //     child: Container(
//   //       color: Colors.white,
//   //       child: SafeArea(
//   //         bottom: false,
//   //         child: SizedBox(
//   //           height: 60,
//   //           child: Padding(
//   //             padding: const EdgeInsets.symmetric(horizontal: 8),
//   //             child: Row(
//   //               children: [
//   //                 // ── Location selector ──────────────────────────────────
//   //                 Expanded(
//   //                   child: GestureDetector(
//   //                     onTap: () {},
//   //                     child: Row(
//   //                       mainAxisSize: MainAxisSize.min,
//   //                       children: [
//   //                         const Icon(Icons.location_on_rounded,
//   //                             color: Color(0xFF2563EB), size: 18),
//   //                         const SizedBox(width: 3),
//   //                         const Flexible(
//   //                           child: Text(
//   //                             'Padi, Chennai',
//   //                             overflow: TextOverflow.ellipsis,
//   //                             style: TextStyle(
//   //                               fontSize: 14,
//   //                               fontWeight: FontWeight.w600,
//   //                               color: Color(0xFF111827),
//   //                             ),
//   //                           ),
//   //                         ),
//   //                         const Icon(Icons.keyboard_arrow_down_rounded,
//   //                             color: Color(0xFF6B7280), size: 18),
//   //                       ],
//   //                     ),
//   //                   ),
//   //                 ),

//   //                 // ── Claimit logo (yellow circle) ───────────────────────
//   //                 Container(
//   //                   width: 40,
//   //                   height: 40,
//   //                   decoration: const BoxDecoration(
//   //                     color: Color(0xFFEAB308),
//   //                     shape: BoxShape.circle,
//   //                   ),
//   //                   child: const Center(
//   //                     child: Text(
//   //                       'C',
//   //                       style: TextStyle(
//   //                         color: Colors.white,
//   //                         fontSize: 22,
//   //                         fontWeight: FontWeight.bold,
//   //                         height: 1,
//   //                       ),
//   //                     ),
//   //                   ),
//   //                 ),

//   //                 // ── Search + Notification ──────────────────────────────
//   //                 Expanded(
//   //                   child: Row(
//   //                     mainAxisAlignment: MainAxisAlignment.end,
//   //                     children: [
//   //                       IconButton(
//   //                         icon: const Icon(Icons.search_rounded,
//   //                             color: Color(0xFF111827)),
//   //                         iconSize: 22,
//   //                         onPressed: () {},
//   //                         padding: const EdgeInsets.all(8),
//   //                         constraints: const BoxConstraints(),
//   //                       ),
//   //                       Stack(
//   //                         children: [
//   //                           IconButton(
//   //                             icon: const Icon(Icons.notifications_none_rounded,
//   //                                 color: Color(0xFF111827)),
//   //                             iconSize: 22,
//   //                             onPressed: () {},
//   //                             padding: const EdgeInsets.all(8),
//   //                             constraints: const BoxConstraints(),
//   //                           ),
//   //                           Positioned(
//   //                             top: 6,
//   //                             right: 6,
//   //                             child: Container(
//   //                               width: 8,
//   //                               height: 8,
//   //                               decoration: const BoxDecoration(
//   //                                 color: Colors.redAccent,
//   //                                 shape: BoxShape.circle,
//   //                               ),
//   //                             ),
//   //                           ),
//   //                         ],
//   //                       ),
//   //                     ],
//   //                   ),
//   //                 ),
//   //               ],
//   //             ),
//   //           ),
//   //         ),
//   //       ),
//   //     ),
//   //   );
//   // }

//   @override
//   Widget build(BuildContext context) {
//     final deals = _isNearby ? _nearbyDeals : _brandDeals;

//     return Scaffold(
//       backgroundColor: const Color(0xFFF5F5F5),
//       appBar: _buildAppBar(),
//       body: SingleChildScrollView(
//         physics: const BouncingScrollPhysics(),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             // ── Banner carousel ──────────────────────────────────────────
//             // SizedBox(
//             //   height: 195,
//             //   child: PageView.builder(
//             //     controller: _bannerCtrl,
//             //     onPageChanged: (i) => setState(() => _currentBanner = i),
//             //     itemCount: _banners.length,
//             //     itemBuilder: (ctx, i) => GestureDetector(
//             //       onTap: () => context.push('/national-ads'),
//             //       child: _BannerSlide(data: _banners[i]),
//             //     ),
//             //   ),
//             // ),
//             AspectRatio(
//   aspectRatio: 16 / 9,
//   child: PageView.builder(
//     controller: _bannerCtrl,
//     onPageChanged: (i) => setState(() => _currentBanner = i),
//     itemCount: _banners.length,
//     itemBuilder: (ctx, i) => Padding(
//       padding: const EdgeInsets.symmetric(horizontal: 12),
//       child: ClipRRect(
//         borderRadius: BorderRadius.circular(20),
//         child: GestureDetector(
//           onTap: () => context.push('/national-ads'),
//           child: _BannerSlide(data: _banners[i]),
//         ),
//       ),
//     ),
//   ),
// ),

//             const SizedBox(height: 12),

//             // ── Dots ────────────────────────────────────────────────────
//             Center(
//               child: SmoothPageIndicator(
//                 controller: _bannerCtrl,
//                 count: _banners.length,
//                 effect: const WormEffect(
//                   dotHeight: 8,
//                   dotWidth: 8,
//                   activeDotColor: Color(0xFF2563EB),
//                   dotColor: Color(0xFFD1D5DB),
//                   spacing: 6,
//                 ),
//               ),
//             ),

//             const SizedBox(height: 20),

//             // ── Category row ─────────────────────────────────────────────
//             _CategoryRow(
//               selected: _selectedCategory,
//               onSelect: (i) => setState(() => _selectedCategory = i),
//             ),

//             const SizedBox(height: 20),

//             // ── Nearby / Brand toggle ─────────────────────────────────────
//             Padding(
//               padding: const EdgeInsets.symmetric(horizontal: 16),
//               child: _DealsToggle(
//                 isNearby: _isNearby,
//                 onToggle: (v) => setState(() => _isNearby = v),
//               ),
//             ),

//             const SizedBox(height: 16),

//             // ── Deal cards ────────────────────────────────────────────────
//             Padding(
//               padding: const EdgeInsets.symmetric(horizontal: 16),
//               child: Column(
//                 children: deals.map((d) => _DealCard(deal: d)).toList(),
//               ),
//             ),

//             const SizedBox(height: 90),
//           ],
//         ),
//       ),
//     );
//   }
// }

// // ─────────────────────────────────────────────────────────────────────────────
// // Banner slide  (network image with gradient fallback)
// // ─────────────────────────────────────────────────────────────────────────────

// class _BannerSlide extends StatelessWidget {
//   final _BannerData data;
//   const _BannerSlide({required this.data});

//   Widget _fallback() => Container(
//         decoration: BoxDecoration(gradient: data.gradient),
//         child: Center(
//           child: Column(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               Text(
//                 data.headline,
//                 textAlign: TextAlign.center,
//                 style: const TextStyle(
//                   color: Colors.white,
//                   fontSize: 22,
//                   fontWeight: FontWeight.bold,
//                   letterSpacing: 0.5,
//                 ),
//               ),
//               const SizedBox(height: 8),
//               Text(
//                 data.sub,
//                 style: TextStyle(
//                     color: Colors.white.withOpacity(0.9), fontSize: 14),
//               ),
//             ],
//           ),
//         ),
//       );

//   @override
//   Widget build(BuildContext context) {
//     return CachedNetworkImage(
//       imageUrl: data.imageUrl,
//       fit: BoxFit.cover,
//       width: double.infinity,
//       placeholder: (_, __) => _fallback(),
//       errorWidget: (_, __, ___) => _fallback(),
//     );
//   }
// }

// // ─────────────────────────────────────────────────────────────────────────────
// // Category row
// // ─────────────────────────────────────────────────────────────────────────────

// // class _CategoryRow extends StatelessWidget {
// //   final int selected;
// //   final ValueChanged<int> onSelect;
// //   const _CategoryRow({required this.selected, required this.onSelect});

// //   @override
// //   Widget build(BuildContext context) {
// //     return SizedBox(
// //       height: 92,
// //       child: ListView.separated(
// //         scrollDirection: Axis.horizontal,
// //         padding: const EdgeInsets.symmetric(horizontal: 16),
// //         itemCount: _categories.length,
// //         separatorBuilder: (_, __) => const SizedBox(width: 27),
// //         itemBuilder: (ctx, i) {
// //           final cat = _categories[i];
// //           final active = selected == i;
// //           return GestureDetector(
// //             onTap: () => onSelect(i),
// //             child: Column(
// //               mainAxisSize: MainAxisSize.min,
// //               children: [
// //                 Container(
// //                   width: 70,
// //                   height: 70,
// //                   decoration: BoxDecoration(
// //                     shape: BoxShape.circle,
// //                     color: active
// //                         ? cat.color
// //                         : cat.color.withOpacity(0.13),
// //                     boxShadow: [
// //                       BoxShadow(
// //                         color: cat.color.withOpacity(active ? 0.35 : 0.10),
// //                         blurRadius: active ? 12 : 6,
// //                         offset: const Offset(0, 3),
// //                       ),
// //                     ],
// //                   ),
// //                   child: Stack(
// //                     alignment: Alignment.center,
// //                     children: [
// //                       Icon(
// //                         cat.icon,
// //                         size: 28,
// //                         color: active ? Colors.white : cat.color,
// //                       ),
// //                       if (cat.isNew)
// //                         Positioned(
// //                           top: 4,
// //                           right: 2,
// //                           child: Container(
// //                             padding: const EdgeInsets.symmetric(
// //                                 horizontal: 4, vertical: 2),
// //                             decoration: BoxDecoration(
// //                               color: const Color(0xFFEAB308),
// //                               borderRadius: BorderRadius.circular(4),
// //                             ),
// //                             child: const Text(
// //                               'New',
// //                               style: TextStyle(
// //                                 fontSize: 7,
// //                                 color: Colors.white,
// //                                 fontWeight: FontWeight.bold,
// //                               ),
// //                             ),
// //                           ),
// //                         ),
// //                     ],
// //                   ),
// //                 ),
// //                 const SizedBox(height: 6),
// //                 Text(
// //                   cat.label,
// //                   style: TextStyle(
// //                     fontSize: 11,
// //                     fontWeight:
// //                         active ? FontWeight.w600 : FontWeight.normal,
// //                     color: active ? cat.color : const Color(0xFF374151),
// //                   ),
// //                 ),
// //               ],
// //             ),
// //           );
// //         },
// //       ),
// //     );
// //   }
// // }
// class _CategoryRow extends StatelessWidget {
//   final int selected;
//   final ValueChanged<int> onSelect;

//   const _CategoryRow({
//     required this.selected,
//     required this.onSelect,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return SizedBox(
//       height: 100,
//       child: PageView.builder(
//         controller: PageController(viewportFraction: 1),
//         itemCount: (_categories.length / 5).ceil(),
//         itemBuilder: (context, pageIndex) {
//           final start = pageIndex * 5;

//           final end = (start + 5 > _categories.length)
//               ? _categories.length
//               : start + 5;

//           final pageItems = _categories.sublist(start, end);

//           return Row(
//             mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//             children: pageItems.asMap().entries.map((entry) {
//               final index = start + entry.key;

//               final cat = entry.value;

//               final active = selected == index;

//               return GestureDetector(
//                 onTap: () => onSelect(index),
//                 child: SizedBox(
//                   width: 78,
//                   child: Column(
//                     children: [
//                       Container(
//                         width: 86,
//                         height: 64,
//                         decoration: BoxDecoration(
//                           shape: BoxShape.circle,
//                           color: Colors.white,
//                           border: Border.all(
//                             color: const Color(0xFFE5E7EB),
//                           ),
//                         ),
//                         child: Stack(
//                           alignment: Alignment.center,
//                           children: [
//                             Icon(
//                               cat.icon,
//                               size: 28,
//                               color: active
//                                   ? const Color(0xFF1565C0)
//                                   : Colors.black87,
//                             ),

//                             // NEW badge
//                             if (cat.isNew)
//                               Positioned(
//                                 top: 5,
//                                 left: 2,
//                                 child: Container(
//                                   padding: const EdgeInsets.symmetric(
//                                     horizontal: 5,
//                                     vertical: 2,
//                                   ),
//                                   decoration: BoxDecoration(
//                                     color: const Color(0xFFF4B400),
//                                     borderRadius:
//                                         BorderRadius.circular(8),
//                                   ),
//                                   child: const Text(
//                                     'New',
//                                     style: TextStyle(
//                                       fontSize: 8,
//                                       fontWeight: FontWeight.bold,
//                                       color: Colors.black,
//                                     ),
//                                   ),
//                                 ),
//                               ),
//                           ],
//                         ),
//                       ),

//                       const SizedBox(height: 8),

//                       Text(
//                         cat.label,
//                         maxLines: 2,
//                         textAlign: TextAlign.center,
//                         style: const TextStyle(
//                           fontSize: 12,
//                           height: 1.2,
//                           color: Colors.black87,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               );
//             }).toList(),
//           );
//         },
//       ),
//     );
//   }
// }

// // ─────────────────────────────────────────────────────────────────────────────
// // Nearby / Brand toggle
// // ─────────────────────────────────────────────────────────────────────────────

// class _DealsToggle extends StatelessWidget {
//   final bool isNearby;
//   final ValueChanged<bool> onToggle;
//   const _DealsToggle({required this.isNearby, required this.onToggle});

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       height: 52,
//       padding: const EdgeInsets.all(4),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(30),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.07),
//             blurRadius: 10,
//             offset: const Offset(0, 2),
//           ),
//         ],
//       ),
//       child: Row(
//         children: [
//           _ToggleBtn(
//               label: 'Nearby Deals',
//               active: isNearby,
//               onTap: () => onToggle(true)),
//           _ToggleBtn(
//               label: 'Brand Deals',
//               active: !isNearby,
//               onTap: () => onToggle(false)),
//         ],
//       ),
//     );
//   }
// }

// class _ToggleBtn extends StatelessWidget {
//   final String label;
//   final bool active;
//   final VoidCallback onTap;
//   const _ToggleBtn(
//       {required this.label, required this.active, required this.onTap});

//   @override
//   Widget build(BuildContext context) {
//     return Expanded(
//       child: GestureDetector(
//         onTap: onTap,
//         child: AnimatedContainer(
//           duration: const Duration(milliseconds: 200),
//           height: double.infinity,
//           decoration: BoxDecoration(
//             color:
//                 active ? const Color(0xFF2563EB) : Colors.transparent,
//             borderRadius: BorderRadius.circular(26),
//           ),
//           alignment: Alignment.center,
//           child: Text(
//             label,
//             style: TextStyle(
//               fontSize: 16,
//               fontWeight: FontWeight.w600,
//               color: active ? Colors.white : const Color(0xFF6B7280),
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }

// // ─────────────────────────────────────────────────────────────────────────────
// // Deal card
// // ─────────────────────────────────────────────────────────────────────────────

// class _DealCard extends StatefulWidget {
//   final DealData deal;
//   const _DealCard({required this.deal});

//   @override
//   State<_DealCard> createState() => _DealCardState();
// }

// class _DealCardState extends State<_DealCard> {
//   bool _fav = false;

//   @override
//   Widget build(BuildContext context) {
//     final d = widget.deal;
//     return Container(
//       margin: const EdgeInsets.only(bottom: 14),
//       height: 110,
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(14),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.07),
//             blurRadius: 14,
//             offset: const Offset(0, 4),
//           ),
//         ],
//       ),
//       child: Row(
//         children: [
//           // ── Left image ────────────────────────────────────────────────
//           ClipRRect(
//             borderRadius: const BorderRadius.only(
//               topLeft: Radius.circular(14),
//               bottomLeft: Radius.circular(14),
//             ),
//             child: SizedBox(
//               width: 110,
//               height: 110,
//               child: CachedNetworkImage(
//                 imageUrl: d.imageUrl,
//                 fit: BoxFit.cover,
//                 placeholder: (_, __) => Container(
//                   color: d.fallbackColor,
//                   child: Icon(d.fallbackIcon,
//                       color: const Color(0xFF9CA3AF), size: 36),
//                 ),
//                 errorWidget: (_, __, ___) => Container(
//                   color: d.fallbackColor,
//                   child: Icon(d.fallbackIcon,
//                       color: const Color(0xFF9CA3AF), size: 36),
//                 ),
//               ),
//             ),
//           ),

//           // ── Right content ─────────────────────────────────────────────
//           Expanded(
//             child: Padding(
//               padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   // Name + heart
//                   Row(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Expanded(
//                         child: Text(
//                           d.name,
//                           style: const TextStyle(
//                             fontSize: 16,
//                             fontWeight: FontWeight.bold,
//                             color: Color(0xFF111827),
//                           ),
//                           maxLines: 1,
//                           overflow: TextOverflow.ellipsis,
//                         ),
//                       ),
//                       const SizedBox(width: 4),
//                       GestureDetector(
//                         onTap: () => setState(() => _fav = !_fav),
//                         child: Container(
//                           padding: const EdgeInsets.all(5),
//                           decoration: BoxDecoration(
//                             shape: BoxShape.circle,
//                             border: Border.all(
//                                 color: const Color(0xFFE5E7EB)),
//                             color: Colors.white,
//                           ),
//                           child: Icon(
//                             _fav
//                                 ? Icons.favorite_rounded
//                                 : Icons.favorite_border_rounded,
//                             size: 15,
//                             color: _fav
//                                 ? Colors.redAccent
//                                 : const Color(0xFF9CA3AF),
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),

//                   const SizedBox(height: 3),

//                   // Location
//                   Text(d.location,
//                       style: const TextStyle(
//                           fontSize: 12, color: Color.fromARGB(255, 0, 0, 0))),

//                   const SizedBox(height: 5),

//                   // Offer text
//                   Text(
//                     d.offer,
//                     style: const TextStyle(
//                       fontSize: 15,
//                       fontWeight: FontWeight.w500,
//                       color: Color.fromARGB(255, 0, 81, 255),
//                     ),
//                     maxLines: 1,
//                     overflow: TextOverflow.ellipsis,
//                   ),

//                   const SizedBox(height: 8),

//                   // Chips row
//                   Row(
//                     children: [
//                       _Chip(label: d.distance),
//                       const SizedBox(width: 8),
//                       _Chip(label: d.type),
//                     ],
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// // ─────────────────────────────────────────────────────────────────────────────
// // Tag chip
// // ─────────────────────────────────────────────────────────────────────────────

// class _Chip extends StatelessWidget {
//   final String label;
//   const _Chip({required this.label});

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding:
//           const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
//       decoration: BoxDecoration(
//         color: const Color(0xFFF3F4F6),
//         borderRadius: BorderRadius.circular(20),
//       ),
//       child: Text(
//         label,
//         style: const TextStyle(
//           fontSize: 11,
//           color: Color(0xFF374151),
//           fontWeight: FontWeight.w500,
//         ),
//       ),
//     );
//   }
// }
import 'dart:async';
import 'dart:math' show Random;
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:video_player/video_player.dart';
import 'package:geocoding/geocoding.dart';
import '../../../core/services/location_service.dart';
import '../../../core/network/api_client.dart';
import '../../../core/router/app_router.dart' show appRouteObserver, rootNavigatorKey;
import '../../auth/providers/auth_provider.dart';
import '../../notifications/providers/notification_provider.dart';
import '../../deals/models/deal_model.dart';
import '../../deals/services/deal_service.dart';
import '../../shops/models/shop_category.dart';
import '../../shops/screens/shop_list_screen.dart';
import '../../shops/services/shop_service.dart';
import '../../profile/providers/profile_provider.dart';
import '../../reels/models/reel_model.dart';
import '../../reels/services/reel_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Mock data  (replace with live API calls once backend is wired up)
// ─────────────────────────────────────────────────────────────────────────────

final _banners = [
  _BannerData(
    imageUrl:
        'https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?w=700&q=80',
    gradient: const LinearGradient(
        colors: [Color(0xFFE65100), Color(0xFFFF8F00)]),
    headline: 'FOOD MAKES LIFE GOOD!',
    sub: 'Exclusive deals near you',
  ),
  _BannerData(
    imageUrl:
        'https://images.unsplash.com/photo-1607082348824-0a96f2a4b9da?w=700&q=80',
    gradient: const LinearGradient(
        colors: [Color(0xFF1565C0), Color(0xFF2563EB)]),
    headline: 'BEST DEALS NEAR YOU!',
    sub: 'Up to 50% off today',
  ),
  _BannerData(
    imageUrl:
        'https://images.unsplash.com/photo-1542838132-92c53300491e?w=700&q=80',
    gradient: const LinearGradient(
        colors: [Color(0xFF2E7D32), Color(0xFF43A047)]),
    headline: 'SAVE MORE TODAY!',
    sub: 'Fresh grocery deals',
  ),
  _BannerData(
    imageUrl:
        'https://images.unsplash.com/photo-1483985988355-763728e1935b?w=700&q=80',
    gradient: const LinearGradient(
        colors: [Color(0xFF6A1B9A), Color(0xFFAB47BC)]),
    headline: 'EXCLUSIVE OFFERS!',
    sub: 'Shop and save big',
  ),
];

final _categories = [
  _CatData(label: 'New deals',             icon: Icons.local_offer_rounded,       color: Color(0xFFEF4444), isNew: true),
  _CatData(label: 'Groceries',             icon: Icons.shopping_basket_rounded,   color: Color(0xFF10B981)),
  _CatData(label: 'Supermarket',           icon: Icons.store_rounded,             color: Color(0xFF3B82F6)),
  _CatData(label: 'Pharmacy',              icon: Icons.local_pharmacy_rounded,    color: Color(0xFF06B6D4)),
  _CatData(label: 'Salon',                 icon: Icons.content_cut_rounded,       color: Color(0xFFF59E0B)),
  _CatData(label: 'Gym',                   icon: Icons.fitness_center_rounded,    color: Color(0xFF8B5CF6)),
  _CatData(label: 'Restaurant',            icon: Icons.restaurant_rounded,        color: Color(0xFFEC4899)),
  _CatData(label: 'Cafes',                 icon: Icons.local_cafe_rounded,        color: Color(0xFF92400E)),
  _CatData(label: 'Clothing',              icon: Icons.checkroom_rounded,         color: Color(0xFFDB2777)),
  _CatData(label: 'Department',            icon: Icons.apartment_rounded,         color: Color(0xFF0284C7)),
  _CatData(label: 'Electronics',           icon: Icons.devices_rounded,           color: Color(0xFF7C3AED)),
  _CatData(label: 'Books',                 icon: Icons.menu_book_rounded,         color: Color(0xFF0D9488)),
  _CatData(label: 'Toys',                  icon: Icons.toys_rounded,              color: Color(0xFFF97316)),
  _CatData(label: 'Baby',                  icon: Icons.child_care_rounded,        color: Color(0xFFEC4899)),
  _CatData(label: 'Home Decor',            icon: Icons.weekend_rounded,           color: Color(0xFFF59E0B)),
  _CatData(label: 'Furniture',             icon: Icons.chair_rounded,             color: Color(0xFF78350F)),
  _CatData(label: 'Spa',                   icon: Icons.spa_rounded,               color: Color(0xFF059669)),
  _CatData(label: 'Schools',               icon: Icons.school_rounded,            color: Color(0xFF2563EB)),
  _CatData(label: 'Colleges',              icon: Icons.account_balance_rounded,   color: Color(0xFF1D4ED8)),
  _CatData(label: 'Tutoring',              icon: Icons.menu_book_outlined,        color: Color(0xFF9333EA)),
  _CatData(label: 'Clinics',               icon: Icons.local_hospital_rounded,    color: Color(0xFFEF4444)),
  _CatData(label: 'Hospitals',             icon: Icons.emergency_rounded,         color: Color(0xFFDC2626)),
  _CatData(label: 'Pets',                  icon: Icons.pets_rounded,              color: Color(0xFF10B981)),
  _CatData(label: 'Sports',                icon: Icons.sports_soccer_rounded,     color: Color(0xFF16A34A)),
  _CatData(label: 'Travel',                icon: Icons.luggage_rounded,           color: Color(0xFFEF4444)),
  _CatData(label: 'Mobile &\nAccessories', icon: Icons.smartphone_rounded,        color: Color(0xFF0284C7)),
  _CatData(label: 'Computer &\nLaptop',    icon: Icons.laptop_rounded,            color: Color(0xFF6366F1)),
  _CatData(label: 'Gifts',                 icon: Icons.card_giftcard_rounded,     color: Color(0xFFE11D48)),
  _CatData(label: 'Jewellery',             icon: Icons.diamond_rounded,           color: Color(0xFFB45309)),
  _CatData(label: 'Shoes',                 icon: Icons.directions_run_rounded,    color: Color(0xFF0369A1)),
];

final _nearbyDeals = [
  DealData(
    name: 'Smile Dentist',
    location: 'Padi, Chennai',
    offer: '25% Off on All Treatments',
    distance: '6 Km',
    type: 'Clinic',
    imageUrl: 'https://images.unsplash.com/photo-1588776814546-ec7eb8e02bb5?w=700&q=80',
    fallbackColor: const Color(0xFFE3F2FD),
    fallbackIcon: Icons.local_hospital_rounded,
    description: 'Smile Dentist offers world-class dental care with experienced professionals. Get 25% off on all treatments including cleaning, fillings, and orthodontics.',
    address: '12, 3rd Street, Padi, Chennai - 600050',
    phone: '+91 98765 43210',
    timing: 'Mon–Sat: 9am – 8pm',
    rating: 4.5,
    reviews: 128,
  ),
  DealData(
    name: 'CK Bakers',
    location: 'Anna Nagar, Chennai',
    offer: 'Buy 2 Get 1 Free on Cakes',
    distance: '3 Km',
    type: 'Bakery',
    imageUrl: 'https://images.unsplash.com/photo-1568254183919-78a4f43a2877?w=700&q=80',
    fallbackColor: const Color(0xFFFFF3E0),
    fallbackIcon: Icons.bakery_dining_rounded,
    description: 'CK Bakers is Anna Nagar\'s favourite bakery since 1995. Freshly baked breads, cakes and pastries every day. Buy 2 Get 1 Free on all custom cakes this month.',
    address: '45, 2nd Avenue, Anna Nagar, Chennai - 600040',
    phone: '+91 98765 12345',
    timing: 'Daily: 7am – 10pm',
    rating: 4.3,
    reviews: 312,
  ),
  DealData(
    name: 'India Mart',
    location: 'Padi, Chennai',
    offer: '25% Off on All Grocery',
    distance: '2 Km',
    type: 'Supermarket',
    imageUrl: 'https://images.unsplash.com/photo-1534723452862-4c874018d66d?w=700&q=80',
    fallbackColor: const Color(0xFFE8F5E9),
    fallbackIcon: Icons.store_mall_directory_rounded,
    description: 'Your one-stop shop for all groceries. Fresh vegetables, fruits, dairy and household essentials — all under one roof at unbeatable prices.',
    address: '89, Industrial Estate, Padi, Chennai - 600050',
    phone: '+91 44 2651 1234',
    timing: 'Daily: 8am – 9pm',
    rating: 4.1,
    reviews: 245,
  ),
  DealData(
    name: 'Fitness First',
    location: 'Velachery, Chennai',
    offer: '50% Off on 3-Month Membership',
    distance: '8 Km',
    type: 'Gym',
    imageUrl: 'https://images.unsplash.com/photo-1534438327276-14e5300c3a48?w=700&q=80',
    fallbackColor: const Color(0xFFE3F2FD),
    fallbackIcon: Icons.fitness_center_rounded,
    description: 'State-of-the-art gym with premium equipment, personal trainers and group classes. Get 50% off your first 3-month membership.',
    address: '100 Feet Road, Velachery, Chennai - 600042',
    phone: '+91 98400 55555',
    timing: 'Mon–Sat: 5am – 11pm | Sun: 6am – 9pm',
    rating: 4.6,
    reviews: 189,
  ),
  DealData(
    name: 'Naturals Salon',
    location: 'Nungambakkam, Chennai',
    offer: '30% Off on All Hair Services',
    distance: '5 Km',
    type: 'Salon',
    imageUrl: 'https://images.unsplash.com/photo-1521590832167-7bcbfaa6381f?w=700&q=80',
    fallbackColor: const Color(0xFFFCE4EC),
    fallbackIcon: Icons.content_cut_rounded,
    description: 'Naturals is India\'s leading salon chain. Expert stylists, premium products and the latest trends — all at great prices this season.',
    address: '22, Khader Nawaz Khan Rd, Nungambakkam, Chennai - 600006',
    phone: '+91 44 4390 1234',
    timing: 'Daily: 9am – 8pm',
    rating: 4.4,
    reviews: 421,
  ),
];

final _brandDeals = [
  DealData(
    name: 'T. Nagar Silks',
    location: 'T. Nagar, Chennai',
    offer: 'Flat 20% Off on Sarees',
    distance: '10 Km',
    type: 'Clothing',
    imageUrl: 'https://images.unsplash.com/photo-1583391733956-6c78276477e2?w=700&q=80',
    fallbackColor: const Color(0xFFF3E5F5),
    fallbackIcon: Icons.checkroom_rounded,
    description: 'T. Nagar\'s most trusted silk saree brand since 1978. Premium Kancheepuram silks, designer lehengas and ethnic wear at factory prices.',
    address: '140, Usman Road, T. Nagar, Chennai - 600017',
    phone: '+91 44 2434 5678',
    timing: 'Daily: 10am – 9pm',
    rating: 4.7,
    reviews: 876,
  ),
  DealData(
    name: 'Adyar Ananda Bhavan',
    location: 'Adyar, Chennai',
    offer: '10% Off on All Sweet Boxes',
    distance: '7 Km',
    type: 'Restaurant',
    imageUrl: 'https://images.unsplash.com/photo-1517244683847-7456b63c5969?w=700&q=80',
    fallbackColor: const Color(0xFFFFF3E0),
    fallbackIcon: Icons.restaurant_rounded,
    description: 'A&B — the iconic South Indian sweet and snack chain. Authentic recipes, hygienic preparation and the same great taste since 1988.',
    address: '16, 4th Main Road, Adyar, Chennai - 600020',
    phone: '+91 44 2441 5252',
    timing: 'Daily: 7am – 10pm',
    rating: 4.5,
    reviews: 1240,
  ),
  DealData(
    name: 'Anna Nagar Electronics',
    location: 'Anna Nagar, Chennai',
    offer: 'Up to 15% Off on Appliances',
    distance: '4 Km',
    type: 'Electronics',
    imageUrl: 'https://images.unsplash.com/photo-1550009158-9ebf69173e03?w=700&q=80',
    fallbackColor: const Color(0xFFE3F2FD),
    fallbackIcon: Icons.devices_rounded,
    description: 'Chennai\'s largest multi-brand electronics store. TVs, refrigerators, washing machines, mobiles — all brands, best prices, free installation.',
    address: 'Plot 5, 5th Avenue, Anna Nagar, Chennai - 600040',
    phone: '+91 98400 11111',
    timing: 'Mon–Sat: 9am – 9pm',
    rating: 4.2,
    reviews: 567,
  ),
  DealData(
    name: 'MedPlus Pharmacy',
    location: 'Porur, Chennai',
    offer: '10% Off on All Medicines',
    distance: '2 Km',
    type: 'Pharmacy',
    imageUrl: 'https://images.unsplash.com/photo-1584308666744-24d5c474f2ae?w=700&q=80',
    fallbackColor: const Color(0xFFE8EAF6),
    fallbackIcon: Icons.local_pharmacy_rounded,
    description: 'MedPlus is one of India\'s largest pharmacy chains. Licensed pharmacists, genuine medicines and home delivery available across Chennai.',
    address: '7, Arcot Road, Porur, Chennai - 600116',
    phone: '+91 1800 102 6454',
    timing: 'Daily: 8am – 10pm',
    rating: 4.3,
    reviews: 389,
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// Data model classes
// ─────────────────────────────────────────────────────────────────────────────

class _BannerData {
  final String imageUrl;
  final String imageData;   // raw base64 fallback
  final LinearGradient gradient;
  final String headline;
  final String sub;
  final String mediaType;   // 'image' or 'video'
  final String videoUrl;
  const _BannerData({
    required this.imageUrl,
    this.imageData = '',
    required this.gradient,
    required this.headline,
    required this.sub,
    this.mediaType = 'image',
    this.videoUrl = '',
  });

  bool get isVideo => mediaType == 'video' && videoUrl.isNotEmpty;
}

class _CatData {
  final String label;
  final IconData icon;
  final bool isNew;
  final Color color;
  const _CatData({
    required this.label,
    required this.icon,
    required this.color,
    this.isNew = false,
  });
}

// DealData imported from deals/models/deal_model.dart

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver {
  final PageController _bannerCtrl = PageController();
  Timer? _bannerTimer;
  int _currentBanner = 0;
  bool _isNearby = true;
  int _selectedCategory = 0;

  // API-loaded deals
  List<DealData> _nearbyDealsList = [];
  List<DealData> _brandDealsList = [];
  bool _loadingDeals = true;

  // API-loaded banners (replaces static _banners list)
  List<_BannerData> _apiBanners = [];

  // GPS-based nearby shops (within 4 km)
  List<ShopItem> _nearbyShops = [];
  bool _loadingNearbyShops = false;
  String _detectedArea = '';   // reverse-geocoded area name, e.g. "Anna Nagar"
  double? _userLat;
  double? _userLng;

  // Reelz ad overlay
  Timer? _reelzAdTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Auto-scroll banner — images advance after 5s, videos advance when
    // playback finishes (with a safety-timeout fallback). See
    // _scheduleNextBannerAdvance().
    _scheduleNextBannerAdvance();
    _loadDeals();
    _loadNearbyShopsFromGPS();
    _loadBanners();
    _scheduleReelzAd();
    // Fetch unread notification count for the bell badge
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationProvider>().fetchNotifications();
    });
  }

  List<_BannerData> get _activeBanners =>
      _apiBanners.isNotEmpty ? _apiBanners : _banners;

  /// Schedules the next auto-advance for the currently-shown banner.
  /// Images advance after a fixed 5s. Videos are normally advanced by
  /// _BannerSlide calling onVideoEnded() when playback finishes — this timer
  /// is just a safety fallback in case a video fails to load/play, capped
  /// generously above the expected ~14s banner-video length.
  void _scheduleNextBannerAdvance() {
    _bannerTimer?.cancel();
    final banners = _activeBanners;
    if (banners.isEmpty) return;
    final current = banners[_currentBanner % banners.length];
    final delay = current.isVideo
        ? const Duration(seconds: 20)
        : const Duration(seconds: 5);
    _bannerTimer = Timer(delay, _advanceBanner);
  }

  void _advanceBanner() {
    _bannerTimer?.cancel();
    if (!_bannerCtrl.hasClients) return;
    final banners = _activeBanners;
    if (banners.isEmpty) return;
    final next = (_currentBanner + 1) % banners.length;
    _bannerCtrl.animateToPage(
      next,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  /// Fetch banners from /banners API; fall back to static if empty/error.
  Future<void> _loadBanners() async {
    try {
      final resp = await ApiClient().get('/banners');
      if (resp.statusCode == 200 && resp.data is Map) {
        final list = resp.data['banners'] as List? ?? [];
        final parsed = list.map((b) {
          final imageUrl = (b['image_url'] as String? ?? '').trim();
          final imageData = (b['image_data'] as String? ?? '').trim();
          final videoUrl = (b['video_url'] as String? ?? '').trim();
          final mediaType = (b['media_type'] as String? ??
                  (videoUrl.isNotEmpty ? 'video' : 'image'))
              .trim();
          return _BannerData(
            imageUrl: imageUrl,
            imageData: imageData,
            gradient: const LinearGradient(
                colors: [Color(0xFF1565C0), Color(0xFF2563EB)]),
            headline: b['headline'] as String? ?? '',
            sub: b['sub'] as String? ?? '',
            mediaType: mediaType,
            videoUrl: videoUrl,
          );
        }).toList();
        if (mounted && parsed.isNotEmpty) {
          setState(() => _apiBanners = parsed);
          _scheduleNextBannerAdvance();
        }
      }
    } catch (e) {
      debugPrint('_loadBanners error: $e');
    }
  }

  /// Returns true if at least 5 minutes have passed since the last ad.
  bool _canShowAd() {
    if (_reelzAdLastShownAt == null) return true;
    return DateTime.now().difference(_reelzAdLastShownAt!) >=
        const Duration(minutes: 5);
  }

  /// Fetch reels then show one randomly after a short delay —
  /// but only if the 5-minute cooldown has expired.
  Future<void> _scheduleReelzAd() async {
    if (!_canShowAd()) return;
    final reels = await ReelService.instance.fetchReels();
    if (!mounted || reels.isEmpty) return;

    // Short delay (5–12 s) so the user sees the home screen first
    final delaySec = 5 + Random().nextInt(8);
    _reelzAdTimer = Timer(Duration(seconds: delaySec), () {
      if (!mounted || !_canShowAd()) return;
      final reel = reels[Random().nextInt(reels.length)];
      _reelzAdLastShownAt = DateTime.now();
      _showReelzAd(reel);
    });
  }


  void _showReelzAd(ReelItem reel) {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black,           // full black — dialog fills screen
      transitionDuration: const Duration(milliseconds: 350),
      transitionBuilder: (_, anim, __, child) => FadeTransition(
        opacity: CurvedAnimation(parent: anim, curve: Curves.easeIn),
        child: child,
      ),
      pageBuilder: (ctx, _, __) => _ReelzAdDialog(
        reel: reel,
        onClose: () => Navigator.of(ctx).pop(),
        onWatch: () {
          Navigator.of(ctx).pop();
          context.push('/reelz');
        },
      ),
    );
  }

  /// Fetch nearby + brand deals from the backend
  Future<void> _loadDeals() async {
    setState(() => _loadingDeals = true);
    final nearby = await DealService.instance.fetchNearbyDeals();
    final brand  = await DealService.instance.fetchBrandDeals();
    if (!mounted) return;
    setState(() {
      _nearbyDealsList = nearby.map(_dtoToDealData).toList();
      _brandDealsList  = brand.map(_dtoToDealData).toList();
      _loadingDeals    = false;
    });
  }

  /// Fetch shops within 4 km of the user's GPS location.
  /// Also reverse-geocodes the position to a human-readable area name.
  Future<void> _loadNearbyShopsFromGPS() async {
    if (mounted) setState(() => _loadingNearbyShops = true);
    try {
      final pos = await LocationService.getPosition(
        context: mounted ? context : null,
      );
      if (pos != null) {
        final lat = pos.latitude;
        final lng = pos.longitude;

        // ── Reverse geocode to get area name ──────────────────────────
        String areaName = '';
        try {
          final placemarks = await placemarkFromCoordinates(lat, lng);
          if (placemarks.isNotEmpty) {
            final p = placemarks.first;
            // subLocality = neighbourhood / area (e.g. "Anna Nagar")
            // locality    = city (e.g. "Chennai")
            areaName = p.subLocality?.isNotEmpty == true
                ? p.subLocality!
                : p.locality ?? '';
          }
        } catch (_) {}

        // ── Fetch nearby shops from backend ───────────────────────────
        final shops = await ShopService.instance.fetchNearbyShops(
          lat: lat,
          lng: lng,
          radiusKm: 4.0,
        );

        if (mounted) {
          setState(() {
            _userLat = lat;
            _userLng = lng;
            _detectedArea = areaName;
            _nearbyShops = shops;
          });
        }
      }
    } catch (e) {
      debugPrint('Dashboard GPS error: \$e');
    }
    if (mounted) setState(() => _loadingNearbyShops = false);
  }

  /// Convert DealDto → DealData for display
  static DealData _dtoToDealData(DealDto d) => DealData(
        id: d.id,
        name: d.name,
        location: d.location,
        offer: d.offer,
        distance: d.distance,
        type: d.type,
        imageUrl: d.imageUrl,
        imageData: d.imageData,
        fallbackColor: const Color(0xFFEEEEEE),
        fallbackIcon: Icons.store_rounded,
        description: d.description,
        address: d.address,
        phone: d.phone,
        timing: d.timing,
        rating: d.rating,
        reviews: d.reviews,
      );

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _bannerTimer?.cancel();
    _reelzAdTimer?.cancel();
    _bannerCtrl.dispose();
    // Note: _reelzAdLastShownAt is static — intentionally kept alive across rebuilds
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Re-fetch nearby shops when user returns to app (location may have changed)
    if (state == AppLifecycleState.resumed) {
      _loadNearbyShopsFromGPS();
    }
  }

  // ── Custom white AppBar ──────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar() {
  return PreferredSize(
    // kToolbarHeight = 56 dp (Material standard). Using that + small padding
    // keeps the bar proportional on any screen density or display-zoom level.
    preferredSize: const Size.fromHeight(kToolbarHeight + 2),
    child: Container(
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 2,
          ),
          child: Row(
            children: [
              // ── Logo (home_main_logo has icon + "claimit" text built-in) ──
              Image.asset(
                'assets/images/home_main_logo.png',
                height: 30,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Row(
                  children: [
                    Image.asset('assets/icons/main_icon.png',
                        width: 38, height: 38, fit: BoxFit.contain),
                    const SizedBox(width: 6),
                    const Text('claimit',
                        style: TextStyle(fontSize: 26,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1565C0))),
                  ],
                ),
              ),

              const Spacer(),

              // ── Location (from user profile) ────────────────────────
              GestureDetector(
                onTap: () => context.push('/location'),
                child: ConstrainedBox(
                  // Cap the location chip so long names like
                  // "Chennai, Tamil Nadu" don't overflow the AppBar Row.
                  constraints: const BoxConstraints(maxWidth: 140),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          context.select<AuthProvider, String>(
                            (a) => a.user?.location?.isNotEmpty == true
                                ? a.user!.location!
                                : 'Select Area',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                      const Icon(Icons.keyboard_arrow_down_rounded, size: 22),
                    ],
                  ),
                ),
              ),

              const Spacer(),

              // ── Search ──────────────────────────
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFE5E7EB),
                  ),
                ),
                child: IconButton(
                  icon: Icon(
                    Icons.search,
                    size: 28,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  onPressed: () => context.push('/search'),
                  padding: EdgeInsets.zero,
                ),
              ),

              const SizedBox(width: 8),

              // ── Notification bell with unread dot ──────────────────
              Consumer<NotificationProvider>(
                builder: (context, notifProvider, _) {
                  final unread = notifProvider.unreadCount;
                  return SizedBox(
                    width: 44,
                    height: 44,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        IconButton(
                          icon: Icon(
                            unread > 0
                                ? Icons.notifications_rounded
                                : Icons.notifications_none_rounded,
                            size: 28,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          onPressed: () => context.push('/notifications'),
                          padding: EdgeInsets.zero,
                        ),
                        if (unread > 0)
                          Positioned(
                            top: 6,
                            right: 6,
                            child: Container(
                              width: 9,
                              height: 9,
                              decoration: const BoxDecoration(
                                color: Color(0xFFEF4444),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    // Use API deals (fallback to static mock if API not yet loaded)
    final nearbySource = _nearbyDealsList.isNotEmpty ? _nearbyDealsList : _nearbyDeals;
    final brandSource  = _brandDealsList.isNotEmpty  ? _brandDealsList  : _brandDeals;
    final deals = _isNearby ? nearbySource : brandSource;

    return Scaffold(
      appBar: _buildAppBar(),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([
            _loadDeals(),
            _loadNearbyShopsFromGPS(),
          ]);
        },
        color: const Color(0xFF1565C0),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Banner carousel with dots overlaid ──────────────────────
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                children: [
                  PageView.builder(
                    controller: _bannerCtrl,
                    onPageChanged: (i) {
                      setState(() => _currentBanner = i);
                      _scheduleNextBannerAdvance();
                    },
                    itemCount: _activeBanners.length,
                    itemBuilder: (ctx, i) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: GestureDetector(
                          onTap: () => context.push('/national-ads'),
                          child: _BannerSlide(
                            key: ValueKey(
                                'banner_${i}_${_activeBanners[i].imageUrl}${_activeBanners[i].videoUrl}'),
                            data: _activeBanners[i],
                            isActive: i == _currentBanner,
                            onVideoEnded: () {
                              if (i == _currentBanner) _advanceBanner();
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                  // ── Dots overlaid at bottom of banner ─────────────────
                  Positioned(
                    bottom: 10,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: SmoothPageIndicator(
                        controller: _bannerCtrl,
                        count: _activeBanners.length,
                        effect: const ColorTransitionEffect(
                          dotHeight: 8,
                          dotWidth: 8,
                          activeDotColor: Color(0xFF2563EB),
                          dotColor: Color(0xFFD1D5DB),
                          spacing: 6,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Category row ─────────────────────────────────────────────
            Transform.translate(
              offset: const Offset(0, -12),
              child: _CategoryRow(
                selected: _selectedCategory,
                onSelect: (i) => setState(() => _selectedCategory = i),
              ),
            ),

            // ── Nearby / Brand toggle + Deal cards (shifted up) ──────────
            Transform.translate(
              offset: const Offset(0, -28),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _DealsToggle(
                      isNearby: _isNearby,
                      onToggle: (v) => setState(() => _isNearby = v),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // ── Deal cards (from API) ───────────────────────────────
                  if (_loadingDeals)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(
                          child: CircularProgressIndicator(
                              color: Color(0xFF2563EB))),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: deals.map((d) => _DealCard(deal: d)).toList(),
                      ),
                    ),
                ],
              ),
            ),

            // ── GPS Nearby Shops (within 4 km) ────────────────────────────
            if (_isNearby) ...[
              const SizedBox(height: 8),
              if (_loadingNearbyShops)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                      child: CircularProgressIndicator(
                          color: Color(0xFF2563EB), strokeWidth: 2)),
                )
              else if (_nearbyShops.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _detectedArea.isNotEmpty
                                ? 'Near \$_detectedArea'
                                : 'Shops Near You',
                            style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1A1A1A)),
                          ),
                          Text(
                            'Within 4 km · \${_nearbyShops.length} shops',
                            style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => context.push('/shops',
                            extra: const ShopCategory(
                              id: -1,
                              name: 'Nearby Shops',
                              icon: Icons.store_rounded,
                              color: Color(0xFF2563EB),
                            )),
                        child: const Text('See All',
                            style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF2563EB),
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  // 175dp ≈ 21.9% of 800dp design baseline
                  height: MediaQuery.of(context).size.height * 0.22,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _nearbyShops.length,
                    itemBuilder: (_, i) =>
                        _NearbyShopChip(shop: _nearbyShops[i]),
                  ),
                ),
              ],
            ],

            const SizedBox(height: 90),
          ],
        ),
      ),       // closes SingleChildScrollView
    ),         // closes RefreshIndicator
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Banner slide  (network image with gradient fallback)
// ─────────────────────────────────────────────────────────────────────────────

class _BannerSlide extends StatefulWidget {
  final _BannerData data;
  final bool isActive;
  final VoidCallback? onVideoEnded;
  const _BannerSlide({
    super.key,
    required this.data,
    this.isActive = false,
    this.onVideoEnded,
  });

  @override
  State<_BannerSlide> createState() => _BannerSlideState();
}

class _BannerSlideState extends State<_BannerSlide> with RouteAware {
  VideoPlayerController? _ctrl;
  bool _videoReady = false;
  bool _videoFailed = false;
  bool _endedFired = false;
  bool _coveredByAnotherRoute = false;
  PageRoute? _subscribedRoute;

  @override
  void initState() {
    super.initState();
    if (widget.data.isVideo) _initVideo();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Home lives inside the bottom-nav shell, so the route that actually
    // gets covered when e.g. Scan Bill / National Ads / a shop page opens
    // is the shell's route on the ROOT navigator — not the nested `/home`
    // route — so look the route up from the root navigator's context.
    final rootCtx = rootNavigatorKey.currentContext;
    final route = rootCtx != null ? ModalRoute.of(rootCtx) : null;
    if (route is PageRoute && route != _subscribedRoute) {
      if (_subscribedRoute != null) appRouteObserver.unsubscribe(this);
      appRouteObserver.subscribe(this, route);
      _subscribedRoute = route;
    }
  }

  void _initVideo() {
    final ctrl = VideoPlayerController.networkUrl(Uri.parse(widget.data.videoUrl));
    _ctrl = ctrl;
    ctrl.initialize().then((_) {
      if (!mounted) return;
      ctrl.setLooping(false);
      // Sound plays for the active banner; non-active ones stay muted.
      ctrl.setVolume(widget.isActive ? 1.0 : 0);
      if (widget.isActive && !_coveredByAnotherRoute) ctrl.play();
      setState(() => _videoReady = true);
    }).catchError((e) {
      debugPrint('Banner video init error: $e');
      if (mounted) setState(() => _videoFailed = true);
    });
    ctrl.addListener(() {
      if (!mounted || _endedFired) return;
      final v = ctrl.value;
      if (v.duration > Duration.zero && v.position >= v.duration) {
        _endedFired = true;
        widget.onVideoEnded?.call();
      }
    });
  }

  @override
  void didUpdateWidget(_BannerSlide old) {
    super.didUpdateWidget(old);
    if (old.data.videoUrl != widget.data.videoUrl) {
      // Different banner reused this slot — rebuild the controller.
      _ctrl?.dispose();
      _ctrl = null;
      _videoReady = false;
      _videoFailed = false;
      _endedFired = false;
      if (widget.data.isVideo) _initVideo();
      return;
    }
    if (widget.isActive != old.isActive && _ctrl != null && _videoReady) {
      if (widget.isActive) {
        _endedFired = false;
        _ctrl!.setVolume(1.0);
        if (!_coveredByAnotherRoute) {
          _ctrl!.seekTo(Duration.zero);
          _ctrl!.play();
        }
      } else {
        _ctrl!.setVolume(0);
        _ctrl!.pause();
      }
    }
  }

  // ── RouteAware ───────────────────────────────────────────────────────────
  // Stop the video (and its sound) the instant another screen covers Home —
  // tapping the banner itself, Scan Bill, a shop page, etc. — and resume
  // only if this slide is still the active one when the user comes back.
  @override
  void didPushNext() {
    _coveredByAnotherRoute = true;
    _ctrl?.pause();
  }

  @override
  void didPopNext() {
    _coveredByAnotherRoute = false;
    if (widget.isActive && _videoReady) _ctrl?.play();
  }

  @override
  void dispose() {
    if (_subscribedRoute != null) appRouteObserver.unsubscribe(this);
    _ctrl?.dispose();
    super.dispose();
  }

  Widget _fallback() => Container(
        decoration: BoxDecoration(gradient: widget.data.gradient),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                widget.data.headline,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.data.sub,
                style: TextStyle(
                    color: Colors.white.withOpacity(0.9), fontSize: 14),
              ),
            ],
          ),
        ),
      );

  Widget _buildImage() {
    final data = widget.data;
    // Use base64 image if no URL available
    if (data.imageUrl.isEmpty && data.imageData.isNotEmpty) {
      try {
        return Image.memory(base64Decode(data.imageData),
            fit: BoxFit.cover, width: double.infinity,
            errorBuilder: (_, __, ___) => _fallback());
      } catch (_) {
        return _fallback();
      }
    }
    return CachedNetworkImage(
      imageUrl: data.imageUrl,
      fit: BoxFit.cover,
      width: double.infinity,
      placeholder: (_, __) => _fallback(),
      errorWidget: (_, __, ___) => _fallback(),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.data.isVideo) return _buildImage();

    if (_videoFailed) return _fallback();
    if (!_videoReady || _ctrl == null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          _fallback(),
          const Center(
            child: CircularProgressIndicator(
                color: Colors.white70, strokeWidth: 2),
          ),
        ],
      );
    }
    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: _ctrl!.value.size.width,
        height: _ctrl!.value.size.height,
        child: VideoPlayer(_ctrl!),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Category row
// ─────────────────────────────────────────────────────────────────────────────

class _CategoryRow extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onSelect;

  const _CategoryRow({
    required this.selected,
    required this.onSelect,
  });

  // 3 pages of 5 slots; last page has 4 real icons + "Show All" button
  static const int _pages = 3;
  static const int _perPage = 5;

  Widget _buildIcon({
    required BuildContext context,
    required _CatData cat,
    required int globalIndex,
    required bool active,
    required VoidCallback onTap,
  }) {
    // Asset icons: icon1.png … icon30.png (1-based index)
    final assetPath = 'assets/icons/category_icon/icon${globalIndex + 1}.png';

    // Use screen width for responsive icon size: ~13% of width, clamped 48–60
    final iconSize = (MediaQuery.of(context).size.width * 0.11).clamp(40.0, 52.0);

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // No outer border — icon images already have a circle built in
            SizedBox(
              width: iconSize,
              height: iconSize,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Image.asset(
                    assetPath,
                    width: iconSize,
                    height: iconSize,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Icon(
                      cat.icon,
                      size: iconSize * 0.55,
                      color: active ? const Color(0xFF2563EB) : cat.color,
                    ),
                  ),
                  if (cat.isNew)
                    Positioned(
                      top: 4,
                      left: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 1),
                        // decoration: BoxDecoration(
                        //   color: const Color(0xFFF4B400),
                        //   borderRadius: BorderRadius.circular(6),
                        // ),
                        // child: const Text(
                        //   'New',
                        //   style: TextStyle(
                        //     fontSize: 8,
                        //     fontWeight: FontWeight.bold,
                        //     color: Colors.black,
                        //   ),
                        // ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              cat.label,
              maxLines: 2,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                height: 1.2,
                color: active ? const Color(0xFF2563EB) : Theme.of(context).colorScheme.onSurface,
                fontWeight: active ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShowAll(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: () => context.push('/categories'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF1E3A6E)
                    : const Color(0xFFEFF6FF),
                border: Border.all(color: const Color(0xFF2563EB)),
              ),
              child: const Icon(
                Icons.apps_rounded,
                size: 22,
                color: Color(0xFF2563EB),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'All',
              maxLines: 2,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                height: 1.2,
                color: Color(0xFF2563EB),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 108dp ≈ 13.5% of 800dp design baseline → scales with screen height
    final catRowH = MediaQuery.of(context).size.height * 0.135;
    return SizedBox(
      height: catRowH,
      child: PageView.builder(
        controller: PageController(viewportFraction: 1),
        itemCount: _pages,
        itemBuilder: (context, pageIndex) {
          final isLastPage = pageIndex == _pages - 1;
          final start = pageIndex * _perPage;
          // Last page shows 4 real icons + Show All; others show 5
          final slotCount = isLastPage ? _perPage - 1 : _perPage;
          final end = (start + slotCount).clamp(0, _categories.length);
          final pageItems = _categories.sublist(start, end);

          return Row(
            children: [
              // Real category icons for this page
              ...List.generate(slotCount, (i) {
                if (i < pageItems.length) {
                  final globalIndex = start + i;
                  final cat = pageItems[i];
                  return _buildIcon(
                    context: context,
                    cat: cat,
                    globalIndex: globalIndex,
                    active: selected == globalIndex,
                    onTap: () {
                      onSelect(globalIndex);
                      context.push(
                        '/shops',
                        extra: ShopCategory(
                          id: globalIndex + 1,
                          name: cat.label.replaceAll('\n', ' '),
                          icon: cat.icon,
                          color: cat.color,
                        ),
                      );
                    },
                  );
                }
                return const Expanded(child: SizedBox.shrink());
              }),

              // "Show All" only on the last page
              if (isLastPage) _buildShowAll(context),
            ],
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Nearby / Brand toggle
// ─────────────────────────────────────────────────────────────────────────────

class _DealsToggle extends StatelessWidget {
  final bool isNearby;
  final ValueChanged<bool> onToggle;
  const _DealsToggle({required this.isNearby, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          _ToggleBtn(
              label: 'Nearby Deals',
              active: isNearby,
              onTap: () => onToggle(true)),
          _ToggleBtn(
              label: 'Brand Deals',
              active: !isNearby,
              onTap: () => onToggle(false)),
        ],
      ),
    );
  }
}

class _ToggleBtn extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _ToggleBtn(
      {required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: double.infinity,
          decoration: BoxDecoration(
            color: active ? const Color(0xFF2563EB) : Colors.transparent,
            borderRadius: BorderRadius.circular(26),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: active ? Colors.white : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Deal card — taps open the deal detail landing page
// ─────────────────────────────────────────────────────────────────────────────

class _DealCard extends StatefulWidget {
  final DealData deal;
  const _DealCard({required this.deal});

  @override
  State<_DealCard> createState() => _DealCardState();
}

class _DealCardState extends State<_DealCard> {
  @override
  Widget build(BuildContext context) {
    final d = widget.deal;
    final profile = context.watch<ProfileProvider>();
    final dealId = d.id.isNotEmpty ? d.id : d.name;
    final isFav = profile.isLikedDeal(dealId);
    return GestureDetector(
      onTap: () => context.push('/deal-detail', extra: d),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.07),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: SizedBox(
          height: 110,
          child: ClipRect(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Left image ─────────────────────────────────────────────
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(14),
                  bottomLeft: Radius.circular(14),
                ),
                child: SizedBox(
                  width: 120,
                  child: d.imageUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: d.imageUrl,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            color: d.fallbackColor,
                            child: Icon(d.fallbackIcon,
                                color: const Color(0xFF9CA3AF), size: 44),
                          ),
                          errorWidget: (_, __, ___) => d.imageData.isNotEmpty
                              ? Image.memory(base64Decode(d.imageData), fit: BoxFit.cover)
                              : Container(color: d.fallbackColor,
                                  child: Icon(d.fallbackIcon, color: const Color(0xFF9CA3AF), size: 44)),
                        )
                      : d.imageData.isNotEmpty
                          ? Image.memory(base64Decode(d.imageData), fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(color: d.fallbackColor,
                                  child: Icon(d.fallbackIcon, color: const Color(0xFF9CA3AF), size: 44)))
                          : Container(color: d.fallbackColor,
                              child: Icon(d.fallbackIcon, color: const Color(0xFF9CA3AF), size: 44)),
                ),
              ),

              // ── Right content ───────────────────────────────────────────
              Expanded(
                child: ClipRect(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 12, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Name + heart
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              d.name,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          GestureDetector(
                            onTap: () => context.read<ProfileProvider>().toggleDealFavourite(
                              dealId,
                              name: d.name,
                              location: d.location,
                              imageUrl: d.imageUrl,
                              offer: d.offer,
                            ),
                            child: Icon(
                              isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                              size: 25,
                              color: isFav ? Colors.red : const Color.fromARGB(255, 225, 215, 13),
                            ),
                          ),
                        ],
                      ),
                      // const SizedBox(height: 5),

                      // Location — starts at same left edge as name
                      Text(
                        d.location,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF6B7280),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      // const SizedBox(height: 8),

                      // Offer badge
                      Container(
                        // padding: const EdgeInsets.symmetric(
                        //     horizontal: 10, vertical: 5),
                        // decoration: BoxDecoration(
                        //   color: Theme.of(context).brightness == Brightness.dark
                        //       ? const Color.fromARGB(255, 92, 113, 152)
                        //       : const Color.fromARGB(255, 255, 255, 255),
                        //   borderRadius: BorderRadius.circular(6),
                        // ),
                        child: Text(
                          d.offer,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Color.fromARGB(255, 14, 68, 184),
                            fontWeight: FontWeight.w600,
                            
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // const SizedBox(height: 10),

                      // Distance + type — starts at same left edge as name
                      Row(
                        children: [
                          Text(
                            d.distance,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color.fromARGB(255, 119, 120, 123),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          _Chip(label: d.type),
                        ],
                      ),
                    ],
                  ),
                ),
                ),
              ),
            ],
          ),
          ),
        ),
      ),
    );
  }
}

// ── Small type label chip ────────────────────────────────────────────────────
class _Chip extends StatelessWidget {
  final String label;
  const _Chip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF2A2A3A)
              : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Horizontal nearby-shop chip card (used in home screen GPS row)
// ─────────────────────────────────────────────────────────────────────────────
class _NearbyShopChip extends StatelessWidget {
  final ShopItem shop;
  const _NearbyShopChip({required this.shop});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/shop-detail', extra: shop),
      child: Container(
        width: 168,
        margin: const EdgeInsets.only(right: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.07),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
              child: SizedBox(
                height: 96,
                width: double.infinity,
                child: shop.imageData != null && shop.imageData!.isNotEmpty
                    ? Image.memory(
                        base64Decode(shop.imageData!),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _fallback(shop),
                      )
                    : _fallback(shop),
              ),
            ),
            // Info
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(shop.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Color(0xFF111827))),
                  const SizedBox(height: 3),
                  Text(
                    shop.distance.isNotEmpty
                        ? shop.distance
                        : shop.location.split(',').first,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF6B7280)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fallback(ShopItem s) => Container(
        color: s.fallbackColor,
        alignment: Alignment.center,
        child: Icon(s.fallbackIcon, color: Colors.grey.shade400, size: 32),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Reelz Ad Dialog — shown randomly on the home screen
// ─────────────────────────────────────────────────────────────────────────────

/// Full-screen Reelz ad overlay — covers the entire screen like an
/// Instagram/TikTok interstitial. ✕ button is immediately visible (no delay).
class _ReelzAdDialog extends StatelessWidget {
  final ReelItem reel;
  final VoidCallback onClose;
  final VoidCallback onWatch;

  const _ReelzAdDialog({
    required this.reel,
    required this.onClose,
    required this.onWatch,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ── Full-screen thumbnail ──────────────────────────────────────
          GestureDetector(
            onTap: onWatch,
            child: reel.thumbnailUrl.isNotEmpty
                ? Image.network(
                    reel.thumbnailUrl,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    errorBuilder: (_, __, ___) => Container(
                      color: const Color(0xFF0F172A),
                      child: const Center(
                        child: Icon(Icons.movie_creation_rounded,
                            color: Colors.white24, size: 80),
                      ),
                    ),
                  )
                : Container(
                    color: const Color(0xFF0F172A),
                    child: const Center(
                      child: Icon(Icons.movie_creation_rounded,
                          color: Colors.white24, size: 80),
                    ),
                  ),
          ),

          // ── Gradient: dark at top & bottom ────────────────────────────
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.55),
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black.withOpacity(0.80),
                  ],
                  stops: const [0.0, 0.25, 0.60, 1.0],
                ),
              ),
            ),
          ),

          // ── Top bar: "Promo Reelz" badge  +  ✕ close ─────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    // Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAB308),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.movie_creation_rounded,
                              color: Colors.white, size: 14),
                          SizedBox(width: 5),
                          Text(
                            'Ad',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Spacer(),

                    // ✕ Close — immediately visible, no delay
                    GestureDetector(
                      onTap: onClose,
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: Colors.white38, width: 1),
                        ),
                        child: const Icon(Icons.close_rounded,
                            color: Colors.white, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Centre play button ─────────────────────────────────────────
          Center(
            child: GestureDetector(
              onTap: onWatch,
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.20),
                  shape: BoxShape.circle,
                  border:
                      Border.all(color: Colors.white70, width: 2),
                ),
                child: const Icon(Icons.play_arrow_rounded,
                    color: Colors.white, size: 44),
              ),
            ),
          ),

          // ── Bottom info + action buttons ───────────────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding:
                    const EdgeInsets.fromLTRB(20, 0, 20, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Shop name
                    if (reel.shopName.isNotEmpty)
                      Text(
                        reel.shopName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          shadows: [
                            Shadow(
                                color: Colors.black54, blurRadius: 8)
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),

                    if (reel.shopLocation.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.location_on_rounded,
                              color: Colors.white70, size: 14),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(
                              reel.shopLocation,
                              style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],

                    if (reel.offer.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: Colors.white30, width: 0.8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.local_offer_rounded,
                                color: Color(0xFFFBBF24), size: 14),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                reel.offer,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),

                    // Action buttons row
                    Row(
                      children: [
                        // Skip
                        Expanded(
                          child: OutlinedButton(
                            onPressed: onClose,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(
                                  color: Colors.white38, width: 1.5),
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(28)),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 14),
                            ),
                            child: const Text('Skip',
                                style: TextStyle(fontSize: 15)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Watch Reel
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            onPressed: onWatch,
                            icon: const Icon(
                                Icons.play_circle_filled_rounded,
                                size: 20),
                            label: const Text('Watch Reel',
                                style: TextStyle(fontSize: 15)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  const Color(0xFF2563EB),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(28)),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 14),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared cooldown timestamp (top-level so it survives widget rebuilds)
// ─────────────────────────────────────────────────────────────────────────────
DateTime? _reelzAdLastShownAt;

/// Show a reelz ad immediately — e.g. after a bill scan.
/// Respects the same 5-minute cooldown as the dashboard auto-ad.
Future<void> showReelzAdIfReady(BuildContext context) async {
  if (_reelzAdLastShownAt != null &&
      DateTime.now().difference(_reelzAdLastShownAt!) <
          const Duration(minutes: 5)) return;

  final reels = await ReelService.instance.fetchReels();
  if (reels.isEmpty || !context.mounted) return;

  _reelzAdLastShownAt = DateTime.now();
  final reel = reels[Random().nextInt(reels.length)];

  showGeneralDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black,
    transitionDuration: const Duration(milliseconds: 350),
    transitionBuilder: (_, anim, __, child) => FadeTransition(
      opacity: CurvedAnimation(parent: anim, curve: Curves.easeIn),
      child: child,
    ),
    pageBuilder: (ctx, _, __) => _ReelzAdDialog(
      reel: reel,
      onClose: () => Navigator.of(ctx).pop(),
      onWatch: () {
        Navigator.of(ctx).pop();
        context.push('/reelz');
      },
    ),
  );
}
