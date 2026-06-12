import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../bill_reader/models/bill_reward_model.dart';
import '../../bill_reader/providers/bill_reward_provider.dart';
import '../../deals/models/deal_model.dart';
import '../../deals/services/deal_service.dart';
import '../../notifications/providers/notification_provider.dart';
import '../../shops/screens/shop_list_screen.dart' show ShopItem;
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
      // Refresh auth user so presigned avatar URL is always fresh
      context.read<AuthProvider>().fetchUserProfile();
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
                  // Container(
                  //   width: 38,
                  //   height: 38,
                  //   decoration: BoxDecoration(
                  //     shape: BoxShape.circle,
                  //     border: Border.all(color: const Color(0xFFE5E7EB)),
                  //   ),
                  //   child: IconButton(
                  //     icon: Icon(
                  //       Icons.search,
                  //       size: 28,
                  //       color: Theme.of(context).colorScheme.primary,
                  //     ),
                  //     onPressed: () => context.push('/search'),
                  //     padding: EdgeInsets.zero,
                  //   ),
                  // ),

                  const SizedBox(width: 8),

                  // ── Notifications with unread dot ─────────────────────────
                  Consumer<NotificationProvider>(
                    builder: (context, notifProvider, _) {
                      final unread = notifProvider.unreadCount;
                      return GestureDetector(
                        onTap: () => context.push('/notifications'),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Icon(
                              unread > 0
                                  ? Icons.notifications_rounded
                                  : Icons.notifications_none_rounded,
                              size: 26,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            if (unread > 0)
                              Positioned(
                                top: -1,
                                right: -1,
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: RefreshIndicator(
        onRefresh: () => context.read<ProfileProvider>().fetchAll(),
        color: AppTheme.primaryColor,
        child: NestedScrollView(
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
                    ? CachedNetworkImageProvider(user!.avatarUrl!)
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
                child: GestureDetector(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => _CashbackWalletPage(bill: bill),
                    ),
                  ),
                  child: _RewardCard(
                    symbol: '₹',
                    value: bill.cashbackWallet.toStringAsFixed(0),
                    label: 'Cashback Wallet',
                    labelColor: const Color(0xFF2563EB),
                    accentColor: const Color(0xFF2563EB),
                  ),
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
            // child: Row(
            //   children: [
            //     const Icon(Icons.receipt_long_rounded,
            //         size: 18, color: Color(0xFF2563EB)),
            //     const SizedBox(width: 8),
            //     Expanded(
            //       child: Text(
            //         'Lifetime Cashback Earned: ₹${bill.lifetimeCashback.toStringAsFixed(0)}',
            //         maxLines: 1,
            //         overflow: TextOverflow.ellipsis,
            //         style: const TextStyle(
            //           fontSize: 13,
            //           fontWeight: FontWeight.w600,
            //           color: Color(0xFF2563EB),
            //         ),
            //       ),
            //     ),
            //   ],
            // ),
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
// My Favourites tab  (with scroll-triggered refresh loading)
// ─────────────────────────────────────────────────────────────────────────────
class _FavouritesTab extends StatefulWidget {
  const _FavouritesTab();
  @override
  State<_FavouritesTab> createState() => _FavouritesTabState();
}

class _FavouritesTabState extends State<_FavouritesTab> {
  final _scrollCtrl = ScrollController();
  bool _loadingMore = false;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_loadingMore) return;
    final pos = _scrollCtrl.position;
    if (pos.pixels >= pos.maxScrollExtent - 120) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore) return;
    setState(() => _loadingMore = true);
    await context.read<ProfileProvider>().fetchAll();
    if (mounted) setState(() => _loadingMore = false);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProfileProvider>();
    final loading = provider.loadingFavourites || provider.loadingDealFavourites;
    final totalItems = provider.favourites.length + provider.dealFavourites.length;

    if (loading && totalItems == 0) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF1565C0)));
    }

    if (totalItems == 0) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.favorite_border_rounded, size: 64, color: Colors.grey.shade300),
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

    final shopCount = provider.favourites.length;
    final dealCount = provider.dealFavourites.length;
    final itemCount = shopCount + dealCount + (_loadingMore ? 1 : 0);

    return ListView.separated(
      controller: _scrollCtrl,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: itemCount,
      separatorBuilder: (_, __) =>
          const Divider(height: 1, indent: 72, endIndent: 16),
      itemBuilder: (ctx, i) {
        if (i == shopCount + dealCount) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(child: CircularProgressIndicator(
                strokeWidth: 2, color: Color(0xFF1565C0))),
          );
        }
        if (i < shopCount) return _FavShopTile(shop: provider.favourites[i]);
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
    if (shop.imageUrl.isNotEmpty) {
      avatar = CircleAvatar(
        radius: 26,
        backgroundImage: CachedNetworkImageProvider(shop.imageUrl),
      );
    } else if (shop.imageData != null && shop.imageData!.isNotEmpty) {
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
      onTap: () => context.push('/shop-detail', extra: ShopItem(
        id: shop.id,
        name: shop.name,
        location: shop.location,
        categoryIds: const [],
        discount: shop.discount,
        rating: shop.rating,
        addedDaysAgo: 0,
        fallbackColor: const Color(0xFF2563EB),
        fallbackIcon: Icons.store_rounded,
        imageUrl: shop.imageUrl,
        imageData: shop.imageData,
      )),
      trailing: GestureDetector(
        onTap: () => provider.toggleFavourite(
          shop.id,
          name: shop.name,
          location: shop.location,
          imageUrl: shop.imageUrl,
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
class _FavDealTile extends StatefulWidget {
  final FavouriteDeal deal;
  const _FavDealTile({required this.deal});
  @override
  State<_FavDealTile> createState() => _FavDealTileState();
}

class _FavDealTileState extends State<_FavDealTile> {
  bool _loading = false;

  Future<void> _openDetail() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final dto = await DealService.instance.fetchDealById(widget.deal.id);
      if (!mounted) return;
      if (dto != null) {
        context.push('/deal-detail', extra: DealData(
          id: dto.id,
          name: dto.name,
          location: dto.location,
          offer: dto.offer,
          distance: dto.distance,
          type: dto.type,
          imageUrl: dto.imageUrl,
          imageData: dto.imageData,
          fallbackColor: const Color(0xFF2563EB),
          fallbackIcon: Icons.local_offer_rounded,
          description: dto.description,
          address: dto.address,
          phone: dto.phone,
          timing: dto.timing,
          rating: dto.rating,
          reviews: dto.reviews,
        ));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final deal = widget.deal;
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
              style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
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
      onTap: _openDetail,
      trailing: _loading
          ? const SizedBox(
              width: 22, height: 22,
              child: CircularProgressIndicator(strokeWidth: 2,
                  color: Color(0xFF2563EB)))
          : GestureDetector(
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
class _HistoryTab extends StatefulWidget {
  const _HistoryTab();
  @override
  State<_HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<_HistoryTab> {
  final _scrollCtrl = ScrollController();
  bool _loadingMore  = false;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_loadingMore) return;
    final pos = _scrollCtrl.position;
    if (pos.pixels >= pos.maxScrollExtent - 120) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore) return;
    setState(() => _loadingMore = true);
    // Refresh wallet + history from server
    await context.read<BillRewardProvider>().loadAll();
    if (mounted) setState(() => _loadingMore = false);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BillRewardProvider>();
    final history  = provider.history;

    if (!provider.walletLoaded && history.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF1565C0)));
    }

    if (history.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            const Text('No history yet',
                style: TextStyle(fontSize: 16, color: Color(0xFF6B7280))),
            const SizedBox(height: 4),
            const Text('Scan a bill to start earning rewards',
                style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF))),
          ],
        ),
      );
    }

    final itemCount = history.length + (_loadingMore ? 1 : 0);

    return ListView.separated(
      controller: _scrollCtrl,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: itemCount,
      separatorBuilder: (_, __) =>
          const Divider(height: 1, indent: 72, endIndent: 16),
      itemBuilder: (ctx, i) {
        // Loading spinner at the bottom
        if (i == history.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(child: CircularProgressIndicator(
                strokeWidth: 2, color: Color(0xFF1565C0))),
          );
        }
        final entry = history[i];
        final dateStr =
            '${entry.date.day} ${_month(entry.date.month)} ${entry.date.year}';
        final timeStr =
            '${entry.date.hour.toString().padLeft(2, '0')}:${entry.date.minute.toString().padLeft(2, '0')} ${entry.date.hour < 12 ? 'AM' : 'PM'}';

        return ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          onTap: () => _showBillDetail(ctx, entry),
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

  void _showBillDetail(BuildContext context, BillRewardEntry entry) {
    final dateStr =
        '${entry.date.day} ${_month(entry.date.month)} ${entry.date.year}';
    final timeStr =
        '${entry.date.hour.toString().padLeft(2, '0')}:${entry.date.minute.toString().padLeft(2, '0')} ${entry.date.hour < 12 ? 'AM' : 'PM'}';

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: entry.shopColor.withOpacity(0.15),
                child: Text(
                  entry.shopName.isNotEmpty ? entry.shopName[0] : 'S',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: entry.shopColor,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(entry.shopName,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w700)),
              ),
            ]),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 12),
            _billRow('Scan Date', '$dateStr  $timeStr'),
            if (entry.billDate != null)
              _billRow('Bill Date',
                  '${entry.billDate!.day} ${_month(entry.billDate!.month)} ${entry.billDate!.year}'),
            if (entry.billNumber != null && entry.billNumber!.isNotEmpty)
              _billRow('Bill No.', entry.billNumber!),
            const SizedBox(height: 8),
            const Divider(),
            const SizedBox(height: 8),
            _billRow('Total Bill', '₹ ${entry.totalBill.toStringAsFixed(2)}',
                valueStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2563EB))),
            _billRow('Cashback Earned', '₹ ${entry.cashback.toStringAsFixed(2)}',
                valueStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF16A34A))),
            _billRow('Reward Points', '${entry.rewardPoints} pts ★',
                valueStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFD97706))),
          ],
        ),
      ),
    );
  }

  Widget _billRow(String label, String value, {TextStyle? valueStyle}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 13, color: Color(0xFF6B7280))),
            Text(value,
                style: valueStyle ??
                    const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        ),
      );

  static String _month(int m) {
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[m];
  }
}
// ─────────────────────────────────────────────────────────────────────────────
// Cashback Wallet Detail Page
// ─────────────────────────────────────────────────────────────────────────────
class _CashbackWalletPage extends StatelessWidget {
  final BillRewardProvider bill;
  const _CashbackWalletPage({required this.bill});

