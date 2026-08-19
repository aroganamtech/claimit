import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/classified_categories.dart';
import '../models/classified_post.dart';
import '../services/classified_service.dart';

class ClassifiedListScreen extends StatefulWidget {
  final String category;
  final String subcategory;
  final String title;
  // "classified" = Local Classifieds items/services, "local_find" = Local
  // Finds business listings — determines which "add post" flow the + button
  // opens (LocalFindAddListingFlow vs AddPostFlowScreen).
  final String listingType;

  const ClassifiedListScreen({
    super.key,
    required this.category,
    required this.subcategory,
    required this.title,
    this.listingType = 'classified',
  });

  @override
  State<ClassifiedListScreen> createState() => _ClassifiedListScreenState();
}

class _ClassifiedListScreenState extends State<ClassifiedListScreen> {
  static const int _pageSize = 6;

  List<ClassifiedPost> _all = [];
  List<ClassifiedPost> _filtered = [];
  bool _loading = true;
  int _visibleCount = _pageSize;

  final _searchCtrl = TextEditingController();
  bool _showSearch = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final posts = await ClassifiedService.instance.fetchClassifieds(
      category: widget.category.isEmpty ? null : widget.category,
      subcategory: widget.subcategory.isEmpty ? null : widget.subcategory,
    );
    if (mounted) {
      setState(() {
        _all = posts;
        _filtered = posts;
        _loading = false;
        _visibleCount = _pageSize;
      });
    }
  }

  void _onSearch(String q) {
    final lower = q.toLowerCase();
    setState(() {
      _filtered = _all.where((p) {
        return p.userName.toLowerCase().contains(lower) ||
            p.title.toLowerCase().contains(lower) ||
            p.area.toLowerCase().contains(lower);
      }).toList();
      _visibleCount = _pageSize;
    });
  }

  String get _displayTitle {
    if (widget.title.isNotEmpty) return widget.title;
    if (widget.subcategory.isNotEmpty) return widget.subcategory;
    return 'Classifieds';
  }

  /// Other "Local Helpers" categories under the same parent group, used to
  /// power the small dropdown next to the title (e.g. switching from
  /// "Electrician" to "Plumbing" without going back to the grid).
  List<ClassifiedTopCategory> get _siblingHelperCategories {
    if (widget.subcategory.isEmpty) return const [];
    return localHelperCategories
        .where((c) => c.category == widget.category)
        .toList();
  }

  /// Opens the right "add post" flow: the Local Finds business registration
  /// flow when browsing a Local Finds zone, otherwise the Local Classifieds
  /// posting flow.
  void _openAddFlow() {
    if (widget.listingType == 'local_find') {
      LocalFindZone? zone;
      try {
        zone = localFindZones.firstWhere((z) => z.id == widget.category);
      } catch (_) {
        zone = null;
      }
      // Pass the subcategory the user is already browsing (e.g. "Grocery")
      // so the new listing lands in the SAME filtered list instead of
      // asking them to pick it again — and, critically, so it actually
      // gets saved with a non-empty subcategory that matches this filter.
      context.push('/local-finds/add', extra: {
        'zone': zone,
        'subcategory': widget.subcategory.isEmpty ? null : widget.subcategory,
      });
    } else {
      context.push('/classified/add');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Color(0xFF1E40AF), size: 20),
          onPressed: () => context.pop(),
        ),
        title: _showSearch
            ? TextField(
                controller: _searchCtrl,
                autofocus: true,
                onChanged: _onSearch,
                decoration: const InputDecoration(
                  hintText: 'Search...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Colors.grey),
                ),
              )
            : const Text(
                'Classified',
                style: TextStyle(
                  color: Color(0xFF1E293B),
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
        actions: [
          // Filter
          IconButton(
            icon: const Icon(Icons.tune_rounded, color: Color(0xFF1E40AF)),
            onPressed: () {},
          ),
          // Search
          IconButton(
            icon: Icon(
              _showSearch ? Icons.close_rounded : Icons.search_rounded,
              color: const Color(0xFF1E40AF),
            ),
            onPressed: () {
              setState(() {
                _showSearch = !_showSearch;
                if (!_showSearch) {
                  _searchCtrl.clear();
                  _filtered = _all;
                  _visibleCount = _pageSize;
                }
              });
            },
          ),
          // Add post
          IconButton(
            icon: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
            ),
            onPressed: _openAddFlow,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF2563EB)))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── "Top N TITLE [v]" header row ────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            style: const TextStyle(
                                fontSize: 18, color: Color(0xFF1E293B)),
                            children: [
                              const TextSpan(
                                text: 'Top ',
                                style: TextStyle(fontWeight: FontWeight.w500),
                              ),
                              TextSpan(
                                text: '${_filtered.length} ',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2563EB)),
                              ),
                              TextSpan(
                                text: _displayTitle.toUpperCase(),
                                style:
                                    const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_siblingHelperCategories.length > 1)
                        PopupMenuButton<ClassifiedTopCategory>(
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.keyboard_arrow_down_rounded,
                              color: Color(0xFF1E293B)),
                          onSelected: (c) => context.pushReplacement(
                            '/classified/list',
                            extra: {
                              'category': c.category,
                              'subcategory': c.subcategory,
                              'title': c.name,
                            },
                          ),
                          itemBuilder: (context) => _siblingHelperCategories
                              .map((c) => PopupMenuItem(
                                    value: c,
                                    child: Text(c.name),
                                  ))
                              .toList(),
                        ),
                    ],
                  ),
                ),

                // ── List ──────────────────────────────────────────────────
                Expanded(
                  child: _filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.search_off_rounded,
                                  size: 56, color: Colors.grey.shade300),
                              const SizedBox(height: 12),
                              Text(
                                'No listings found',
                                style: TextStyle(color: Colors.grey.shade500),
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton.icon(
                                onPressed: _openAddFlow,
                                icon: const Icon(Icons.add_rounded),
                                label: const Text('Post First Ad'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2563EB),
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _load,
                          color: const Color(0xFF2563EB),
                          child: _buildList(),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildList() {
    final visible = _filtered.take(_visibleCount).toList();
    final remaining = _filtered.length - visible.length;
    final hasMore = remaining > 0;

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: visible.length + (hasMore ? 1 : 0),
      separatorBuilder: (context, i) =>
          const Divider(color: Color(0xFFE2E8F0), height: 1),
      itemBuilder: (context, i) {
        if (i == visible.length) {
          return Padding(
            padding: const EdgeInsets.only(top: 12),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () =>
                    setState(() => _visibleCount += _pageSize),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                child: Text('Load more $remaining+'),
              ),
            ),
          );
        }
        final post = visible[i];
        return GestureDetector(
          onTap: () => context.push('/classified/detail', extra: post),
          child: _ListingRow(post: post),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Flat listing row — title / area / description (or experience) + call & chat
// ─────────────────────────────────────────────────────────────────────────────

class _ListingRow extends StatelessWidget {
  const _ListingRow({required this.post});
  final ClassifiedPost post;

  Future<void> _call() async {
    if (post.userPhone.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: post.userPhone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _whatsapp() async {
    if (post.userPhone.isEmpty) return;
    final phone = post.userPhone.replaceAll(RegExp(r'[^0-9]'), '');
    final uri = Uri.parse('https://wa.me/91$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final heading = post.title.isNotEmpty ? post.title : post.userName;
    final descLine = post.description.isNotEmpty
        ? post.description
        : (post.yearsOfExp > 0 ? '${post.yearsOfExp}+ Exp' : '');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  heading,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Color(0xFF1E293B),
                  ),
                ),
                if (post.area.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    post.area,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF2563EB),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                if (descLine.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    descLine,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                      height: 1.3,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          _ActionIcon(icon: Icons.call_rounded, onTap: _call),
          const SizedBox(width: 8),
          _ActionIcon(icon: Icons.chat_bubble_rounded, onTap: _whatsapp),
        ],
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  const _ActionIcon({required this.icon, required this.onTap});
  final IconData icon;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: const Color(0xFFD1FAE5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 17, color: const Color(0xFF059669)),
      ),
    );
  }
}
