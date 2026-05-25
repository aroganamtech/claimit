import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class StatusBadge extends StatelessWidget {
  final String status;

  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final config = _getConfig(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: config['bg'] as Color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        config['label'] as String,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: config['text'] as Color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Map<String, dynamic> _getConfig(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return {
          'bg': AppTheme.pendingColor,
          'text': AppTheme.pendingTextColor,
          'label': 'Pending',
        };
      case 'under_review':
        return {
          'bg': const Color(0xFFDBEAFE),
          'text': const Color(0xFF1E40AF),
          'label': 'Under Review',
        };
      case 'approved':
        return {
          'bg': AppTheme.approvedColor,
          'text': AppTheme.approvedTextColor,
          'label': 'Approved',
        };
      case 'rejected':
        return {
          'bg': AppTheme.rejectedColor,
          'text': AppTheme.rejectedTextColor,
          'label': 'Rejected',
        };
      case 'settled':
        return {
          'bg': const Color(0xFFEDE9FE),
          'text': const Color(0xFF5B21B6),
          'label': 'Settled',
        };
      default:
        return {
          'bg': AppTheme.dividerColor,
          'text': AppTheme.textSecondary,
          'label': status,
        };
    }
  }
}
