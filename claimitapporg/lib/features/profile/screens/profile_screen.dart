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

                  // ── Location ──────────────────────────────────────────────
                  // Expanded takes all remaining space between logo and icons,
                  // so the full location name is always visible.
                  Expanded(
                    child: GestureDetector(
                      onTap: () => context.push('/location'),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.max,
                        children: [
                          // Flexible(
                          //   child: Text(
                          //     context.select<AuthProvider, String>(
                          //       (a) => a.user?.location?.isNotEmpty == true
                          //           ? a.user!.location!
                          //           : 'Select Area',
                          //     ),
                          //     maxLines: 1,
                          //     overflow: TextOverflow.ellipsis,
                          //     style: TextStyle(
                          //       fontSize: 15,
                          //       fontWeight: FontWeight.w600,
                          //       color: Theme.of(context).colorScheme.onSurface,
                          //     ),
                          //   ),
                          // ),
                          // Icon(
                          //   Icons.keyboard_arrow_down_rounded,
                          //   size: 28,
                          //   color: Theme.of(context).colorScheme.onSurface,
                          // ),
                        ],
                      ),
                    ),
                  ),

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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
              // Location pill — wrapped in Flexible so the outer Row with
              // Spacer gives this child bounded width (avoids Flexible(Text)
              // receiving maxWidth=Infinity which causes a RenderFlex crash).
              Flexible(
                child: GestureDetector(
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
                        Flexible(
                          child: Text(
                            user?.location ?? 'Set Location',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF374151),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
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

          // ── Two stat cards: Cashback Wallet + Reward Points ───────────────
          Row(
            children: [
              Expanded(
                child: _RewardCard(
                  symbol: '₹',
                  value: bill.cashbackWallet.toStringAsFixed(0),
                  label: 'Cashback Wallet',
                  labelColor: const Color(0xFF2563EB),
                  accentColor: const Color(0xFF2563EB),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _RewardCard(
                  symbol: '🪙',
                  value: bill.currentPoints.toString(),
                  label: 'Reward Points',
                  labelColor: const Color(0xFFD97706),
                  accentColor: const Color(0xFFD97706),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // ── Lifetime cashback row ─────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.receipt_long_rounded,
                    size: 18, color: Color(0xFF2563EB)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Lifetime Cashback Earned: ₹${bill.lifetimeCashback.toStringAsFixed(0)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2563EB),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // ── Transfer to Bank button (min ₹100) ───────────────────────────
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              onPressed: bill.cashbackWallet >= 100
                  ? () => _showTransferSheet(context, bill)
                  : null,
              icon: const Icon(Icons.account_balance_rounded, size: 18),
              label: Text(
                bill.cashbackWallet >= 100
                    ? 'Transfer ₹${bill.cashbackWallet.toStringAsFixed(0)} to Bank'
                    : bill.cashbackWallet > 0
                        ? 'Need ₹${(100 - bill.cashbackWallet).toStringAsFixed(0)} more to Transfer'
                        : 'No Cashback to Transfer',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFFD1D5DB),
                disabledForegroundColor: const Color(0xFF9CA3AF),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showTransferSheet(BuildContext context, BillRewardProvider bill) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _TransferToBank(
        availableBalance: bill.cashbackWallet,
        provider: bill,
      ),
    );
  }
}

class _RewardCard extends StatelessWidget {
  final String symbol;
  final String value;
  final String label;
  final Color labelColor;
  final Color accentColor;

  const _RewardCard({
    required this.symbol,
    required this.value,
    required this.label,
    required this.labelColor,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accentColor.withOpacity(0.2)),
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
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: labelColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Transfer to Bank bottom sheet
// ─────────────────────────────────────────────────────────────────────────────
class _TransferToBank extends StatefulWidget {
  final double availableBalance;
  final BillRewardProvider provider;

  const _TransferToBank({
    required this.availableBalance,
    required this.provider,
  });

  @override
  State<_TransferToBank> createState() => _TransferToBankState();
}

class _TransferToBankState extends State<_TransferToBank> {
  final _upiCtrl = TextEditingController();
  final _amtCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _amtCtrl.text = widget.availableBalance.toStringAsFixed(0);
  }

  @override
  void dispose() {
    _upiCtrl.dispose();
    _amtCtrl.dispose();
    super.dispose();
  }

  Future<void> _transfer() async {
    final upi = _upiCtrl.text.trim();
    final amount = double.tryParse(_amtCtrl.text.trim()) ?? 0;

    if (upi.isEmpty) {
      setState(() => _error = 'Please enter your UPI ID or account number');
      return;
    }
    if (amount < 100) {
      setState(() => _error = 'Minimum transfer amount is ₹100');
      return;
    }
    if (amount > widget.availableBalance) {
      setState(() => _error = 'Enter a valid amount (max ₹${widget.availableBalance.toStringAsFixed(0)})');
      return;
    }

    setState(() { _loading = true; _error = null; });
    final ok = await widget.provider.transferToBank(
      amount: amount,
      accountDetails: upi,
    );
    if (!mounted) return;
    setState(() => _loading = false);

    if (ok) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('₹${amount.toStringAsFixed(0)} transferred successfully!'),
          backgroundColor: const Color(0xFF2E7D32),
        ),
      );
    } else {
      setState(() => _error = 'Transfer failed. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFD1D5DB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          Row(
            children: [
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.account_balance_rounded,
                    color: Color(0xFF2563EB), size: 22),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Transfer to Bank',
                      style: TextStyle(
                          fontSize: 17, fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A1A))),
                  Text(
                    'Available: ₹${widget.availableBalance.toStringAsFixed(0)}',
                    style: const TextStyle(
                        fontSize: 13, color: Color(0xFF6B7280)),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Amount field
          Row(
            children: [
              const Text('Amount (₹)',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                      color: Color(0xFF374151))),
              const Spacer(),
              const Text('Min ₹100',
                  style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
            ],
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _amtCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              prefixText: '₹ ',
              hintText: '0',
              filled: true,
              fillColor: const Color(0xFFF8FAFF),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                      color: Color(0xFF2563EB), width: 2)),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 14),
            ),
          ),

          const SizedBox(height: 14),

          // UPI / Account field
          const Text('UPI ID / Account Number',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                  color: Color(0xFF374151))),
          const SizedBox(height: 6),
          TextField(
            controller: _upiCtrl,
            decoration: InputDecoration(
              hintText: 'e.g. name@upi or account number',
              hintStyle: const TextStyle(
                  fontSize: 13, color: Color(0xFFBDBDBD)),
              filled: true,
              fillColor: const Color(0xFFF8FAFF),
              prefixIcon: const Icon(Icons.account_circle_outlined,
                  color: Color(0xFF9CA3AF)),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                      color: Color(0xFF2563EB), width: 2)),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 14),
            ),
          ),

          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!,
                style: const TextStyle(fontSize: 12, color: Colors.red)),
          ],

          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _loading ? null : _transfer,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: _loading
                  ? const SizedBox(width: 22, height: 22,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5))
                  : const Text('Confirm Transfer',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold)),
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
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: Text(shop.location,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
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
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
          if (deal.offer.isNotEmpty)
            Text(deal.offer,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          subtitle: Text(
            '$dateStr | $timeStr',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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
