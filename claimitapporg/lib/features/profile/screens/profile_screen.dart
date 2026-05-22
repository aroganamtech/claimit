import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../bill_reader/providers/bill_reward_provider.dart';
import '../providers/profile_provider.dart';
import '../../../core/theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ProfileScreen — redesigned to match mockup
// ─────────────────────────────────────────────────────────────────────────────
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProfileProvider>().fetchAll();
    });
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  PreferredSizeWidget _buildAppBar() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(70),
      child: Builder(
        builder: (context) => Container(
          color: Theme.of(context).colorScheme.surface,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  // ── Logo ──────────────────────────────────────────────────
                  Image.asset(
                    'assets/images/home_main_logo.png',
                    height: 38,
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

                  // ── Location ──────────────────────────────────────────────
                  GestureDetector(
                    onTap: () => context.push('/location'),
                    child: Row(
                      children: [
                        Text(
                          context.select<AuthProvider, String>(
                            (a) => a.user?.location?.isNotEmpty == true
                                ? a.user!.location!
                                : 'Select Area',
                          ),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 28,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ],
                    ),
                  ),

                  const Spacer(),

                  // ── Search ────────────────────────────────────────────────
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFE5E7EB)),
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

                  // ── Notifications ─────────────────────────────────────────
                  GestureDetector(
                    onTap: () => context.push('/notifications'),
                    child: Icon(
                      Icons.notifications_none_rounded,
                      size: 26,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: NestedScrollView(
        headerSliverBuilder: (ctx, _) => [
          SliverToBoxAdapter(child: _ProfileCard()),
          SliverToBoxAdapter(child: _RewardsSection()),
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabBarDelegate(_tab),
          ),
        ],
        body: TabBarView(
          controller: _tab,
          children: const [
            _FavouritesTab(),
            _HistoryTab(),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Profile header card
// ─────────────────────────────────────────────────────────────────────────────
class _ProfileCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;

    final initials = (user?.fullName.isNotEmpty == true)
        ? user!.fullName.trim()[0].toUpperCase()
        : 'U';
    final displayPhone = (user?.phone.isNotEmpty == true)
        ? '+91 ${user!.phone}'
        : null;

    return Container(
      color: Theme.of(context).colorScheme.surface,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Avatar + name/contact ──────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Avatar
              CircleAvatar(
                radius: 38,
                backgroundColor: const Color(0xFFE8EFF8),
                backgroundImage: (user?.avatarUrl != null)
                    ? NetworkImage(
                        '${context.read<AuthProvider>().user?.avatarUrl}')
                    : null,
                child: (user?.avatarUrl == null)
                    ? Text(
                        initials,
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2563EB),
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 14),
              // Name / email / phone
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user?.fullName ?? 'User',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    if (user?.email?.isNotEmpty == true) ...[
                      const SizedBox(height: 2),
                      Text(
                        user!.email!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                    if (displayPhone != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        displayPhone,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // ── Location chip + action icons ───────────────────────────────────
          Row(
            children: [
              // Location pill
              GestureDetector(
                onTap: () => context.push('/location'),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFD1D5DB)),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.location_on_outlined,
                          size: 26, color: Color(0xFF2563EB)),
                      const SizedBox(width: 4),
                      Text(
                        user?.location ?? 'Set Location',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF374151),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const Spacer(),

              // Edit icon
              _IconBtn(
                icon: Icons.edit_outlined,
                onTap: () => context.push('/profile/edit'),
              ),
              const SizedBox(width: 8),
              // Settings icon
              _IconBtn(
                icon: Icons.settings_outlined,
                onTap: () => context.push('/settings'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _IconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: const Color(0xFF2563EB).withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 18, color: const Color(0xFF2563EB)),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Rewards summary section
// ─────────────────────────────────────────────────────────────────────────────
class _RewardsSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final bill = context.watch<BillRewardProvider>();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Rewards',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _RewardCard(
                  symbol: '₹',
                  value: _fmt(bill.lifetimeCashback.toInt()),
                  label: 'Earned',
                  valueColor: const Color(0xFF1A1A2E),
                  labelColor: const Color(0xFF2563EB),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _RewardCard(
                  symbol: '🪙',
                  value: bill.currentPoints.toString(),
                  label: 'Redeemed',
                  valueColor: const Color(0xFF1A1A2E),
                  labelColor: const Color(0xFF6B7280),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _fmt(int n) {
    if (n >= 1000) {
      final k = n / 1000;
      return '${k == k.roundToDouble() ? k.toInt() : k.toStringAsFixed(1)},${(n % 1000).toString().padLeft(3, '0')}';
    }
    return n.toString();
  }
}

class _RewardCard extends StatelessWidget {
  final String symbol;
  final String value;
  final String label;
  final Color valueColor;
  final Color labelColor;

  const _RewardCard({
    required this.symbol,
    required this.value,
    required this.label,
    required this.valueColor,
    required this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$symbol $value',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: labelColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sticky tab bar delegate
// ─────────────────────────────────────────────────────────────────────────────
class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabController controller;
  const _TabBarDelegate(this.controller);

  @override
  double get minExtent => 56;
  @override
  double get maxExtent => 56;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF2A2A3A)
              : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(10),
        ),
        child: TabBar(
          controller: controller,
          indicator: BoxDecoration(
            color: const Color(0xFF2563EB),
            borderRadius: BorderRadius.circular(8),
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          labelColor: Colors.white,
          unselectedLabelColor: const Color(0xFF6B7280),
          labelStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: const TextStyle(fontSize: 13),
          tabs: const [
            Tab(text: 'My Favourites'),
            Tab(text: 'My History'),
          ],
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _TabBarDelegate oldDelegate) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// My Favourites tab
// ─────────────────────────────────────────────────────────────────────────────
class _FavouritesTab extends StatelessWidget {
  const _FavouritesTab();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProfileProvider>();
    final loading = provider.loadingFavourites || provider.loadingDealFavourites;
    final totalItems = provider.favourites.length + provider.dealFavourites.length;

    if (loading && totalItems == 0) {
      return const Center(child: CircularProgressIndicator());
    }

    if (totalItems == 0) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.favorite_border_rounded,
                size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            const Text('No favourites yet',
                style: TextStyle(fontSize: 16, color: Color(0xFF6B7280))),
            const SizedBox(height: 4),
            const Text('Tap ❤️ on any shop or deal to add it here',
                style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF))),
          ],
        ),
      );
    }

    // Build a unified list: shops first, then deals
    final shopCount = provider.favourites.length;
    final dealCount = provider.dealFavourites.length;
    final itemCount = shopCount + dealCount;

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: itemCount,
      separatorBuilder: (_, __) =>
          const Divider(height: 1, indent: 72, endIndent: 16),
      itemBuilder: (ctx, i) {
        if (i < shopCount) {
          return _FavShopTile(shop: provider.favourites[i]);
        }
        return _FavDealTile(deal: provider.dealFavourites[i - shopCount]);
      },
    );
  }
}

// ── Favourite shop tile ───────────────────────────────────────────────────────
class _FavShopTile extends StatelessWidget {
  final FavouriteShop shop;
  const _FavShopTile({required this.shop});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<ProfileProvider>();

    Widget avatar;
    if (shop.imageData != null && shop.imageData!.isNotEmpty) {
      avatar = CircleAvatar(
        radius: 26,
        backgroundImage: MemoryImage(base64Decode(shop.imageData!)),
      );
    } else {
      avatar = CircleAvatar(
        radius: 26,
        backgroundColor: const Color(0xFF2563EB).withOpacity(0.12),
        child: Text(
          shop.name.isNotEmpty ? shop.name[0].toUpperCase() : 'S',
          style: const TextStyle(
              fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
        ),
      );
    }

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: avatar,
      title: Text(shop.name,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: Text(shop.location,
          style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
      trailing: GestureDetector(
        onTap: () => provider.toggleFavourite(
          shop.id,
          name: shop.name,
          location: shop.location,
          imageData: shop.imageData,
          discount: shop.discount,
          rating: shop.rating,
        ),
        child: const Icon(Icons.favorite_rounded,
            color: Colors.redAccent, size: 22),
      ),
    );
  }
}

// ── Favourite deal tile ───────────────────────────────────────────────────────
class _FavDealTile extends StatelessWidget {
  final FavouriteDeal deal;
  const _FavDealTile({required this.deal});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<ProfileProvider>();

    Widget avatar;
    if (deal.imageUrl.isNotEmpty) {
      avatar = CircleAvatar(
        radius: 26,
        backgroundImage: CachedNetworkImageProvider(deal.imageUrl),
        onBackgroundImageError: (_, __) {},
      );
    } else {
      avatar = CircleAvatar(
        radius: 26,
        backgroundColor: const Color(0xFFEFF6FF),
        child: Text(
          deal.name.isNotEmpty ? deal.name[0].toUpperCase() : 'D',
          style: const TextStyle(
              fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
        ),
      );
    }

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: avatar,
      title: Row(
        children: [
          Expanded(
            child: Text(deal.name,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 14)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text('Deal',
                style: TextStyle(
                    fontSize: 10,
                    color: Color(0xFF2563EB),
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(deal.location,
              style:
                  const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
          if (deal.offer.isNotEmpty)
            Text(deal.offer,
                style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF2563EB),
                    fontWeight: FontWeight.w500)),
        ],
      ),
      isThreeLine: deal.offer.isNotEmpty,
      trailing: GestureDetector(
        onTap: () => provider.toggleDealFavourite(
          deal.id,
          name: deal.name,
          location: deal.location,
          imageUrl: deal.imageUrl,
          offer: deal.offer,
        ),
        child: const Icon(Icons.favorite_rounded,
            color: Colors.redAccent, size: 22),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// My History tab (bill scan history from BillRewardProvider)
// ─────────────────────────────────────────────────────────────────────────────
class _HistoryTab extends StatelessWidget {
  const _HistoryTab();

  @override
  Widget build(BuildContext context) {
    final history = context.watch<BillRewardProvider>().history;

    if (history.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long_outlined,
                size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            const Text(
              'No history yet',
              style: TextStyle(fontSize: 16, color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 4),
            const Text(
              'Scan a bill to start earning rewards',
              style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: history.length,
      separatorBuilder: (_, __) =>
          const Divider(height: 1, indent: 72, endIndent: 16),
      itemBuilder: (ctx, i) {
        final entry = history[i];
        final dateStr =
            '${entry.date.day} ${_month(entry.date.month)} ${entry.date.year}';
        final timeStr =
            '${entry.date.hour.toString().padLeft(2, '0')}:${entry.date.minute.toString().padLeft(2, '0')} ${entry.date.hour < 12 ? 'AM' : 'PM'}';

        return ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          leading: CircleAvatar(
            radius: 26,
            backgroundColor: entry.shopColor.withOpacity(0.15),
            child: Text(
              entry.shopName.isNotEmpty ? entry.shopName[0] : 'S',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: entry.shopColor,
                fontSize: 18,
              ),
            ),
          ),
          title: Text(
            entry.shopName,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          subtitle: Text(
            '$dateStr | $timeStr',
            style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${entry.totalBill.toInt()} Rs',
                style: const TextStyle(
                  color: Color(0xFF2563EB),
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${entry.rewardPoints} ★',
                style: const TextStyle(
                  color: Color(0xFFD97706),
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static String _month(int m) {
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[m];
  }
}
