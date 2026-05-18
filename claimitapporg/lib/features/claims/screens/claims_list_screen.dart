import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/claims_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../shared/widgets/status_badge.dart';

class ClaimsListScreen extends StatefulWidget {
  const ClaimsListScreen({super.key});

  @override
  State<ClaimsListScreen> createState() => _ClaimsListScreenState();
}

class _ClaimsListScreenState extends State<ClaimsListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ClaimsProvider>().fetchClaims();
    });
  }

  final List<Map<String, String>> _filters = [
    {'label': 'All', 'value': 'all'},
    {'label': 'Pending', 'value': 'pending'},
    {'label': 'Under Review', 'value': 'under_review'},
    {'label': 'Approved', 'value': 'approved'},
    {'label': 'Rejected', 'value': 'rejected'},
    {'label': 'Settled', 'value': 'settled'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('My Claims'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips
          Consumer<ClaimsProvider>(
            builder: (context, provider, _) {
              return Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: _filters.map((filter) {
                      final isSelected = provider.filterStatus == filter['value'];
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(filter['label']!),
                          selected: isSelected,
                          onSelected: (_) =>
                              provider.setFilter(filter['value']!),
                          selectedColor: AppTheme.secondaryColor.withOpacity(0.15),
                          checkmarkColor: AppTheme.secondaryColor,
                          labelStyle: TextStyle(
                            color: isSelected
                                ? AppTheme.secondaryColor
                                : AppTheme.textSecondary,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                          side: BorderSide(
                            color: isSelected
                                ? AppTheme.secondaryColor
                                : AppTheme.dividerColor,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              );
            },
          ),

          // Claims List
          Expanded(
            child: Consumer<ClaimsProvider>(
              builder: (context, provider, _) {
                if (provider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (provider.claims.isEmpty) {
                  return _buildEmptyState(context);
                }

                return RefreshIndicator(
                  onRefresh: () => provider.fetchClaims(),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: provider.claims.length,
                    itemBuilder: (context, index) {
                      final claim = provider.claims[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _ClaimListItem(
                          claim: claim,
                          onTap: () => context.push('/claims/${claim.id}'),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.assignment_outlined,
            size: 80,
            color: AppTheme.textSecondary.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          const Text(
            'No Claims Found',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'You haven\'t filed any claims yet',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => context.push('/claims/new'),
            icon: const Icon(Icons.add),
            label: const Text('File New Claim'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(180, 48),
            ),
          ),
        ],
      ),
    );
  }
}

class _ClaimListItem extends StatelessWidget {
  final dynamic claim;
  final VoidCallback onTap;

  const _ClaimListItem({required this.claim, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _getTypeColor(claim.claimType).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getTypeIcon(claim.claimType),
                    color: _getTypeColor(claim.claimType),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        claim.claimNumber,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        claim.claimType,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                StatusBadge(status: claim.status),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _InfoChip(
                  icon: Icons.calendar_today_outlined,
                  label: DateFormatter.formatDate(claim.submittedAt),
                ),
                _InfoChip(
                  icon: Icons.currency_rupee_rounded,
                  label: DateFormatter.formatCurrency(claim.claimAmount),
                ),
                _InfoChip(
                  icon: Icons.description_outlined,
                  label: '${claim.documents.length} docs',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'health insurance':
        return const Color(0xFF10B981);
      case 'motor insurance':
        return const Color(0xFF3B82F6);
      case 'home insurance':
        return const Color(0xFFF59E0B);
      case 'life insurance':
        return const Color(0xFF8B5CF6);
      default:
        return AppTheme.secondaryColor;
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'health insurance':
        return Icons.health_and_safety_rounded;
      case 'motor insurance':
        return Icons.directions_car_rounded;
      case 'home insurance':
        return Icons.home_rounded;
      case 'life insurance':
        return Icons.favorite_rounded;
      default:
        return Icons.shield_rounded;
    }
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppTheme.textSecondary),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }
}
