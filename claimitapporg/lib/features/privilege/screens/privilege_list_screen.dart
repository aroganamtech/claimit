import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../models/privilege_models.dart';
import '../services/privilege_service.dart';
import '../widgets/privilege_common.dart';

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

class _PrivilegeListScreenState extends State<PrivilegeListScreen> {
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
      bottomNavigationBar: const PrivilegeBottomBar(current: 1),
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
                          padding: const EdgeInsets.fromLTRB(14, 12, 14, 20),
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
class _PartnerCard extends StatelessWidget {
  final PrivilegePartner partner;
  const _PartnerCard({required this.partner});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kPrivLine),
      ),
      // IntrinsicHeight so the stretched image column can't be handed an
      // infinite height inside the scroll view.
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(14)),
              child: SizedBox(
                width: 110,
                child: partner.photoUrl.isEmpty
                    ? Container(
                        color: const Color(0xFFEEF2F7),
                        child: const Icon(Icons.storefront_rounded,
                            size: 30, color: kPrivMuted),
                      )
                    : CachedNetworkImage(
                        imageUrl: partner.photoUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, __) =>
                            Container(color: const Color(0xFFEEF2F7)),
                        errorWidget: (_, __, ___) => Container(
                          color: const Color(0xFFEEF2F7),
                          child: const Icon(Icons.storefront_rounded,
                              size: 30, color: kPrivMuted),
                        ),
                      ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(partner.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: kPrivInk)),
                    const SizedBox(height: 2),
                    // Plain text, no location pin — the icon was removed from
                    // every card in this app.
                    Text(partner.area.isNotEmpty ? partner.area : partner.city,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12.5, color: kPrivMuted)),
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
                    const SizedBox(height: 9),
                    Row(
                      children: [
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 9, vertical: 5),
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
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () => context.push('/privilege/detail',
                              extra: partner.id),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: kPrivBlue,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text('View privilege',
                                maxLines: 1,
                                style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
