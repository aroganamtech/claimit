import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../models/feedback_model.dart';
import '../services/feedback_service.dart';

/// Feedback & Complaints — submission form + history of past submissions
/// with their status and any admin reply. Styled to match SettingsScreen.
class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  static const _bg = Color(0xFFF5F5F5);
  static const _ink = Color(0xFF1A1A2E);
  static const _accent = Color(0xFF2563EB);

  late Future<List<FeedbackModel>> _future;

  @override
  void initState() {
    super.initState();
    _future = FeedbackService.instance.fetchMyFeedback();
  }

  Future<void> _refresh() async {
    final next = FeedbackService.instance.fetchMyFeedback();
    setState(() => _future = next);
    await next;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => context.pop(),
          child: const Icon(Icons.arrow_back_ios_new_rounded,
              size: 26, color: _ink),
        ),
        title: const Text(
          'Feedback & Complaints',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: _ink,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openSubmitSheet,
        backgroundColor: _accent,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('New', style: TextStyle(color: Colors.white)),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<FeedbackModel>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: _accent));
            }
            if (snap.hasError) {
              return _errorState(snap.error.toString());
            }
            final items = snap.data ?? [];
            if (items.isEmpty) return _emptyState();
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: items.length,
              itemBuilder: (context, i) => _FeedbackCard(item: items[i]),
            );
          },
        ),
      ),
    );
  }

  Widget _emptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(32),
      children: [
        const SizedBox(height: 80),
        const Icon(Icons.feedback_outlined, size: 64, color: Color(0xFF9CA3AF)),
        const SizedBox(height: 16),
        const Center(
          child: Text(
            'No feedback yet',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _ink),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 6),
        const Center(
          child: Text(
            'Tap "New" to send feedback, report a complaint,\nor share a suggestion with us.',
            style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _errorState(String message) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(32),
      children: [
        const SizedBox(height: 80),
        const Icon(Icons.error_outline_rounded, size: 56, color: Color(0xFF9CA3AF)),
        const SizedBox(height: 16),
        Center(
          child: Text(
            message,
            style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  void _openSubmitSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SubmitFeedbackSheet(onSubmitted: _refresh),
    );
  }
}

class _FeedbackCard extends StatelessWidget {
  final FeedbackModel item;
  const _FeedbackCard({required this.item});

  static const _ink = Color(0xFF1A1A2E);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _categoryBadge(item.category),
              const SizedBox(width: 8),
              _statusBadge(item.status),
              const Spacer(),
              Text(
                DateFormat('dd MMM yyyy').format(item.createdAt),
                style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            item.subject,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _ink),
          ),
          const SizedBox(height: 6),
          Text(
            item.message,
            style: const TextStyle(fontSize: 13, color: Color(0xFF4B5563), height: 1.4),
          ),
          if (item.hasReply) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFDBEAFE)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.support_agent_rounded, size: 16, color: Color(0xFF2563EB)),
                      SizedBox(width: 6),
                      Text(
                        'Reply from support',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF2563EB)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.adminReply!,
                    style: const TextStyle(fontSize: 13, color: Color(0xFF1A1A2E), height: 1.4),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _categoryBadge(String category) {
    final label = category[0].toUpperCase() + category.substring(1);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF4B5563)),
      ),
    );
  }

  Widget _statusBadge(String status) {
    Color color;
    switch (status) {
      case 'replied':
        color = const Color(0xFF16A34A);
        break;
      case 'closed':
        color = const Color(0xFF6B7280);
        break;
      default:
        color = const Color(0xFFEA580C);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status[0].toUpperCase() + status.substring(1),
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}

class _SubmitFeedbackSheet extends StatefulWidget {
  final Future<void> Function() onSubmitted;
  const _SubmitFeedbackSheet({required this.onSubmitted});

  @override
  State<_SubmitFeedbackSheet> createState() => _SubmitFeedbackSheetState();
}

class _SubmitFeedbackSheetState extends State<_SubmitFeedbackSheet> {
  static const _ink = Color(0xFF1A1A2E);
  static const _accent = Color(0xFF2563EB);

  final _subjectCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  String _category = 'feedback';
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final subject = _subjectCtrl.text.trim();
    final message = _messageCtrl.text.trim();
    if (subject.isEmpty || message.isEmpty) {
      setState(() => _error = 'Please fill in both subject and message.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await FeedbackService.instance.submitFeedback(
        category: _category,
        subject: subject,
        message: message,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      await widget.onSubmitted();
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Send feedback',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: _ink),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                children: [
                  _categoryChip('feedback', 'Feedback'),
                  _categoryChip('complaint', 'Complaint'),
                  _categoryChip('suggestion', 'Suggestion'),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _subjectCtrl,
                maxLength: 150,
                decoration: InputDecoration(
                  labelText: 'Subject',
                  filled: true,
                  fillColor: const Color(0xFFF5F5F5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _messageCtrl,
                maxLength: 2000,
                maxLines: 5,
                decoration: InputDecoration(
                  labelText: 'Message',
                  filled: true,
                  fillColor: const Color(0xFFF5F5F5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: Color(0xFFE53935), fontSize: 12)),
              ],
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accent,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Submit', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _categoryChip(String value, String label) {
    final selected = _category == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _category = value),
      selectedColor: _accent.withOpacity(0.12),
      backgroundColor: const Color(0xFFF5F5F5),
      labelStyle: TextStyle(
        color: selected ? _accent : const Color(0xFF4B5563),
        fontWeight: FontWeight.w600,
        fontSize: 12,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: selected ? _accent : const Color(0xFFE5E7EB)),
      ),
    );
  }
}
