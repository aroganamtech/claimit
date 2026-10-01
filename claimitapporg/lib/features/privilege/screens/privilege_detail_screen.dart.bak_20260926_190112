import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../models/privilege_models.dart';
import '../services/privilege_service.dart';
import '../widgets/privilege_common.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Screen 3 — partner detail.
//
// Photos, the % OFF badge, then About / Privilege Details / Terms & Conditions,
// and the button that opens the eligibility pass.
// ─────────────────────────────────────────────────────────────────────────────

class PrivilegeDetailScreen extends StatefulWidget {
  final String partnerId;
  const PrivilegeDetailScreen({super.key, required this.partnerId});

  @override
  State<PrivilegeDetailScreen> createState() => _PrivilegeDetailScreenState();
}

class _PrivilegeDetailScreenState extends State<PrivilegeDetailScreen> {
  PrivilegePartner? _partner;
  bool _loading = true;
  bool _issuing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await PrivilegeService.instance.fetchPartner(widget.partnerId);
    if (!mounted) return;
    setState(() {
      _partner = p;
      _loading = false;
    });
  }

  Future<void> _showEligibility() async {
    if (_issuing || _partner == null) return;
    setState(() => _issuing = true);

    final res = await PrivilegeService.instance.issuePass(_partner!.id);
    if (!mounted) return;
    setState(() => _issuing = false);

    if (res.pass == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res.error ?? 'Could not open your privilege.')),
      );
      return;
    }
    context.push('/privilege/pass', extra: res.pass);
  }

  @override
  Widget build(BuildContext context) {
    final p = _partner;

    return Scaffold(
      backgroundColor: kPrivBg,
      appBar: const PrivilegeHeader(showBack: true),
      bottomNavigationBar: const PrivilegeBottomBar(current: 1),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : p == null
              ? const Center(
                  child: Text('This privilege is no longer available',
                      style: TextStyle(color: kPrivMuted)))
              : ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    _photos(p),

                    // ── Name + badge ─────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(p.name,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        color: kPrivInk)),
                                const SizedBox(height: 3),
                                Text(
                                  [p.area, p.city]
                                      .where((s) => s.isNotEmpty)
                                      .join(', '),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 13, color: kPrivMuted),
                                ),
                                if (p.distance.isNotEmpty) ...[
                                  const SizedBox(height: 3),
                                  Text(p.distance,
                                      style: const TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600,
                                          color: kPrivBlue)),
                                ],
                              ],
                            ),
                          ),
                          if (p.discountPercent > 0) ...[
                            const SizedBox(width: 12),
                            PrivilegeBadge(text: p.percentBadge),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          PrivilegeSection(title: 'About', body: p.about),
                          PrivilegeSection(
                              title: 'Privilege Details',
                              body: p.privilegeDetails),
                          PrivilegeSection(
                              title: 'Terms & Conditions', body: p.terms),
                        ],
                      ),
                    ),

                    // ── CTA ──────────────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 26),
                      child: SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _issuing ? null : _showEligibility,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kPrivYellow,
                            foregroundColor: const Color(0xFF3A2E00),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          child: _issuing
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Color(0xFF3A2E00)))
                              : const Text('Show Discount Eligibility',
                                  style: TextStyle(
                                      fontSize: 15.5,
                                      fontWeight: FontWeight.w800)),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _photos(PrivilegePartner p) {
    final urls = p.photoUrls.isNotEmpty
        ? p.photoUrls
        : (p.photoUrl.isNotEmpty ? [p.photoUrl] : const <String>[]);

    if (urls.isEmpty) {
      return Container(
        height: 190,
        color: const Color(0xFFEEF2F7),
        child: const Icon(Icons.storefront_rounded, size: 48, color: kPrivMuted),
      );
    }
    return SizedBox(
      height: 190,
      child: PageView.builder(
        itemCount: urls.length,
        itemBuilder: (_, i) => CachedNetworkImage(
          imageUrl: urls[i],
          fit: BoxFit.cover,
          placeholder: (_, __) => Container(color: const Color(0xFFEEF2F7)),
          errorWidget: (_, __, ___) => Container(
            color: const Color(0xFFEEF2F7),
            child: const Icon(Icons.storefront_rounded,
                size: 48, color: kPrivMuted),
          ),
        ),
      ),
    );
  }
}
