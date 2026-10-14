import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/location_provider.dart';
import '../../../core/providers/location_reload_mixin.dart';
import '../models/privilege_models.dart';
import '../services/privilege_service.dart';
import '../widgets/privilege_common.dart';
import '../../../core/widgets/claimit_bottom_bar.dart';
import '../../../features/home/screens/home_screen.dart';
import '../../../core/widgets/spot_promo_card.dart';
import '../../../core/widgets/spot_promo_sheet.dart';
import '../../../core/services/spot_promo_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Screen 1 — Claimit Privilege home.
//
// Search, the selected location, the 3x3 category grid, the campaign banner,
// and a + button to list your own business. No drawer and no hamburger: both
// were removed at Ramesh's request, so the bottom bar is the only navigation.
//
// Each category tile carries a live count for the selected city, so a user can
// see where the privileges actually are before tapping into an empty list.
// ─────────────────────────────────────────────────────────────────────────────

class PrivilegeHomeScreen extends StatefulWidget {
  const PrivilegeHomeScreen({super.key});

  @override
  State<PrivilegeHomeScreen> createState() => _PrivilegeHomeScreenState();
}

class _PrivilegeHomeScreenState extends State<PrivilegeHomeScreen>
    with LocationReloadMixin {
  // ── Nearby partners ───────────────────────────────────────────────────────
  // The backend already does the hard part: /privilege/partners sorts by
  // distance and falls back from 5 km to 10 km to nearest-anywhere, so this
  // section is never empty just because the user is somewhere quiet.
  List<PrivilegePartner> _nearby = const [];
  bool _loadingNearby = true;

  /// Paid Spot Promos. The SAME list shows on Local Finder and Claimit Select
  /// — one booking, three pages — so this comes from the shared
  /// SpotPromoService rather than anything Privilege-specific. They sit above
  /// the organic partners because that placement is what was paid for.
  List<SpotPromoDto> _paidPromos = const [];

  /// Favourites, per session — same affordance as the Local Finder card.
  final Set<String> _liked = <String>{};
  bool _showingNearest = false;

  /// Search is scoped to Privilege by construction — it calls the Privilege
  /// partners endpoint, not the app's global search. Typing "salon" here can
  /// only ever return privilege partners.
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadNearby();
  }

  @override
  void onLocationChanged() {
    _loadNearby();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadNearby() async {
    // A pull-to-refresh must actually reach the network: the promo cache
    // would otherwise serve the same list straight back for 3 minutes.
    SpotPromoService.instance.invalidate();
    setState(() => _loadingNearby = true);
    // Kick both off before awaiting either, so the paid strip does not make
    // the page wait any longer than it already does for the partner list.
    // (Future.wait would work too, but on two different result types it
    // collapses to List<Object?> and needs casting back.)
    final partnersFuture =
        PrivilegeService.instance.fetchPartners(sort: 'distance', limit: 6);
    final promosFuture = SpotPromoService.instance.fetch();
    final page = await partnersFuture;
    final promos = await promosFuture;
    if (!mounted) return;
    setState(() {
      _nearby = page.partners;
      _showingNearest = page.showingNearest;
      _paidPromos = promos;
      _loadingNearby = false;
    });
  }

  /// Hands the term to the list screen, which runs it against the backend —
  /// so a search covers every partner, not only the six loaded here.
  void _submitSearch(String raw) {
    final q = raw.trim();
    if (q.isEmpty) return;
    context.push('/privilege/list', extra: {'search': q});
  }

  Future<void> _refresh() async {
    await _loadNearby();
  }

  void _openCategory(PrivilegeCategory c) {
    context.push('/privilege/list', extra: {'category': c});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      // Identical header to Local Finder â logo, hairline divider, then the
      // feature name in that feature's own colour. Privilege is blue.
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: kPrivBlue, size: 20),
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            Image.asset(
              'assets/images/home_main_logo.png',
              height: 30,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Text('claimit',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: kPrivBlue)),
            ),
            const SizedBox(width: 8),
            Container(width: 1.5, height: 20, color: const Color(0xFFD7DEE8)),
            const SizedBox(width: 8),
            const Flexible(
              child: Text(
                'Privilege',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: kPrivBlue,
                    fontWeight: FontWeight.w800,
                    fontSize: 18),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'My Privileges',
            icon: const Icon(Icons.local_offer_rounded,
                color: kPrivBlue, size: 22),
            onPressed: () => context.push('/privilege/history'),
          ),
        ],
      ),
      // The dashboard's centre button, docked into the shared bar's notch —
      // without it the bar has a 72px hole where the button should be.
      floatingActionButton:
          ClaimitCenterFab(onTap: () => showClaimitFeaturedZones(context)),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: const ClaimitBottomBar(),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          children: [
            _locationField(),
            // Tightened at the client's request: the three stacked controls
            // and the banner were sitting too far apart, pushing the cards
            // below the fold.
            const SizedBox(height: 6),
            _searchField(),
            const SizedBox(height: 8),
            _banner(),
            const SizedBox(height: 10),
            _sectionHeader(
                'Categories', () => context.push('/privilege/categories')),
            const SizedBox(height: 6),
            _categoriesGrid(),
            const SizedBox(height: 6),
            _nearbyHeader(),
            const SizedBox(height: 10),
            if (_loadingNearby)
              const Padding(
                  padding: EdgeInsets.all(28),
                  child:
                      Center(child: CircularProgressIndicator(color: kPrivBlue)))
            else if (_nearby.isEmpty && _paidPromos.isEmpty)
              _emptyNearby()
            else ...[
              // Told, not hidden: if nothing fell inside the radius, the list
              // is the nearest partners anywhere.
              if (_showingNearest && _nearby.isNotEmpty)
                const Padding(
                  padding: EdgeInsets.only(bottom: 10),
                  child: Text(
                    'Nothing within your radius yet — showing the nearest instead.',
                    style: TextStyle(
                        fontSize: 12,
                        color: kPrivMuted,
                        fontStyle: FontStyle.italic),
                  ),
                ),
              ..._nearby.map(_promoCard),
              // ── Spot Promos — AFTER the organic list ────────────────────
              // Identical on Local Finder, Select and Privilege: one booking,
              // one collection, one endpoint. Hidden entirely when nothing is
              // booked, so an empty heading never shows.
              if (_paidPromos.isNotEmpty) ...[
                _spotPromoHeader(),
                ..._paidPromos.map(_paidPromoCard),
              ],
            ],
            const SizedBox(height: 14),
            _registerButton(context),
          ],
        ),
      ),
    );
  }

  // ── Location ────────────────────────
  // The app-wide selected location, exactly as Local Finder shows it.
  Widget _locationField() {
    final label = context.select<LocationProvider, String>(
      (l) => l.selected?.display ?? 'Select location',
    );
    return InkWell(
      onTap: () => context.push('/location/pick'),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFD7DEE8)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            const Icon(Icons.location_on_rounded, size: 18, color: kPrivBlue),
            const SizedBox(width: 8),
            Expanded(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 14,
                      color: kPrivInk,
                      fontWeight: FontWeight.w500)),
            ),
            const Icon(Icons.keyboard_arrow_down_rounded,
                size: 20, color: kPrivMuted),
          ],
        ),
      ),
    );
  }

  // ── Banner ────────────────────────
  Widget _banner() => ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.asset(
          'assets/images/privilege_banner.png',
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            height: 140,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.all(18),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [kPrivBlue, Color(0xFF0D47A1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Text(
              'Explore exclusive privileges\nand offers across India.',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  height: 1.3),
            ),
          ),
        ),
      );

  Widget _sectionHeader(String title, VoidCallback onSeeAll) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w800, color: kPrivBlue)),
          GestureDetector(
            onTap: onSeeAll,
            child: const Text('See All',
                style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: kPrivBlue)),
          ),
        ],
      );

  /// Five across, icon + label — the same grid Local Finder draws, so the ten
  /// categories sit in two even rows.
  Widget _categoriesGrid() {
    final iconSize =
        (MediaQuery.of(context).size.width / 6).clamp(52.0, 80.0);
    return GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        mainAxisSpacing: 10,
        crossAxisSpacing: 6,
        // Height stated outright rather than derived from the cell WIDTH:
        // childAspectRatio made the tile shorter than the icon on a 360dp
        // phone (overflow) and taller than it needed on a wide one (the gap
        // under the labels). icon + 4 gap + ~15 label + 1 slack.
        mainAxisExtent: iconSize + 20,
      ),
      children: kPrivilegeCategories
          .map((c) => GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _openCategory(c),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      c.iconAsset,
                      width: iconSize,
                      height: iconSize,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Container(
                        width: iconSize,
                        height: iconSize,
                        decoration: const BoxDecoration(
                            color: Color(0xFFE8F0FE), shape: BoxShape.circle),
                        child:
                            Icon(c.icon, size: iconSize * 0.5, color: kPrivBlue),
                      ),
                    ),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(c.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: kPrivInk)),
                    ),
                  ],
                ),
              ))
          .toList(),
    );
  }

  Widget _registerButton(BuildContext context) => SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => context.push('/privilege/add'),
          icon: const Icon(Icons.add_business_rounded),
          label: const Text('List Your Business'),
          style: ElevatedButton.styleFrom(
            backgroundColor: kPrivYellow,
            foregroundColor: const Color(0xFF3A2E00),
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      );

  // ── Search field ──────────────────────────────────────────────────────────
  Widget _searchField() => Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: kPrivLine),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            const Icon(Icons.search_rounded, size: 19, color: kPrivMuted),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                textInputAction: TextInputAction.search,
                onSubmitted: _submitSearch,
                decoration: const InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: 'Search privilege partners',
                  hintStyle: TextStyle(fontSize: 13.5, color: kPrivMuted),
                ),
                style: const TextStyle(fontSize: 14, color: kPrivInk),
              ),
            ),
            GestureDetector(
              onTap: () => _submitSearch(_searchCtrl.text),
              child: const Icon(Icons.arrow_forward_rounded,
                  size: 19, color: kPrivBlue),
            ),
          ],
        ),
      );

  /// The ORGANIC partners section. Named for what it actually contains.
  ///
  /// This used to be titled "Spot Promos", which is why the client saw
  /// "different Spot Promos on each page": the heading was the ad section's
  /// name but the list under it was this page's own partners, which of course
  /// differ from Select's professionals and Local Finder's businesses. Paid
  /// promos now live in their own section (see _spotPromoHeader) and are
  /// identical on all three pages.
  Widget _nearbyHeader() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Nearby Partners',
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w800, color: kPrivBlue),
          ),
          const SizedBox(height: 4),
          Container(width: 104, height: 2.5, color: kPrivYellow),
        ],
      );

  /// Heading for the PAID section. Labelled "Sponsored" because a paid card
  /// sitting among organic listings has to say what it is.
  Widget _spotPromoHeader() => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(height: 1, color: Color(0xFFE5E7EB)),
            const SizedBox(height: 16),
            Row(
              children: const [
                Text('Spot Promos',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w800,
                        color: kPrivBlue)),
                SizedBox(width: 8),
                Text('Sponsored',
                    style: TextStyle(
                        fontSize: 10.5, fontWeight: FontWeight.w600,
                        color: Color(0xFF9CA3AF))),
              ],
            ),
            const SizedBox(height: 4),
            Container(width: 104, height: 2.5, color: kPrivYellow),
            const SizedBox(height: 4),
          ],
        ),
      );

  Widget _emptyNearby() => Container(
        padding: const EdgeInsets.symmetric(vertical: 26),
        alignment: Alignment.center,
        child: const Text(
          'No privilege partners here yet.',
          style: TextStyle(color: kPrivMuted),
        ),
      );

  /// One Spot Promo — the same card Nearby Deals draws.
  Widget _promoCard(PrivilegePartner p) => SpotPromoCard(
        promo: SpotPromo(
          id:       p.id,
          name:     p.name,
          location: p.address.isNotEmpty
              ? p.address
              : [p.area, p.city].where((e) => e.isNotEmpty).join(', '),
          offer:    p.offerChip,
          distance: p.distance,
          category: p.categoryLabel,
          image:    p.photoUrl,
        ),
        accent:      kPrivBlue,
        isFavourite: _liked.contains(p.id),
        onFavourite: () => setState(() => _liked.contains(p.id)
            ? _liked.remove(p.id)
            : _liked.add(p.id)),
        onTap: () => context.push('/privilege/detail', extra: p.id),
      );

  /// One paid Spot Promo. Identical card, identical sheet, on all three
  /// pages — the mapping lives on the DTO so it cannot diverge between them.
  Widget _paidPromoCard(SpotPromoDto p) => SpotPromoCard(
        promo:       p.toCard(),
        accent:      kPrivBlue,
        isFavourite: _liked.contains(p.id),
        onFavourite: () => setState(() => _liked.contains(p.id)
            ? _liked.remove(p.id)
            : _liked.add(p.id)),
        onTap: () => showSpotPromoSheet(context, p, accent: kPrivBlue),
      );
}
