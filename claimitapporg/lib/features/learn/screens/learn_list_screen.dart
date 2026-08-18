import 'package:flutter/material.dart';

import '../models/learn_item.dart';
import '../services/learn_service.dart';
import 'learn_video_screen.dart';

/// "Learn Claimit" — list of how-to-use-the-app questions. Admin adds these
/// (question + video) from the web panel; tapping a question opens its
/// answer video (see [LearnVideoScreen]).
class LearnListScreen extends StatefulWidget {
  const LearnListScreen({super.key});

  @override
  State<LearnListScreen> createState() => _LearnListScreenState();
}

class _LearnListScreenState extends State<LearnListScreen> {
  bool _loading = true;
  List<LearnItem> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await LearnService.instance.fetchItems();
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Learn Claimit'),
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    children: const [
                      Padding(
                        padding: EdgeInsets.only(top: 120),
                        child: Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 32),
                            child: Text(
                              'No lessons available yet. Check back soon!',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.black54),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, i) {
                      final item = _items[i];
                      return _LearnCard(
                        item: item,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => LearnVideoScreen(item: item),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

class _LearnCard extends StatelessWidget {
  const _LearnCard({required this.item, required this.onTap});
  final LearnItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: Color(0xFFEFF6FF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_circle_fill_rounded,
                  color: Color(0xFF1565C0),
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item.question,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 8),
              if (item.likeCount > 0) ...[
                const Icon(Icons.favorite_rounded, color: Colors.redAccent, size: 14),
                const SizedBox(width: 3),
                Text(
                  '${item.likeCount}',
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(width: 8),
              ],
              const Icon(Icons.chevron_right_rounded, color: Colors.black38),
            ],
          ),
        ),
      ),
    );
  }
}