  @override
  Widget build(BuildContext context) {
    final history = bill.history;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Color(0xFF1565C0), size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Cashback Wallet',
          style: TextStyle(
            color: Color(0xFF111827),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Balance card ──────────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1565C0), Color(0xFF2563EB)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2563EB).withOpacity(0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Available Balance',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '₹${bill.cashbackWallet.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(color: Colors.white24),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _WalletStat(
                      label: 'Lifetime Earned',
                      value: '₹${bill.lifetimeCashback.toStringAsFixed(2)}',
                    ),
                    _WalletStat(
                      label: 'Total Scans',
                      value: '${history.length}',
                    ),
                    _WalletStat(
                      label: 'Reward Points',
                      value: '${bill.currentPoints} ★',
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── Transfer to bank ──────────────────────────────────────────────
          if (bill.cashbackWallet >= 100)
            ElevatedButton.icon(
              onPressed: () {
                // Show transfer sheet (reuse existing logic)
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.white,
                  shape: const RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  builder: (_) => _TransferToBank(
                    availableBalance: bill.cashbackWallet,
                    provider: bill,
                  ),
                );
              },
              icon: const Icon(Icons.account_balance_rounded, size: 18),
              label: Text(
                  'Transfer ₹${bill.cashbackWallet.toStringAsFixed(0)} to Bank'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            )
          else if (bill.cashbackWallet > 0)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFF59E0B)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded,
                      color: Color(0xFFD97706), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Need ₹${(100 - bill.cashbackWallet).toStringAsFixed(0)} more to transfer to bank',
                      style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF92400E),
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 24),

