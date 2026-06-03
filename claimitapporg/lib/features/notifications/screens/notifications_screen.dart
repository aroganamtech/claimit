import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../auth/providers/auth_provider.dart';
import '../providers/notification_provider.dart';
import '../models/notification_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Helpers — map notification type → icon + colour + tab
// ─────────────────────────────────────────────────────────────────────────────

enum _NotifTab { all, alert, offer, reminder }

class _NotifMeta {
  final IconData icon;
  final Color    iconColor;
  final _NotifTab tab;
  const _NotifMeta(this.icon, this.iconColor, this.tab);
}

_NotifMeta _metaFor(String type) {
  switch (type) {
    case 'bill_review_approved':
      return const _NotifMeta(Icons.receipt_long_rounded,   Color(0xFF2E7D32), _NotifTab.offer);
    case 'bill_review_rejected':
      return const _NotifMeta(Icons.receipt_long_rounded,   Color(0xFFC62828), _NotifTab.alert);
    case 'claim_approved':
    case 'claim_update':
      return const _NotifMeta(Icons.check_circle_rounded,   Color(0xFF2E7D32), _NotifTab.alert);
    case 'claim_rejected':
      return const _NotifMeta(Icons.cancel_rounded,         Color(0xFFC62828), _NotifTab.alert);
    case 'reward':
    case 'points':
      return const _NotifMeta(Icons.stars_rounded,          Color(0xFFF59E0B), _NotifTab.offer);
    case 'offer':
    case 'deal':
      return const _NotifMeta(Icons.local_offer_rounded,    Color(0xFF8B5CF6), _NotifTab.offer);
    case 'shop':
      return const _NotifMeta(Icons.store_rounded,          Color(0xFF10B981), _NotifTab.alert);
    case 'reminder':
      return const _NotifMeta(Icons.document_scanner_outlined, Color(0xFF2563EB), _NotifTab.reminder);
    case 'expiry':
      return const _NotifMeta(Icons.hourglass_bottom_rounded, Color(0xFFF97316), _NotifTab.reminder);
    case 'referral':
      return const _NotifMeta(Icons.people_alt_rounded,     Color(0xFF2563EB), _NotifTab.reminder);
    case 'delivery':
      return const _NotifMeta(Icons.local_shipping_rounded, Color(0xFF2563EB), _NotifTab.alert);
    case 'system':
    case 'update':
      return const _NotifMeta(Icons.system_update_alt_rounded, Color(0xFF6B7280), _NotifTab.alert);
    case 'flash_sale':
      return const _NotifMeta(Icons.local_fire_department_rounded, Color(0xFFEF4444), _NotifTab.offer);
    default:
      return const _NotifMeta(Icons.notifications_rounded, Color(0xFF2563EB), _NotifTab.alert);
  }
}

