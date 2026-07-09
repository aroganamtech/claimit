import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/classified_categories.dart';

// ─────────────────────────────────────────────────────────────────────────────
// "Local Finds" landing screen — opened from the FAB's Featured Zones popup
// via the "Local Finds Classifieds" tile. Shows a 12-tile zone grid (Shop,
// Eat, Fashion, Health, Fitness, Edu, Services, Auto, Stay, Entertain, Fin,
// Living) styled after the reference design, with a "LOCAL CLASSIFIEDS"
// heading beneath it that opens the existing Classified home screen
// (property / rental / job / buy & sell listings, restyled to match).
// ─────────────────────────────────────────────────────────────────────────────

const Color _navy = Color(0xFF1E3A5F);
const Color _gold = Color(0xFFC9A876);

class LocalFindsScreen extends StatelessWidget {
  const LocalFindsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _navy, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFDCE7F5),
              Color(0xFFE9E4EF),
              Color(0xFFF3E3EA),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            child: Column(
              children: [
                const SizedBox(height: 8),
                Text(
                  'LOCAL FINDS',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 34,
                    fontWeight: FontWeight.w700,
                    color: _navy,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 28),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: localFindZones.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 22,
                    crossAxisSpacing: 8,
                    childAspectRatio: 0.82,
                  ),
                  itemBuilder: (context, i) {
                    final zone = localFindZones[i];
                    return _LocalFindTile(
                      zone: zone,
                      onTap: () => _openZone(context, zone),
                    );
                  },
                ),
                const SizedBox(height: 36),
                GestureDetector(
                  onTap: () => context.push('/classified/home'),
                  child: Text(
                    'LOCAL CLASSIFIEDS',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: _navy,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Container(width: 64, height: 2, color: _gold),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openZone(BuildContext context, LocalFindZone zone) {
    // TODO: route to each zone's dedicated sub-category screen once that
    // content is provided; for now, let the user know it's on the way.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${zone.label} sub-categories coming soon'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: _navy,
      ),
    );
  }
}

class _LocalFindTile extends StatelessWidget {
  const _LocalFindTile({required this.zone, required this.onTap});
  final LocalFindZone zone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.55),
              border: Border.all(color: _gold, width: 1.4),
            ),
            child: Icon(zone.icon, size: 30, color: _navy),
          ),
          const SizedBox(height: 8),
          Text(
            zone.label.toUpperCase(),
            textAlign: TextAlign.center,
            style: GoogleFonts.playfairDisplay(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _navy,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}
