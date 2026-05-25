import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../models/policy_model.dart';
import '../providers/policy_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_formatter.dart';

class PoliciesScreen extends StatefulWidget {
  const PoliciesScreen({super.key});

  @override
  State<PoliciesScreen> createState() => _PoliciesScreenState();
}

class _PoliciesScreenState extends State<PoliciesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PolicyProvider>().fetchPolicies();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('My Policies'),
      ),
      body: Consumer<PolicyProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.policies.isEmpty) {
            return _buildEmptyState(context, provider);
          }

          return RefreshIndicator(
            onRefresh: provider.fetchPolicies,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: provider.policies.length,
              itemBuilder: (context, index) {
                final policy = provider.policies[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _PolicyCard(
                    policy: policy,
                    onTap: () => context.push('/policies/${policy.id}'),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, PolicyProvider provider) {
    return RefreshIndicator(
      onRefresh: provider.fetchPolicies,
      child: ListView(
        children: [
          // Responsive top gap — percentage-based so it centres correctly
          // on both small and large screens.
          Builder(builder: (ctx) => SizedBox(
            height: MediaQuery.of(ctx).size.height * 0.12,
          )),
          Icon(
            Icons.policy_outlined,
            size: 80,
            color: AppTheme.textSecondary.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          const Center(
            child: Text(
              'No Policies Yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Center(
            child: Text(
              'Add a policy to view its coverage and claim history',
              style: TextStyle(color: AppTheme.textSecondary),
              textAlign: TextAlign.center,
            ),
          ),
          if (provider.error != null) ...[
            const SizedBox(height: 16),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  provider.error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.errorColor, fontSize: 12),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PolicyCard extends StatelessWidget {
  final PolicyModel policy;
  final VoidCallback onTap;

  const _PolicyCard({required this.policy, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final daysToExpiry = policy.daysToExpiry;
    final isExpiringSoon = daysToExpiry < 60 && daysToExpiry >= 0;
    final isExpired = daysToExpiry < 0;

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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppTheme.secondaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.policy_rounded,
                    color: AppTheme.secondaryColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        policy.policyType,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        policy.insurerName,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: (isExpired ? AppTheme.errorColor : AppTheme.successColor)
                        .withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isExpired ? 'Expired' : 'Active',
                    style: TextStyle(
                      color: isExpired ? AppTheme.errorColor : AppTheme.successColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Sum Insured',
                      style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      DateFormatter.formatCurrency(policy.sumInsured),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      isExpired ? 'Expired' : 'Expires in',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isExpired
                          ? '${-daysToExpiry} days ago'
                          : '$daysToExpiry days',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isExpired
                            ? AppTheme.errorColor
                            : (isExpiringSoon
                                ? AppTheme.warningColor
                                : AppTheme.textPrimary),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (isExpiringSoon) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.warningColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: const [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: AppTheme.warningColor,
                      size: 16,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Policy expiring soon. Renew now!',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
