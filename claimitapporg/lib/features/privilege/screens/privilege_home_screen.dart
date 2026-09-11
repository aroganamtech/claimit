import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../auth/providers/auth_provider.dart';
import '../models/privilege_models.dart';
import '../services/privilege_service.dart';
import '../widgets/privilege_common.dart';

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

class _PrivilegeHomeScreenState extends State<PrivilegeHomeScreen> {
  Map<String, int> _counts = {};

  @override
  void initState() {
    super.initState();
    _loadCounts();
  }

  Future<void> _loadCounts() async {
    final city = _cityOnly(context.read<AuthProvider>().user?.location ?? '');
    final counts = await PrivilegeService.instance.fetchCoverage(city);
    if (!mounted) return;
    setState(() => _counts = counts);
  }

  /// "Anna Nagar, Chennai" -> "Chennai". The coverage query matches on city,
  /// so sending the full label would find nothing.
  String _cityOnly(String location) {
    final parts = location.split(',');
    return parts.isNotEmpty ? parts.last.trim() : location.trim();
  }

  void _openCategory(PrivilegeCategory c) {
    context.push('/privilege/list', extra: {'category': c});
  }

  @override
  Widget build(BuildContext context) {
    final location = context.select<AuthProvider, String>(
      (a) => a.user?.location?.isNotEmpty == true
          ? a.user!.location!
          : 'Select location',
    );

    return Scaffold(
      backgroundColor: kPrivBg,
      appBar: const PrivilegeHeader(),
      bottomNavigationBar: const PrivilegeBottomBar(current: 0),

      // The + button replaces the removed drawer as the way to add your own
      // business — one obvious control instead of a hidden menu.
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/privilege/add'),
        backgroundColor: kPrivYellow,
        foregroundColor: const Color(0xFF3A2E00),
        icon: const Icon(Icons.add_rounded),
        label: const Text('List your business',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),

      body: RefreshIndicator(
        onRefresh: _loadCounts,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          // Bottom padding clears the floating button. 96 was too tight — the
          // button sat ON the banner (see the correction sheet screenshot),
          // hiding the artwork it was meant to sit below.
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 130),
          children: [
            // ── Headline ─────────────────────────────────────────────────
            // Replaces the search field, per the correction sheet. The nine
            // category tiles are right below and the list screens have their
            // own filters, so a search box here was one more thing to read
            // before the user could get anywhere.
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kPrivLine),
              ),
              child: const Column(
                children: [
                  Text(
                    'Enjoy Exclusive',
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w800,
                      color: kPrivBlue,
                      height: 1.25,
                    ),
                  ),
                  Text(
                    'Privilege Discounts & Benefits',
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w800,
                      color: kPrivBlue,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── Selected location ────────────────────────────────────────
            InkWell(
              onTap: () => context.push('/location/pick'),
              child: Row(
                children: [
                  const Icon(Icons.location_on_rounded,
                      size: 18, color: kPrivBlue),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      location,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: kPrivInk),
                    ),
                  ),
                  const Icon(Icons.keyboard_arrow_down_rounded,
                      size: 20, color: kPrivInk),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ── Category grid ────────────────────────────────────────────
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: kPrivilegeCategories.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                // The tile sizes its own contents from this height (see
                // _CategoryTile), so this ratio is the one number that tunes
                // the whole grid. 0.72 gives roughly a 144px tall tile on a
                // normal phone, which puts the icon at about 60.
                childAspectRatio: 0.72,
              ),
              itemBuilder: (_, i) =>
                  _CategoryTile(
                    category: kPrivilegeCategories[i],
                    count: _counts[kPrivilegeCategories[i].id],
                    onTap: () => _openCategory(kPrivilegeCategories[i]),
                  ),
            ),
            const SizedBox(height: 16),

            // ── Campaign banner ──────────────────────────────────────────
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.asset(
                'assets/images/privilege_banner.jpeg',
                fit: BoxFit.cover,
                // Falls back to a drawn banner so the screen still looks
                // finished before the artwork is dropped in.
                errorBuilder: (_, __, ___) => Container(
                  height: 140,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [kPrivBlue, Color(0xFF0D47A1)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Claimit',
                          style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              height: 1.1)),
                      const Text('Privilege',
                          style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: kPrivYellow,
                              height: 1.1)),
                      const SizedBox(height: 6),
                      const Text('Exclusive Benefits. Exceptional Savings.',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: Colors.white)),
                      const SizedBox(height: 2),
                      const Text('Explore • Show • Save',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: kPrivYellow)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final PrivilegeCategory category;
  final int? count;
  final VoidCallback onTap;

  const _CategoryTile({
    required this.category,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Dimmed when we know there is nothing here — a tap that leads to an empty
    // list is worse than a tile that says so up front.
    final empty = count != null && count == 0;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: kPrivLine),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 9),
        // Everything below is measured from the tile's OWN box rather than
        // from a hard-coded pixel size or a guess at the screen width. The
        // grid decides how wide a tile is; this asks how tall it actually
        // came out and takes a share of that.
        //
        // Measuring is what makes it right on every device instead of right
        // on the one it was designed against: a 5" phone, a 6.7" phone and a
        // tablet all get proportionally the same tile, and a large system
        // font can't push the label out of the box.
        child: LayoutBuilder(
          builder: (context, box) {
            final h = box.maxHeight;

            // ~44% of the tile height. On a normal phone that lands at about
            // 60px, which is the size Ramesh asked for — but it is derived,
            // so it holds on any screen. Clamped so a very small tile keeps a
            // legible icon and a very large one doesn't get a cartoon.
            final iconSize = (h * 0.44).clamp(40.0, 88.0);
            final labelSize = (h * 0.077).clamp(9.5, 13.5);
            final countSize = (h * 0.068).clamp(8.5, 12.0);
            final gap = (h * 0.04).clamp(3.0, 8.0);

            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Opacity(
                  opacity: empty ? 0.4 : 1,
                  child: SizedBox(
                    width: iconSize,
                    height: iconSize,
                    child: Image.asset(
                      category.iconAsset,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Icon(
                        category.icon,
                        size: iconSize * 0.82,
                        color: category.color,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: gap),
                // Flexible, not Expanded: the label takes the space that is
                // left and no more, so it can never demand height the tile
                // hasn't got.
                Flexible(
                  child: Center(
                    child: Text(
                      category.label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: labelSize,
                        height: 1.2,
                        fontWeight: FontWeight.w600,
                        color: empty ? kPrivMuted : kPrivInk,
                      ),
                    ),
                  ),
                ),
                if (count != null && count! > 0)
                  Text('$count here',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: countSize,
                          fontWeight: FontWeight.w700,
                          color: kPrivBlue)),
              ],
            );
          },
        ),
      ),
    );
  }
}
