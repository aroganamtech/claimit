import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/providers/location_reload_mixin.dart';
import '../models/privilege_models.dart';
import '../services/privilege_service.dart';
import '../widgets/privilege_common.dart';
import '../../../core/widgets/claimit_bottom_bar.dart';
import '../../../features/home/screens/home_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Screen 2 — partners in a category.
//
// Three filter chips (Distance / Discount / Location), then the cards. Paged:
// the first 20 load, more arrive as the user scrolls, so a category with 400
// partners doesn't pull all of them down at once.
// ─────────────────────────────────────────────────────────────────────────────

class PrivilegeListScreen extends StatefulWidget {
  final PrivilegeCategory? category;
  final String? searchTerm;

  const PrivilegeListScreen({super.key, this.category, this.searchTerm});

  @override
  State<PrivilegeListScreen> createState() => _PrivilegeListScreenState();
}

class _PrivilegeListScreenState extends State<PrivilegeListScreen>
    with LocationReloadMixin {
  static const _pageSize = 20;

  final _scroll = ScrollController();
  final List<PrivilegePartner> _items = [];

  String _sort = 'distance';
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  bool _showingNearest = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_hasMore || _loadingMore || _loading) return;
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 300) {
      _loadMore();
    }
  }

  /// Location changed — start the list again from page 1. Paging state has to
  /// reset too, or page 2 of the old city gets appended to page 1 of the new
  /// one.
  @override
  void onLocationChanged() => _load();

  Future<void> _load() async {
    setState(() => _loading = true);
    final page = await PrivilegeService.instance.fetchPartners(
      category: widget.category?.id,
      search: widget.searchTerm,
      sort: _sort,
      skip: 0,
      limit: _pageSize,
    );
    if (!mounted) return;
    setState(() {
      _items
        ..clear()
        ..addAll(page.partners);
      _hasMore = page.hasMore;
      _showingNearest = page.showingNearest;
      _loading = false;
    });
  }

  Future<void> _loadMore() async {
    setState(() => _loadingMore = true);
    final page = await PrivilegeService.instance.fetchPartners(
      category: widget.category?.id,
      search: widget.searchTerm,
      sort: _sort,
      skip: _items.length,
      limit: _pageSize,
    );
    if (!mounted) return;
    setState(() {
      // Guard against a duplicate arriving if the same page is requested
      // twice on a fast scroll.
      final seen = _items.map((p) => p.id).toSet();
      _items.addAll(page.partners.where((p) => !seen.contains(p.id)));
      _hasMore = page.hasMore;
      _loadingMore = false;
    });
  }

  void _setSort(String s) {
    if (_sort == s) return;
    setState(() => _sort = s);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.category?.label ??
        (widget.searchTerm?.isNotEmpty == true
            ? 'Results for "${widget.searchTerm}"'
            : 'All Privileges');

    return Scaffold(
      backgroundColor: kPrivBg,
      appBar: const PrivilegeHeader(showBack: true),
      // The dashboard's centre button, docked into the shared bar's notch —
      // without it the bar has a 72px hole where the button should be.
      floatingActionButton:
          ClaimitCenterFab(onTap: () => showClaimitFeaturedZones(context)),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: const ClaimitBottomBar(),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: kPrivInk),
                  ),
                ),
              ],
            ),
          ),

          // ── Filter chips ─────────────────────────────────────────────
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              children: [
                _chip('Distance', 'distance'),
                _chip('Discount', 'discount'),
                _chip('Location', 'location'),
              ],
            ),
          ),

          // Said out loud rather than quietly widening the search: a partner
          // 40 km away is still useful, but calling it "nearby" would not be
          // true.
          if (_showingNearest && !_loading && _items.isNotEmpty)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(14, 8, 14, 0),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFFE082)),
              ),
              child: const Text(
                'Nothing in your area yet — showing the nearest instead.',
                style: TextStyle(fontSize: 12, color: Color(0xFF6D4C41)),
              ),
            ),

          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                    ? _empty()
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                          controller: _scroll,
                          physics: const AlwaysScrollableScrollPhysics(),
                          // Matches Select's list inset exactly (14, 14, 14, 20)
                          // so the two screens line up when you flick between
                          // them.
                          padding: const EdgeInsets.fromLTRB(14, 14, 14, 20),
                          itemCount: _items.length + (_hasMore ? 1 : 0),
                          itemBuilder: (_, i) {
                            if (i >= _items.length) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 20),
                                child: Center(
                                    child: SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2))),
                              );
                            }
                            return _PartnerCard(partner: _items[i]);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, String value) {
    final on = _sort == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: () => _setSort(value),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: on ? kPrivBlue : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: on ? kPrivBlue : kPrivLine),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: on ? Colors.white : kPrivInk,
            ),
          ),
        ),
      ),
    );
  }

  Widget _empty() => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 80),
          Icon(Icons.local_offer_outlined, size: 46, color: kPrivMuted),
          SizedBox(height: 10),
          Center(
            child: Text('No privileges here yet',
                style: TextStyle(fontSize: 14, color: kPrivMuted)),
          ),
        ],
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Card: image left, name / area / distance, offer chip + View privilege.
// ─────────────────────────────────────────────────────────────────────────────
/// Partner card.
///
/// Deliberately a mirror of _ProCard in select_list_screen.dart: same outer
/// margin and padding, same 104 px photo, same 12 px gutter, same full-width
/// two-button footer. Ramesh asked for Privilege and Select to look and
/// measure the same, and the two screens sit one tap apart in the app, so any
/// difference in card height or button placement reads as a bug rather than a
/// style.
///
/// What stays Privilege's own: the blue/yellow palette and the discount chip,
/// which has no equivalent in Select.
class _PartnerCard extends StatelessWidget {
  final PrivilegePartner partner;
  const _PartnerCard({required this.partner});

