import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/classified_post.dart';
import '../services/classified_service.dart';
import '../widgets/listing_flow_widgets.dart';

const Color _navy = Color(0xFF1E3A5F);

// ─────────────────────────────────────────────────────────────────────────────
// Shows the current user's own posts (Local Finds business listings +
// Local Classifieds posts) with edit / delete / availability toggle.
// Only the owner ever sees their own posts here — the backend enforces this
// (GET /classifieds/mine is scoped to the signed-in user, and PATCH/DELETE
// both check ownership server-side too).
// ─────────────────────────────────────────────────────────────────────────────

class MyListingsScreen extends StatefulWidget {
  const MyListingsScreen({super.key});

  @override
  State<MyListingsScreen> createState() => _MyListingsScreenState();
}

class _MyListingsScreenState extends State<MyListingsScreen> {
  List<ClassifiedPost> _posts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final posts = await ClassifiedService.instance.fetchMyPosts();
    if (!mounted) return;
    setState(() {
      _posts = posts;
      _loading = false;
    });
  }

  Future<void> _toggleAvailability(ClassifiedPost post) async {
    final newStatus = await ClassifiedService.instance.toggleAvailability(post.id);
    if (newStatus != null) _load();
  }

  Future<void> _delete(ClassifiedPost post) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete listing?'),
        content: Text('This will permanently remove "${post.title.isNotEmpty ? post.title : post.businessName}".'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final ok = await ClassifiedService.instance.deletePost(post.id);
    if (ok) _load();
  }

  Future<void> _edit(ClassifiedPost post) async {
    final titleCtrl = TextEditingController(text: post.isLocalFind ? post.businessName : post.title);
    final descCtrl = TextEditingController(text: post.description);

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20, right: 20, top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ListingStepTitle('Edit listing'),
            const SizedBox(height: 16),
            ListingField(
              controller: titleCtrl,
              hint: post.isLocalFind ? 'Business name' : 'Title',
            ),
            const SizedBox(height: 12),
            WordLimitedField(controller: descCtrl, hint: 'Description (up to 25 words)'),
            const SizedBox(height: 20),
            ListingPrimaryButton(
              label: 'Save changes',
              onTap: () => Navigator.pop(ctx, true),
            ),
          ],
        ),
      ),
    );

    if (saved != true) return;
    final fields = <String, dynamic>{'description': descCtrl.text.trim()};
    if (post.isLocalFind) {
      fields['business_name'] = titleCtrl.text.trim();
    } else {
      fields['title'] = titleCtrl.text.trim();
    }
    final result = await ClassifiedService.instance.updatePost(post.id, fields);
    if (result != null) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _navy, size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'My Listings',
          style: TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.bold, fontSize: 17),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _navy))
          : _posts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.storefront_outlined, size: 56, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      Text("You haven't posted anything yet",
                          style: TextStyle(color: Colors.grey.shade500)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _posts.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) => _ListingCard(
                      post: _posts[i],
                      onToggle: () => _toggleAvailability(_posts[i]),
                      onEdit: () => _edit(_posts[i]),
                      onDelete: () => _delete(_posts[i]),
                    ),
                  ),
                ),
    );
  }
}

class _ListingCard extends StatelessWidget {
  const _ListingCard({
    required this.post,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });
  final ClassifiedPost post;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final heading = post.isLocalFind
        ? (post.businessName.isNotEmpty ? post.businessName : post.title)
        : post.title;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: post.isLocalFind ? const Color(0xFFFFF3E0) : const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  post.isLocalFind ? 'LOCAL FINDS' : 'CLASSIFIED',
                  style: TextStyle(
                    fontSize: 10, fontWeight: FontWeight.bold,
                    color: post.isLocalFind ? const Color(0xFFD97706) : const Color(0xFF2563EB),
                  ),
                ),
              ),
              const Spacer(),
              Switch(
                value: post.isAvailable,
                onChanged: (_) => onToggle(),
                activeColor: const Color(0xFF22C55E),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(heading.isEmpty ? '(untitled)' : heading,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1E293B))),
          if (post.description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(post.description,
                maxLines: 2, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              TextButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Edit'),
              ),
              TextButton.icon(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Colors.redAccent),
                label: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
