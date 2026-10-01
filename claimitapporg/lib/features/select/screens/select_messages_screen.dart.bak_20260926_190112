import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/select_chat.dart';
import '../services/select_service.dart';
import '../widgets/select_common.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Claimit Select — Messages tab.
//
// Every chat the user is part of, whether they started it as a customer or
// received it on their own listing. Tapping one opens the thread.
// ─────────────────────────────────────────────────────────────────────────────

class SelectMessagesScreen extends StatefulWidget {
  const SelectMessagesScreen({super.key});

  @override
  State<SelectMessagesScreen> createState() => _SelectMessagesScreenState();
}

class _SelectMessagesScreenState extends State<SelectMessagesScreen> {
  bool _loading = true;
  List<SelectConversation> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final items = await SelectService.instance.fetchConversations();
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  Future<void> _open(SelectConversation c) async {
    await context.push('/select/chat', extra: c);
    // Coming back from a thread: unread counts / last message will have moved.
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSelBg,
      bottomNavigationBar: const SelectBottomNav(current: 2),
      body: Column(
        children: [
          _blueHeader(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: kSelAccent))
                : _items.isEmpty
                    ? SelEmptyState(
                        icon: Icons.chat_bubble_outline_rounded,
                        title: 'No messages yet',
                        message:
                            'Tap Enquire on any professional to start a chat. '
                            'Your conversations show up here.',
                        action: ElevatedButton(
                          onPressed: () => context.go('/select'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kSelYellow,
                            foregroundColor: kSelOnYellow,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 22, vertical: 12),
                          ),
                          child: const Text('Find a professional'),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        color: kSelAccent,
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: _items.length,
                          separatorBuilder: (_, __) => const Divider(
                              height: 1, indent: 78, color: kSelLine),
                          itemBuilder: (_, i) => _ConversationTile(
                            convo: _items[i],
                            onTap: () => _open(_items[i]),
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _blueHeader() {
    return Container(
      width: double.infinity,
      color: kSelYellow,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 4, 16, 12),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: kSelOnYellow),
                onPressed: () => context.go('/select'),
              ),
              const Expanded(
                child: Text(
                  'Messages',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: kSelOnYellow,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({required this.convo, required this.onTap});

  final SelectConversation convo;
  final VoidCallback onTap;

  /// "14:32" today, otherwise "12 Aug".
  String get _stamp {
    if (convo.lastMessageAt.trim().isEmpty) return '';
    final dt = DateTime.tryParse(convo.lastMessageAt);
    if (dt == null) return '';
    final local = dt.toLocal();
    final now = DateTime.now();
    if (local.year == now.year &&
        local.month == now.month &&
        local.day == now.day) {
      return '${local.hour.toString().padLeft(2, '0')}:'
          '${local.minute.toString().padLeft(2, '0')}';
    }
    const months = [
      'Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'
    ];
    return '${local.day} ${months[local.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    final unread = convo.unreadCount > 0;
    return InkWell(
      onTap: onTap,
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SelPhoto(
              url: convo.otherPhotoUrl,
              width: 50,
              height: 50,
              radius: 25,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          convo.otherName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight:
                                unread ? FontWeight.w800 : FontWeight.w700,
                            color: kSelInk,
                          ),
                        ),
                      ),
                      if (_stamp.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Text(
                          _stamp,
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight:
                                unread ? FontWeight.w700 : FontWeight.w400,
                            color: unread ? kSelAccent : kSelMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          convo.lastMessage.trim().isEmpty
                              ? 'Say hello'
                              : convo.lastMessage,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: unread ? kSelInk : kSelMuted,
                            fontWeight:
                                unread ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                      ),
                      if (unread) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: kSelAccent,
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: Text(
                            convo.unreadCount > 99
                                ? '99+'
                                : '${convo.unreadCount}',
                            maxLines: 1,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
