import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/select_booking.dart';
import '../services/select_service.dart';
import '../widgets/select_common.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Claimit Select — Bookings tab.
//
// Two sides of the same feature:
//   • "My Bookings"  — consultations the user booked with others.
//   • "Requests"     — consultations booked with the user's own listing,
//                      which they can Confirm or Decline.
//
// The Requests segment only appears when the user actually has a listing, so a
// plain customer sees a single simple list.
// ─────────────────────────────────────────────────────────────────────────────

class SelectBookingsScreen extends StatefulWidget {
  const SelectBookingsScreen({super.key});

  @override
  State<SelectBookingsScreen> createState() => _SelectBookingsScreenState();
}

class _SelectBookingsScreenState extends State<SelectBookingsScreen> {
  bool _loading = true;
  bool _isProfessional = false;
  int _tab = 0; // 0 = mine, 1 = requests
  List<SelectBooking> _mine = const [];
  List<SelectBooking> _received = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    // Both lists in parallel — /bookings/received simply returns [] when the
    // caller has no listing, so this is safe for every user.
    final results = await Future.wait([
      SelectService.instance.fetchMyBookings(),
      SelectService.instance.fetchReceivedBookings(),
      SelectService.instance.fetchMyProfile(),
    ]);
    if (!mounted) return;
    setState(() {
      _mine = results[0] as List<SelectBooking>;
      _received = results[1] as List<SelectBooking>;
      _isProfessional = results[2] != null;
      if (!_isProfessional) _tab = 0;
      _loading = false;
    });
  }

  Future<void> _setStatus(SelectBooking b, String status) async {
    final ok = await SelectService.instance.updateBookingStatus(b.id, status);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't update. Please try again.")),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(status == 'confirmed'
            ? 'Booking confirmed'
            : 'Booking declined'),
      ),
    );
    _load();
  }

  Future<void> _callCustomer(String phone) async {
    final p = phone.trim();
    if (p.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No phone number on this booking')),
      );
      return;
    }
    final uri = Uri.parse('tel:$p');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  List<SelectBooking> get _current => _tab == 0 ? _mine : _received;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSelBg,
      bottomNavigationBar: const SelectBottomNav(current: 1),
      body: Column(
        children: [
          _blueHeader(),
          if (_isProfessional) _segments(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: kSelAccent))
                : _current.isEmpty
                    ? _empty()
                    : RefreshIndicator(
                        onRefresh: _load,
                        color: kSelAccent,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(14, 14, 14, 20),
                          itemCount: _current.length,
                          itemBuilder: (_, i) => _BookingCard(
                            booking: _current[i],
                            onConfirm: _tab == 1
                                ? () => _setStatus(_current[i], 'confirmed')
                                : null,
                            onDecline: _tab == 1
                                ? () => _setStatus(_current[i], 'cancelled')
                                : null,
                            onCallCustomer: _tab == 1
                                ? () => _callCustomer(_current[i].customerPhone)
                                : null,
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _empty() {
    if (_tab == 1) {
      return const SelEmptyState(
        icon: Icons.inbox_rounded,
        title: 'No requests yet',
        message:
            'When a customer books a consultation with you, it appears here '
            'for you to confirm.',
      );
    }
    return SelEmptyState(
      icon: Icons.calendar_month_rounded,
      title: 'No bookings yet',
      message: 'Consultations you book with professionals will show up here.',
      action: ElevatedButton(
        onPressed: () => context.go('/select'),
        style: ElevatedButton.styleFrom(
          backgroundColor: kSelYellow,
          foregroundColor: kSelOnYellow,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
        ),
        child: const Text('Find a professional'),
      ),
    );
  }

  Widget _blueHeader() {
    return Container(
      width: double.infinity,
      color: kSelYellow,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 4, 16, 12),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: kSelOnYellow),
                onPressed: () => context.go('/select'),
              ),
              const Expanded(
                child: Text(
                  'Bookings',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: kSelOnYellow,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _segments() {
    final pending =
        _received.where((b) => b.status == 'requested').length;
    return Container(
      color: kSelYellow,
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      child: Row(
        children: [
          Expanded(child: _segment('My Bookings', 0, 0)),
          const SizedBox(width: 8),
          Expanded(child: _segment('Requests', 1, pending)),
        ],
      ),
    );
  }

  Widget _segment(String label, int index, int badge) {
    final selected = _tab == index;
    return GestureDetector(
      onTap: () => setState(() => _tab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 10),
        decoration: BoxDecoration(
          color: selected ? kSelYellow : Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: selected ? const Color(0xFF3A2E00) : kSelInk,
                  ),
                ),
              ),
            ),
            if (badge > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: selected ? const Color(0xFF3A2E00) : kSelAccent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$badge',
                  maxLines: 1,
                  style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  const _BookingCard({
    required this.booking,
    this.onConfirm,
    this.onDecline,
    this.onCallCustomer,
  });

  final SelectBooking booking;
  final VoidCallback? onConfirm;
  final VoidCallback? onDecline;
  final VoidCallback? onCallCustomer;

  bool get _isIncoming => onConfirm != null;

  Color get _statusColor {
    switch (booking.status) {
      case 'confirmed':
        return const Color(0xFF1B7A3D);
      case 'cancelled':
        return const Color(0xFFC62828);
      default:
        return const Color(0xFFB26A00);
    }
  }

  Color get _statusBg {
    switch (booking.status) {
      case 'confirmed':
        return const Color(0xFFE7F7EC);
      case 'cancelled':
        return const Color(0xFFFDECEA);
      default:
        return const Color(0xFFFFF6E5);
    }
  }

  String get _statusLabel {
    switch (booking.status) {
      case 'confirmed':
        return 'Confirmed';
      case 'cancelled':
        return 'Declined';
      default:
        return 'Requested';
    }
  }

  @override
  Widget build(BuildContext context) {
    // On an incoming request the important party is the customer; on the
    // user's own booking it's the professional.
    final title = _isIncoming
        ? (booking.customerName.trim().isEmpty
            ? 'Customer'
            : booking.customerName)
        : booking.professionalName;
    final subtitle =
        _isIncoming ? booking.customerPhone : booking.professionalRole;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!_isIncoming)
                SelPhoto(
                  url: booking.professionalPhotoUrl,
                  width: 54,
                  height: 54,
                  radius: 10,
                )
              else
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF3FB),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.person_rounded, color: kSelAccent),
                ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: kSelInk,
                      ),
                    ),
                    if (subtitle.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: kSelMuted),
                      ),
                    ],
                    if (booking.service.trim().isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        booking.service,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: kSelInk),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: _statusBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _statusLabel,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: kSelLine),
          const SizedBox(height: 10),
          // Wrap so these chips reflow instead of overflowing on a narrow
          // screen or at a large system font size.
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              _metaChip(Icons.event_rounded, booking.date),
              _metaChip(Icons.schedule_rounded, booking.timeSlot),
              _metaChip(Icons.videocam_rounded, booking.modeLabel),
            ],
          ),
          if (booking.message.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: kSelBg,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text(
                booking.message,
                style: const TextStyle(
                    fontSize: 12.5, color: kSelInk, height: 1.4),
              ),
            ),
          ],
          // Professional actions — only on a request that's still pending.
          if (_isIncoming && booking.status == 'requested') ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onDecline,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFC62828),
                      side: const BorderSide(color: Color(0xFFC62828)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(9)),
                    ),
                    child: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('Decline', maxLines: 1),
                    ),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onConfirm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1B7A3D),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(9)),
                    ),
                    child: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('Confirm', maxLines: 1),
                    ),
                  ),
                ),
              ],
            ),
          ],
          // Once confirmed, give the professional a quick way to reach them.
          if (_isIncoming &&
              booking.status == 'confirmed' &&
              booking.customerPhone.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onCallCustomer,
                icon: const Icon(Icons.call_rounded, size: 17),
                label: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('Call customer', maxLines: 1),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: kSelAccent,
                  side: const BorderSide(color: kSelAccent),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _metaChip(IconData icon, String text) {
    if (text.trim().isEmpty) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: kSelMuted),
        const SizedBox(width: 4),
        Text(
          text,
          maxLines: 1,
          style: const TextStyle(fontSize: 12, color: kSelInk),
        ),
      ],
    );
  }
}
