import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../auth/providers/auth_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Data model
// ─────────────────────────────────────────────────────────────────────────────

enum _NotifTab { all, alert, offer, reminder }

class _NotifItem {
  final String id;
  final String title;
  final String subtitle;
  final String time;
  final _NotifTab tab; // alert | offer | reminder
  final IconData icon;
  final Color iconColor;
  bool isRead;

  _NotifItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.time,
    required this.tab,
    required this.icon,
    required this.iconColor,
    this.isRead = false,
  });
}

List<_NotifItem> _buildDummyNotifs() => [
      _NotifItem(
        id: '1',
        title: 'Flash Sale Alert 🔥',
        subtitle: 'Reliance Trends is offering 50% OFF today only. Hurry — ends at midnight!',
        time: '2 min ago',
        tab: _NotifTab.offer,
        icon: Icons.local_fire_department_rounded,
        iconColor: const Color(0xFFEF4444),
      ),
      _NotifItem(
        id: '2',
        title: 'Reward Points Added',
        subtitle: 'You earned 120 points from your last bill scan at Big Bazaar. Keep scanning!',
        time: '18 min ago',
        tab: _NotifTab.offer,
        icon: Icons.stars_rounded,
        iconColor: const Color(0xFFF59E0B),
      ),
      _NotifItem(
        id: '3',
        title: 'Scan Bill Reminder',
        subtitle: 'Did you shop recently? Don\'t forget to scan your bill to earn reward points.',
        time: '1 hr ago',
        tab: _NotifTab.reminder,
        icon: Icons.document_scanner_outlined,
        iconColor: const Color(0xFF2563EB),
      ),
      _NotifItem(
        id: '4',
        title: 'New Shop Nearby',
        subtitle: 'Sathya Agencies just joined claimit. Visit and earn rewards on every purchase!',
        time: '3 hrs ago',
        tab: _NotifTab.alert,
        icon: Icons.store_rounded,
        iconColor: const Color(0xFF10B981),
      ),
      _NotifItem(
        id: '5',
        title: 'Exclusive Offer for You',
        subtitle: 'Lakme Salon is offering an exclusive 30% discount for claimit members this week.',
        time: '5 hrs ago',
        tab: _NotifTab.offer,
        icon: Icons.local_offer_rounded,
        iconColor: const Color(0xFF8B5CF6),
        isRead: true,
      ),
      _NotifItem(
        id: '6',
        title: 'Points Expiring Soon',
        subtitle: '200 reward points will expire in 3 days. Redeem them before they\'re gone!',
        time: 'Yesterday',
        tab: _NotifTab.reminder,
        icon: Icons.hourglass_bottom_rounded,
        iconColor: const Color(0xFFF97316),
      ),
      _NotifItem(
        id: '7',
        title: 'Friend Joined claimit',
        subtitle: 'Your friend Priya joined claimit using your referral. You both earned 50 bonus points!',
        time: 'Yesterday',
        tab: _NotifTab.reminder,
        icon: Icons.people_alt_rounded,
        iconColor: const Color(0xFF2563EB),
        isRead: true,
      ),
      _NotifItem(
        id: '8',
        title: 'App Update Available',
        subtitle: 'A new version of claimit (v2.1) is available. Update now for the best experience.',
        time: '2 days ago',
        tab: _NotifTab.alert,
        icon: Icons.system_update_alt_rounded,
        iconColor: const Color(0xFF6B7280),
        isRead: true,
      ),
      _NotifItem(
        id: '9',
        title: 'Delivery Update',
        subtitle: 'Your redeemed item has been dispatched. Expected delivery: 2–3 business days.',
        time: '3 days ago',
        tab: _NotifTab.alert,
        icon: Icons.local_shipping_rounded,
        iconColor: const Color(0xFF2563EB),
        isRead: true,
      ),
      _NotifItem(
        id: '10',
        title: 'Weekly Rewards Summary',
        subtitle: 'This week you earned 340 points across 5 stores. You\'re on a great streak!',
        time: '5 days ago',
        tab: _NotifTab.offer,
        icon: Icons.bar_chart_rounded,
        iconColor: const Color(0xFF10B981),
        isRead: true,
      ),
    ];

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  _NotifTab _activeTab = _NotifTab.all;
  final List<_NotifItem> _notifs = _buildDummyNotifs();

  List<_NotifItem> get _filtered {
    if (_activeTab == _NotifTab.all) return _notifs;
    return _notifs.where((n) => n.tab == _activeTab).toList();
  }

  int get _unreadCount => _notifs.where((n) => !n.isRead).length;

  void _markAllRead() {
    setState(() {
      for (final n in _notifs) {
        n.isRead = true;
      }
    });
  }

  void _markRead(String id) {
    setState(() {
      final idx = _notifs.indexWhere((n) => n.id == id);
      if (idx != -1) _notifs[idx].isRead = true;
    });
  }

  void _dismiss(String id) {
    setState(() {
      _notifs.removeWhere((n) => n.id == id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // ── Tab pills ──────────────────────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Row(
              children: [
                _TabBtn(
                  label: 'All',
                  active: _activeTab == _NotifTab.all,
                  onTap: () => setState(() => _activeTab = _NotifTab.all),
                ),
                const SizedBox(width: 8),
                _TabBtn(
                  label: 'Alert',
                  active: _activeTab == _NotifTab.alert,
                  onTap: () => setState(() => _activeTab = _NotifTab.alert),
                ),
                const SizedBox(width: 8),
                _TabBtn(
                  label: 'Offer',
                  active: _activeTab == _NotifTab.offer,
                  onTap: () => setState(() => _activeTab = _NotifTab.offer),
                ),
                const SizedBox(width: 8),
                _TabBtn(
                  label: 'Reminder',
                  active: _activeTab == _NotifTab.reminder,
                  onTap: () => setState(() => _activeTab = _NotifTab.reminder),
                ),
              ],
            ),
          ),

          // ── Mark all read bar ──────────────────────────────────────────
          if (_unreadCount > 0)
            Container(
              color: const Color(0xFFEFF6FF),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.mark_email_read_outlined,
                      size: 28, color: Color(0xFF2563EB)),
                  const SizedBox(width: 6),
                  Text(
                    '$_unreadCount unread notification${_unreadCount > 1 ? 's' : ''}',
                    style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF2563EB),
                        fontWeight: FontWeight.w500),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _markAllRead,
                    child: const Text(
                      'Mark all read',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF2563EB),
                        fontWeight: FontWeight.w700,
                        decoration: TextDecoration.underline,
                        decorationColor: Color(0xFF2563EB),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // ── List ──────────────────────────────────────────────────────
          Expanded(
            child: filtered.isEmpty
                ? _buildEmpty()
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                    itemCount: filtered.length,
                    itemBuilder: (context, i) {
                      final notif = filtered[i];
                      return _NotifCard(
                        key: ValueKey(notif.id),
                        notif: notif,
                        onTap: () => _markRead(notif.id),
                        onDismiss: () => _dismiss(notif.id),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final location = context.select<AuthProvider, String>(
      (a) => a.user?.location?.isNotEmpty == true
          ? a.user!.location!
          : 'Select Area',
    );

    return PreferredSize(
      preferredSize: const Size.fromHeight(112),
      child: Container(
        color: Colors.white,
        child: SafeArea(
          bottom: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Row 1: same as home dashboard appbar ───────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    // Logo icon + text
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
                    // Location
                    GestureDetector(
                      onTap: () => context.push('/location'),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              location,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.black,
                              ),
                            ),
                          ),
                          const SizedBox(width: 2),
                          const Icon(Icons.keyboard_arrow_down_rounded, size: 26),
                        ],
                      ),
                    ),
                    const Spacer(),
                    // Search icon
                    GestureDetector(
                      onTap: () => context.push('/search'),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: const Icon(
                          Icons.search,
                          size: 28,
                          color: Color(0xFF1565C0),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1, color: Color(0xFFF3F4F6)),

              // ── Row 2: back + title ────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 16, 10),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => context.go('/home'),
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(Icons.arrow_back_ios_new_rounded,
                            color: Color(0xFF1565C0), size: 18),
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Text(
                      'Notifications',
                      style: TextStyle(
                        color: Color(0xFF111827),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    // Unread badge
                    if (_unreadCount > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1565C0),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$_unreadCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    final labels = {
      _NotifTab.all: 'No notifications yet',
      _NotifTab.alert: 'No alert notifications',
      _NotifTab.offer: 'No offer notifications',
      _NotifTab.reminder: 'No reminders',
    };
    final sublabels = {
      _NotifTab.all: 'We\'ll notify you about offers, alerts and reminders.',
      _NotifTab.alert: 'System and delivery alerts will appear here.',
      _NotifTab.offer: 'Exclusive deals and cashback offers will appear here.',
      _NotifTab.reminder: 'Bill scan and reward reminders will appear here.',
    };

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.notifications_none_rounded,
                size: 44, color: Color(0xFF2563EB)),
          ),
          const SizedBox(height: 18),
          Text(
            labels[_activeTab]!,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              sublabels[_activeTab]!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF6B7280),
                height: 1.5,
              ),
            ),
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
  const _TabBtn({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF2563EB) : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: active ? Colors.white : const Color(0xFF6B7280),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Notification card
// ─────────────────────────────────────────────────────────────────────────────

class _NotifCard extends StatelessWidget {
  final _NotifItem notif;
  final VoidCallback onTap;
  final VoidCallback onDismiss;
  const _NotifCard({
    super.key,
    required this.notif,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(notif.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismiss(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete_outline_rounded, color: Colors.white, size: 24),
            SizedBox(height: 3),
            Text(
              'Delete',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: notif.isRead ? Colors.white : const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: notif.isRead
                  ? const Color(0xFFE5E7EB)
                  : const Color(0xFF2563EB).withOpacity(0.25),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon container — circular to match design
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: notif.iconColor.withOpacity(0.13),
                  shape: BoxShape.circle,
                ),
                child: Icon(notif.icon, color: notif.iconColor, size: 24),
              ),
              const SizedBox(width: 12),
              // Text content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            notif.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: notif.isRead
                                  ? FontWeight.w500
                                  : FontWeight.bold,
                              color: const Color(0xFF111827),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Unread blue dot
                        if (!notif.isRead)
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(top: 4),
                            decoration: const BoxDecoration(
                              color: Color(0xFF2563EB),
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notif.subtitle,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      notif.time,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF9CA3AF),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