  Future<void> _call() async {
    final raw = partner.phone.trim();
    if (raw.isEmpty) return;
    final uri = Uri.parse('tel:$raw');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasPhone = partner.phone.trim().isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        // Shadow rather than a border, matching Select. A bordered card next
        // to a shadowed one looks like two different apps.
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
          // IntrinsicHeight + stretch makes the photo grow to exactly the
          // height of the text column beside it. Required here — a stretch Row
          // inside a ListView would otherwise hit "BoxConstraints forces an
          // infinite height".
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 104,
                  // The photo is the only positioned child of a Stack, so it
                  // reports zero intrinsic height. Without this a network image
                  // reports its own scaled height and card heights jump around
                  // with each photo's aspect ratio.
                  child: Stack(
                    children: [Positioned.fill(child: _photo())],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: _details()),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () =>
                      context.push('/privilege/detail', extra: partner.id),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kPrivBlue,
                    side: const BorderSide(color: kPrivBlue),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9)),
                  ),
                  child: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('View Privilege',
                        maxLines: 1,
                        style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                // Disabled rather than hidden when there is no number, so the
                // footer keeps the same two-column shape on every card.
                child: ElevatedButton.icon(
                  onPressed: hasPhone ? _call : null,
                  icon: const Icon(Icons.call_rounded, size: 17),
                  label: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('Call',
                        maxLines: 1,
                        style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrivYellow,
                    foregroundColor: const Color(0xFF3A2E00),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _photo() {
    const fallback = Icon(Icons.storefront_rounded,
        size: 30, color: kPrivMuted);

    if (partner.photoUrl.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: const Color(0xFFEEF2F7),
          borderRadius: BorderRadius.circular(12),
        ),
        child: fallback,
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: CachedNetworkImage(
        imageUrl: partner.photoUrl,
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(color: const Color(0xFFEEF2F7)),
        errorWidget: (_, __, ___) => Container(
          color: const Color(0xFFEEF2F7),
          child: fallback,
        ),
      ),
    );
  }

  Widget _details() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(partner.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 15.5,            // matches Select's name size
                fontWeight: FontWeight.w700,
                color: kPrivInk)),
        const SizedBox(height: 3),
        // Plain text, no location pin — the icon was removed from every card
        // in this app.
        Text(partner.area.isNotEmpty ? partner.area : partner.city,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12.5, color: kPrivMuted)),
        if (partner.distance.isNotEmpty) ...[
          const SizedBox(height: 3),
          Text(partner.distance,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: kPrivBlue)),
        ],
        const SizedBox(height: 8),
        // Align keeps the chip hugging its text instead of stretching to the
        // full column width.
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3CD),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              partner.offerChip,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF9A6B00)),
            ),
          ),
        ),
      ],
    );
  }
}
