import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_format.dart';
import '../../../core/utils/l10n_context.dart';
import '../../../core/widgets/app_card.dart';
import '../../../domain/entities/finance_data.dart';
import '../../../domain/services/finance_calculations.dart';
import '../../../domain/services/financial_health_calculator.dart';
import '../../../providers/finance_providers.dart';
import 'widgets/finance_widgets.dart';

/// The Finance tab root: a hub linking the finance features together.
class FinanceOverviewScreen extends ConsumerWidget {
  const FinanceOverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(financeControllerProvider);

    return Scaffold(
      body: SafeArea(
        child: asyncData.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _FinanceErrorView(
            message: context.l10n.errorTitle,
            onRetry: () => ref.invalidate(financeControllerProvider),
          ),
          data: (data) => _FinanceOverviewContent(data: data),
        ),
      ),
    );
  }
}

class _FinanceOverviewContent extends ConsumerWidget {
  const _FinanceOverviewContent({required this.data});

  final FinanceData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final now = DateTime.now();
    final income = FinanceCalculations.monthlyIncome(data.transactions, now);
    final expenses =
        FinanceCalculations.monthlyExpenses(data.transactions, now);
    final savings = income - expenses;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.tabFinance,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            const DemoDataBadge(),
          ],
        ),
        const SizedBox(height: 16),

        // Financial Health — the headline card, links to the breakdown.
        _HealthCard(income: income, expenses: expenses),
        const SizedBox(height: 16),

        // This month at a glance.
        Text(l10n.thisMonth, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: StatTile(
                label: l10n.income,
                value: CurrencyFormat.pkr(income),
                icon: Icons.south_west_rounded,
                color: AppColors.teal,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: StatTile(
                label: l10n.expenses,
                value: CurrencyFormat.pkr(expenses),
                icon: Icons.north_east_rounded,
                color: AppColors.danger,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: StatTile(
                label: l10n.savings,
                value: CurrencyFormat.pkr(savings),
                icon: Icons.savings_rounded,
                color: AppColors.mint,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Feature navigation.
        Row(
          children: [
            Expanded(
              child: _NavCard(
                icon: Icons.account_balance_wallet_rounded,
                title: l10n.navMyFinancesTitle,
                description: l10n.navMyFinancesDesc,
                onTap: () => context.push('/finance/finances'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _NavCard(
                icon: Icons.receipt_long_rounded,
                title: l10n.navExpensesTitle,
                description: l10n.navExpensesDesc,
                onTap: () => context.push('/finance/expenses'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _NavCard(
                icon: Icons.data_usage_rounded,
                title: l10n.navBudgetTitle,
                description: l10n.navBudgetDesc,
                onTap: () => context.push('/finance/budget'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _NavCard(
                icon: Icons.flag_rounded,
                title: l10n.navGoalsTitle,
                description: l10n.navGoalsDesc,
                onTap: () => context.push('/finance/goals'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _HealthCard extends ConsumerWidget {
  const _HealthCard({required this.income, required this.expenses});

  final double income;
  final double expenses;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final health = ref.watch(financialHealthProvider);

    return AppCard(
      onTap: () => context.push('/finance/health'),
      child: Row(
        children: [
          ScoreRing(score: health?.score ?? 0, size: 96, strokeWidth: 10),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.healthScoreTitle,
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  health == null
                      ? l10n.thisMonth
                      : switch (health.rating) {
                          HealthRating.excellent => l10n.ratingExcellent,
                          HealthRating.good => l10n.ratingGood,
                          HealthRating.fair => l10n.ratingFair,
                          HealthRating.needsAttention =>
                            l10n.ratingNeedsAttention,
                        },
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: healthColor(context, health?.score ?? 0),
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.navHealthDesc,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}

class _NavCard extends StatelessWidget {
  const _NavCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: scheme.primary),
          ),
          const SizedBox(height: 12),
          Text(title,
              style: theme.textTheme.titleSmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Text(
            description,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.25,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _FinanceErrorView extends StatelessWidget {
  const _FinanceErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 48, color: AppColors.danger),
            const SizedBox(height: 16),
            Text(message, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: Text(l10n.retryAction)),
          ],
        ),
      ),
    );
  }
}