String _timeAgo(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inSeconds < 60)  return 'Just now';
  if (diff.inMinutes < 60)  return '${diff.inMinutes} min ago';
  if (diff.inHours   < 24)  return '${diff.inHours} hr ago';
  if (diff.inDays    < 7)   return '${diff.inDays} day${diff.inDays > 1 ? 's' : ''} ago';
  return DateFormat('d MMM').format(dt);
}

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationProvider>().fetchNotifications();
    });
  }

  List<NotificationModel> _filtered(List<NotificationModel> all) {
    if (_activeTab == _NotifTab.all) return all;
    return all.where((n) => _metaFor(n.type).tab == _activeTab).toList();
  }

  void _markRead(NotificationModel n) {
    if (!n.isRead) {
      context.read<NotificationProvider>().markAsRead(n.id);
    }
    // Navigate to wallet for bill review notifications
    if (n.isBillReview) {
      context.push('/bill-reader/wallet');
    }
  }

  void _markAllRead() {
    context.read<NotificationProvider>().markAllAsRead();
  }

  @override
  Widget build(BuildContext context) {
    // Read location here (in build) so context.select is valid
    final location = context.select<AuthProvider, String>(
      (a) => a.user?.location?.isNotEmpty == true
          ? a.user!.location!
          : 'Select Area',
    );

    return Consumer<NotificationProvider>(
      builder: (context, provider, _) {
        final allNotifs = provider.notifications;
        final filtered  = _filtered(allNotifs);
        final unread    = allNotifs.where((n) => !n.isRead).length;

        return Scaffold(
          backgroundColor: const Color(0xFFF9FAFB),
          appBar: _buildAppBar(unread, location),
          body: Column(
            children: [
              // ── Tab pills ────────────────────────────────────────────────
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                child: Row(
                  children: [
                    _TabBtn(label: 'All',      active: _activeTab == _NotifTab.all,      onTap: () => setState(() => _activeTab = _NotifTab.all)),
                    const SizedBox(width: 8),
                    _TabBtn(label: 'Alert',    active: _activeTab == _NotifTab.alert,    onTap: () => setState(() => _activeTab = _NotifTab.alert)),
                    const SizedBox(width: 8),
                    _TabBtn(label: 'Offer',    active: _activeTab == _NotifTab.offer,    onTap: () => setState(() => _activeTab = _NotifTab.offer)),
                    const SizedBox(width: 8),
                    _TabBtn(label: 'Reminder', active: _activeTab == _NotifTab.reminder, onTap: () => setState(() => _activeTab = _NotifTab.reminder)),
                  ],
                ),
              ),

              // ── Mark all read bar ────────────────────────────────────────
              if (unread > 0)
                Container(
                  color: const Color(0xFFEFF6FF),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.mark_email_read_outlined, size: 28, color: Color(0xFF2563EB)),
                      const SizedBox(width: 6),
                      Text('$unread unread notification${unread > 1 ? 's' : ''}',
                          style: const TextStyle(fontSize: 13, color: Color(0xFF2563EB), fontWeight: FontWeight.w500)),
                      const Spacer(),
                      GestureDetector(
                        onTap: _markAllRead,
                        child: const Text('Mark all read',
                            style: TextStyle(fontSize: 13, color: Color(0xFF2563EB), fontWeight: FontWeight.w700,
                                decoration: TextDecoration.underline, decorationColor: Color(0xFF2563EB))),
                      ),
                    ],
                  ),
                ),

              // ── List ────────────────────────────────────────────────────
              Expanded(
                child: provider.isLoading
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)))
                    : filtered.isEmpty
                        ? _buildEmpty()
                        : RefreshIndicator(
                            color: const Color(0xFF2563EB),
                            onRefresh: provider.fetchNotifications,
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                              itemCount: filtered.length,
                              itemBuilder: (context, i) => _NotifCard(
                                key: ValueKey(filtered[i].id),
                                notif: filtered[i],
                                onTap: () => _markRead(filtered[i]),
                              ),
                            ),
                          ),
              ),
            ],
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(int unreadCount, String location) {
    final topPad = MediaQuery.of(context).padding.top;

    return PreferredSize(
      preferredSize: Size.fromHeight(112 + topPad),
      child: Container(
        color: Colors.white,
        child: SafeArea(
          bottom: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    Image.asset('assets/images/home_main_logo.png', height: 30, fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Row(children: [
                          Image.asset('assets/icons/main_icon.png', width: 38, height: 38),
                          const SizedBox(width: 6),
                          const Text('claimit', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: Color(0xFF1565C0))),
                        ])),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => context.push('/location'),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Flexible(child: Text(location, maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black))),
                        const SizedBox(width: 2),
                        const Icon(Icons.keyboard_arrow_down_rounded, size: 26),
                      ]),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => context.push('/search'),
                      child: Container(
                        width: 38, height: 38,
                        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0xFFE5E7EB))),
                        child: const Icon(Icons.search, size: 28, color: Color(0xFF1565C0)),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFF3F4F6)),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 16, 10),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => context.go('/home'),
                      child: const Padding(padding: EdgeInsets.all(8),
                          child: Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF1565C0), size: 18)),
                    ),
                    const SizedBox(width: 2),
                    const Text('Notifications', style: TextStyle(color: Color(0xFF111827), fontSize: 18, fontWeight: FontWeight.bold)),
                    if (unreadCount > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: const Color(0xFF1565C0), borderRadius: BorderRadius.circular(12)),
                        child: Text('$unreadCount', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
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
      _NotifTab.all:      'No notifications yet',
      _NotifTab.alert:    'No alert notifications',
      _NotifTab.offer:    'No offer notifications',
      _NotifTab.reminder: 'No reminders',
    };
    final sublabels = {
      _NotifTab.all:      'We\'ll notify you about offers, alerts and reminders.',
      _NotifTab.alert:    'System and delivery alerts will appear here.',
      _NotifTab.offer:    'Exclusive deals and cashback offers will appear here.',
      _NotifTab.reminder: 'Bill scan and reward reminders will appear here.',
    };
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(width: 88, height: 88,
            decoration: const BoxDecoration(color: Color(0xFFEFF6FF), shape: BoxShape.circle),
            child: const Icon(Icons.notifications_none_rounded, size: 44, color: Color(0xFF2563EB))),
        const SizedBox(height: 18),
        Text(labels[_activeTab]!, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Text(sublabels[_activeTab]!, textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280), height: 1.5)),
        ),
      ]),
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
        child: Text(label,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                color: active ? Colors.white : const Color(0xFF6B7280))),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Notification card
// ─────────────────────────────────────────────────────────────────────────────

class _NotifCard extends StatelessWidget {
  final NotificationModel notif;
  final VoidCallback onTap;
  const _NotifCard({super.key, required this.notif, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final meta = _metaFor(notif.type);

    Color bgColor = notif.isRead ? Colors.white : const Color(0xFFEFF6FF);
    Color borderColor = notif.isRead
        ? const Color(0xFFE5E7EB)
        : const Color(0xFF2563EB).withOpacity(0.25);
    Color? accentBar;

    if (notif.isBillReviewApproved) {
      accentBar   = const Color(0xFF2E7D32);
      borderColor = const Color(0xFF2E7D32).withOpacity(0.4);
      bgColor     = notif.isRead ? Colors.white : const Color(0xFFE8F5E9);
    } else if (notif.isBillReviewRejected) {
      accentBar   = const Color(0xFFC62828);
      borderColor = const Color(0xFFC62828).withOpacity(0.4);
      bgColor     = notif.isRead ? Colors.white : const Color(0xFFFFEBEE);
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),  // uniform — valid with borderRadius
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: Stack(
            children: [
              // Coloured left accent bar for bill review cards
              if (accentBar != null)
                Positioned(
                  left: 0, top: 0, bottom: 0,
                  child: Container(width: 4, color: accentBar),
                ),
              // Card content
              Padding(
                padding: EdgeInsets.only(
                  left: accentBar != null ? 18 : 14,
                  right: 14,
                  top: 14,
                  bottom: 14,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icon circle
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: meta.iconColor.withOpacity(0.13),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(meta.icon, color: meta.iconColor, size: 24),
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
                            notif.message,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF6B7280),
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Text(
                                _timeAgo(notif.createdAt),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF9CA3AF),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (notif.isBillReview) ...[
                                const SizedBox(width: 8),
                                Text(
                                  'Tap to view wallet',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: meta.iconColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
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