          // ── Transactions header ───────────────────────────────────────────
          Row(
            children: [
              const Icon(Icons.receipt_long_rounded,
                  size: 20, color: Color(0xFF1565C0)),
              const SizedBox(width: 8),
              const Text(
                'Transactions',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF111827),
                ),
              ),
              const Spacer(),
              Text(
                '${history.length} bills',
                style: const TextStyle(
                    fontSize: 12, color: Color(0xFF9CA3AF)),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // ── Transaction list ──────────────────────────────────────────────
          if (history.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text(
                  'No transactions yet.\nScan a bill to earn cashback!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 14, color: Color(0xFF9CA3AF), height: 1.6),
                ),
              ),
            )
          else
            ...history.map((entry) => _TransactionTile(entry: entry)),
        ],
      ),
    );
  }
}

// ── Small stat widget inside the wallet card ──────────────────────────────────
class _WalletStat extends StatelessWidget {
  final String label;
  final String value;
  const _WalletStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label,
            style:
                const TextStyle(color: Colors.white60, fontSize: 11)),
      ],
    );
  }
}

// ── Single transaction row ────────────────────────────────────────────────────
class _TransactionTile extends StatelessWidget {
  final dynamic entry; // BillRewardEntry
  const _TransactionTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final date = entry.date as DateTime;
    final months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final dateStr =
        '${date.day} ${months[date.month]} ${date.year}';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.receipt_rounded,
                color: Color(0xFF2563EB), size: 22),
          ),
          const SizedBox(width: 12),
          // Shop + date
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.shopName as String,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111827),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  dateStr,
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF9CA3AF)),
                ),
              ],
            ),
          ),
          // Cashback + bill amount
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '+₹${(entry.cashback as double).toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF059669),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Bill: ₹${(entry.totalBill as double).toStringAsFixed(0)}',
                style: const TextStyle(
                    fontSize: 11, color: Color(0xFF9CA3AF)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
