import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/classified_post.dart';
import '../services/classified_service.dart';
import 'classified_home_screen.dart' show classifiedCategoryLabel;

// ─────────────────────────────────────────────────────────────────────────────
// Local Classifieds — ADS LIST landing page. Opens first when the Classifieds
// icon is tapped: shows the created ads, with an "Add Ads" icon in the top-right
// that opens the post-ad flow (category → details → payment) at /classified/add.
// (Split out from the old combined home page so ads and categories live on
//  separate screens.)
// ─────────────────────────────────────────────────────────────────────────────

const Color _blue = Color(0xFF1565C0);
const Color _ink = Color(0xFF1E293B);
const Color _muted = Color(0xFF64748B);

class ClassifiedAdsScreen extends StatefulWidget {
  const ClassifiedAdsScreen({super.key});

  @override
  State<ClassifiedAdsScreen> createState() => _ClassifiedAdsScreenState();
}

class _ClassifiedAdsScreenState extends State<ClassifiedAdsScreen> {
  List<ClassifiedPost> _ads = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await ClassifiedService.instance
        .fetchClassifieds(listingType: 'classified');
    if (mounted) setState(() { _ads = list; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _blue, size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text('Local Classifieds',
            style: TextStyle(color: _blue, fontWeight: FontWeight.w700, fontSize: 18)),
        actions: [
          // Add Ads — opens the post-ad flow (starts with choosing a category).
          IconButton(
            tooltip: 'Add Ads',
            icon: const Icon(Icons.post_add, color: _blue),
            onPressed: () => context.push('/classified/add'),
          ),
          IconButton(
            tooltip: 'My Listings',
            icon: const Icon(Icons.list_alt_rounded, color: _blue),
            onPressed: () => context.push('/classified/mine'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: _blue))
            : _ads.isEmpty
                ? ListView(
                    children: [
                      const SizedBox(height: 120),
                      _empty(),
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
                    itemCount: _ads.length,
                    itemBuilder: (_, i) => _adCard(_ads[i]),
                  ),
      ),
    );
  }

  Widget _adCard(ClassifiedPost b) {
    final phone = b.whatsapp.isNotEmpty ? b.whatsapp : b.userPhone;
    return GestureDetector(
      onTap: () => context.push('/classified/detail', extra: b),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFEEF1F5)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(14), bottomLeft: Radius.circular(14)),
                child: _thumb(b),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(b.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700, color: _ink, height: 1.25)),
                      const SizedBox(height: 5),
                      if (phone.isNotEmpty)
                        Text(phone,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600, color: _blue)),
                      const SizedBox(height: 8),
                      _chip(classifiedCategoryLabel(b.category)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
            color: const Color(0xFFEFF3F8), borderRadius: BorderRadius.circular(20)),
        child: Text(label,
            style: const TextStyle(fontSize: 11.5, color: _ink, fontWeight: FontWeight.w500)),
      );

  Widget _thumb(ClassifiedPost b) {
    if (b.photos.isNotEmpty) {
      try {
        return Image.memory(base64Decode(b.photos.first),
            width: 104, height: 104, fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _thumbFallback());
      } catch (_) {}
    }
    return _thumbFallback();
  }

  Widget _thumbFallback() => Container(
      width: 104, height: 104, color: const Color(0xFFEFF3F8),
      child: const Icon(Icons.image_rounded, color: _blue, size: 32));

  Widget _empty() => Container(
        padding: const EdgeInsets.all(24),
        alignment: Alignment.center,
        child: const Text('No classifieds yet. Tap "Add Ads" to post the first one!',
            textAlign: TextAlign.center,
            style: TextStyle(color: _muted)),
      );
}
