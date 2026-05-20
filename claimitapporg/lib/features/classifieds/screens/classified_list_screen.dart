import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/classified_post.dart';
import '../services/classified_service.dart';

class ClassifiedListScreen extends StatefulWidget {
  final String category;
  final String subcategory;
  final String title;

  const ClassifiedListScreen({
    super.key,
    required this.category,
    required this.subcategory,
    required this.title,
  });

  @override
  State<ClassifiedListScreen> createState() => _ClassifiedListScreenState();
}

class _ClassifiedListScreenState extends State<ClassifiedListScreen> {
  List<ClassifiedPost> _all = [];
  List<ClassifiedPost> _filtered = [];
  bool _loading = true;

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
    });
  }

  String get _displayTitle {
    if (widget.title.isNotEmpty) return widget.title;
    if (widget.subcategory.isNotEmpty) return widget.subcategory;
    return 'Classifieds';
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
            : Text(
                'Classified',
                style: const TextStyle(
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
            onPressed: () => context.push('/classified/add'),
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
                // ── "Top N SUBCATEGORY" title ──────────────────────────────
                Padding(
                  padding:
                      const EdgeInsets.fromLTRB(16, 16, 16, 8),
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
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
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
                                onPressed: () =>
                                    context.push('/classified/add'),
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
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                            itemCount: _filtered.length,
                            itemBuilder: (context, i) => GestureDetector(
                              onTap: () => context.push(
                                '/classified/detail',
                                extra: _filtered[i],
                              ),
                              child: _WorkerCard(post: _filtered[i]),
                            ),
                          ),
                        ),
                ),
              ],
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Worker/service provider card
// ─────────────────────────────────────────────────────────────────────────────

class _WorkerCard extends StatelessWidget {
  const _WorkerCard({required this.post});
  final ClassifiedPost post;

  Color _avatarColor(String name) {
    final colors = [
      const Color(0xFF2563EB), const Color(0xFF059669), const Color(0xFFD97706),
      const Color(0xFFDC2626), const Color(0xFF7C3AED), const Color(0xFF0891B2),
    ];
    final index = name.isEmpty ? 0 : name.codeUnitAt(0) % colors.length;
    return colors[index];
  }

  @override
  Widget build(BuildContext context) {
    final hasPhoto = post.photos.isNotEmpty && post.photos.first.isNotEmpty;
    final initials = post.userName.isNotEmpty
        ? post.userName[0].toUpperCase()
        : '?';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Avatar ───────────────────────────────────────────────────
            ClipOval(
              child: hasPhoto
                  ? Image.memory(
                      base64Decode(post.photos.first),
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          _InitialsAvatar(initials: initials, color: _avatarColor(post.userName)),
                    )
                  : _InitialsAvatar(
                      initials: initials,
                      color: _avatarColor(post.userName),
                    ),
            ),
            const SizedBox(width: 12),

            // ── Info ─────────────────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post.userName.toUpperCase(),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Color(0xFF1E293B),
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    post.address.isNotEmpty ? post.address : post.area,
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF64748B), height: 1.4),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      // Experience badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          post.yearsOfExp > 0
                              ? '${post.yearsOfExp}+ Exp'
                              : 'Experienced',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF475569),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const Spacer(),
                      // Availability
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: post.isAvailable
                                  ? const Color(0xFF22C55E)
                                  : Colors.grey,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            post.isAvailable ? 'Available' : 'Unavailable',
                            style: TextStyle(
                              fontSize: 12,
                              color: post.isAvailable
                                  ? const Color(0xFF22C55E)
                                  : Colors.grey,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Star / bookmark ──────────────────────────────────────────
            const Padding(
              padding: EdgeInsets.only(left: 8),
              child: Icon(Icons.star_rounded,
                  color: Color(0xFFFBBF24), size: 22),
            ),
          ],
        ),
      ),
    );
  }
}

class _InitialsAvatar extends StatelessWidget {
  const _InitialsAvatar({required this.initials, required this.color});
  final String initials;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      color: color,
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
