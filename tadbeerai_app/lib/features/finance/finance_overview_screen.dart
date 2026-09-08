import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_format.dart';
import '../../../core/utils/l10n_context.dart';
import '../../../core/widgets/app_canvas.dart';
import '../../../core/widgets/app_card.dart';
import '../../../domain/entities/finance_data.dart';
import '../../../domain/entities/financial_profile.dart';
import '../../../domain/entities/transaction.dart';
import '../../../domain/services/finance_calculations.dart';
import '../../../domain/services/financial_health_calculator.dart';
import '../../../providers/finance_providers.dart';
import '../../../providers/profile_providers.dart';
import 'finance_category_visuals.dart';
import 'widgets/finance_widgets.dart';
import 'widgets/transaction_form_sheet.dart';

/// The Finance tab root: modern fintech command center linking health,
/// cash flow, budget envelopes, savings goals, and recent activity.
class FinanceOverviewScreen extends ConsumerWidget {
  const FinanceOverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(financeControllerProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.navyBg : Colors.transparent,
      body: AppCanvas(
        useSafeArea: true,
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final now = DateTime.now();

    final profile = ref.watch(financialProfileControllerProvider).valueOrNull;
    final health = ref.watch(financialHealthProvider);

    // Monthly cash flow figures (reconciled with profile baseline if available)
    final txIncome = FinanceCalculations.monthlyIncome(data.transactions, now);
    final txExpenses =
        FinanceCalculations.monthlyExpenses(data.transactions, now);

    final monthIncome =
        (profile?.monthlyIncome != null && profile!.monthlyIncome! > 0)
            ? profile.monthlyIncome!
            : txIncome;
    final monthExpenses = (profile?.monthlyEssentialExpenses != null &&
            profile!.monthlyEssentialExpenses! > 0)
        ? profile.monthlyEssentialExpenses!
        : txExpenses;

    final netMonthlyCashFlow = monthIncome - monthExpenses;

    // Liquid savings reserve (all-time)
    final currentSavings =
        (profile?.totalSavings != null && profile!.totalSavings! > 0)
            ? profile.totalSavings!
            : FinanceCalculations.currentSavings(
                data.openingSavingsBalance, data.transactions);

    // Budget utilization metrics
    final spentByCategory =
        FinanceCalculations.spentByCategory(data.transactions, now);
    final onTrackBudgets = data.budgets
        .where((b) => (spentByCategory[b.category] ?? 0) <= b.monthlyLimit)
        .length;
    final totalBudgetLimit =
        data.budgets.fold<double>(0, (sum, b) => sum + b.monthlyLimit);
    final totalBudgetSpent = data.budgets.fold<double>(
      0,
      (sum, b) => sum + (spentByCategory[b.category] ?? 0),
    );
    final budgetUtilization =
        totalBudgetLimit > 0 ? totalBudgetSpent / totalBudgetLimit : 0.0;

    // Goals metrics
    final activeGoalsCount = data.goals.length;
    final topGoal = data.goals.isNotEmpty ? data.goals.first : null;
    final topGoalStatus =
        topGoal != null ? FinanceCalculations.goalStatus(topGoal, now) : null;

    // Monthly expense transaction count
    final monthExpenseCount = data.transactions
        .where((t) =>
            t.type == TransactionType.expense &&
            t.date.year == now.year &&
            t.date.month == now.month)
        .length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        // ── 1. Modern Header & Quick Action ───────────────────────────────
        _FinanceHeader(profile: profile),
        const SizedBox(height: 16),

        // ── 2. Financial Resilience Scorecard ─────────────────────────────
        _HealthScorecard(
          health: health,
          profile: profile,
          isDark: isDark,
        ),
        const SizedBox(height: 16),

        // ── 3. Monthly Cash Flow Snapshot ─────────────────────────────────
        _MonthlyCashFlowCard(
          monthIncome: monthIncome,
          monthExpenses: monthExpenses,
          netMonthlyCashFlow: netMonthlyCashFlow,
          now: now,
          isDark: isDark,
        ),
        const SizedBox(height: 22),

        // ── 4. Operational Hub Modules (2x2 Grid) ─────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Finance Tools',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
            ),
            Text(
              'Live Status',
              style: theme.textTheme.labelSmall?.copyWith(
                color: isDark
                    ? AppColors.textOnDarkTertiary
                    : AppColors.textOnLightSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _HubModuleCard(
                icon: Icons.account_balance_wallet_rounded,
                accentColor: isDark ? AppColors.teal : const Color(0xFF0D9488),
                title: l10n.navMyFinancesTitle,
                metric: CurrencyFormat.pkr(currentSavings),
                caption: 'Liquid Reserve',
                badgeText: 'Net Position',
                onTap: () => context.push('/finance/finances'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _HubModuleCard(
                icon: Icons.receipt_long_rounded,
                accentColor:
                    isDark ? AppColors.danger : const Color(0xFFDC2626),
                title: l10n.navExpensesTitle,
                metric: CurrencyFormat.pkr(monthExpenses),
                caption: monthExpenseCount > 0
                    ? '$monthExpenseCount logged'
                    : 'No entries yet',
                badgeText: 'This Month',
                onTap: () => context.push('/finance/expenses'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _HubModuleCard(
                icon: Icons.donut_large_rounded,
                accentColor: const Color(0xFF38BDF8),
                title: l10n.navBudgetTitle,
                metric: data.budgets.isEmpty
                    ? 'No Limits'
                    : '$onTrackBudgets of ${data.budgets.length} On Track',
                caption: data.budgets.isEmpty
                    ? 'Set category caps'
                    : 'Cap: ${CurrencyFormat.pkr(totalBudgetLimit)}',
                badgeText: 'Envelopes',
                progress: data.budgets.isNotEmpty ? budgetUtilization : null,
                progressColor:
                    budgetUtilizationColor(context, budgetUtilization),
                onTap: () => context.push('/finance/budget'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _HubModuleCard(
                icon: Icons.flag_rounded,
                accentColor: isDark ? AppColors.mint : const Color(0xFF047857),
                title: l10n.navGoalsTitle,
                metric: activeGoalsCount == 0
                    ? 'No Goals'
                    : '$activeGoalsCount Target${activeGoalsCount == 1 ? '' : 's'}',
                caption: topGoal != null
                    ? '${topGoal.title} (${((topGoalStatus?.progress ?? 0) * 100).round()}%)'
                    : 'Create milestone',
                badgeText: 'Targets',
                progress: topGoalStatus?.progress,
                progressColor:
                    isDark ? AppColors.mint : const Color(0xFF047857),
                onTap: () => context.push('/finance/goals'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // ── 5. Recent Financial Activity ──────────────────────────────────
        _RecentTransactionsSection(
          transactions: data.transactions,
          onAddTransaction: () => _openTransactionForm(context, ref),
          onSelectTransaction: (tx) =>
              _openTransactionForm(context, ref, existing: tx),
          onViewAll: () => context.push('/finance/expenses'),
        ),
      ],
    );
  }

  Future<void> _openTransactionForm(
    BuildContext context,
    WidgetRef ref, {
    Transaction? existing,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: TransactionFormSheet(
          existing: existing,
          onSubmit: (transaction) async {
            final controller = ref.read(financeControllerProvider.notifier);
            if (existing == null) {
              await controller.addTransaction(transaction);
            } else {
              await controller.updateTransaction(transaction);
            }
          },
          onDelete: existing == null
              ? null
              : () => ref
                  .read(financeControllerProvider.notifier)
                  .deleteTransaction(existing.id),
        ),
      ),
    );
  }
}

// ── Header Widget ──────────────────────────────────────────────────────────
class _FinanceHeader extends ConsumerWidget {
  const _FinanceHeader({required this.profile});

  final FinancialProfile? profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final personaTitle = switch (profile?.persona) {
      Persona.salaried => 'Salaried Pro',
      Persona.student => 'Student',
      Persona.businessOwner => 'Business',
      Persona.shopOwner => 'Retailer',
      null => null,
    };

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Finance Hub',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Cash flow, resilience & wealth planning',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isDark
                      ? AppColors.textOnDarkTertiary
                      : AppColors.textOnLightSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        if (personaTitle != null)
          InkWell(
            onTap: () => context.push('/profile/financial'),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: (isDark ? AppColors.teal : const Color(0xFF0D9488))
                    .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: (isDark ? AppColors.teal : const Color(0xFF0D9488))
                      .withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.badge_outlined,
                    size: 13,
                    color: isDark ? AppColors.teal : const Color(0xFF0D9488),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    personaTitle,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: isDark ? AppColors.teal : const Color(0xFF0D9488),
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          const DemoDataBadge(),
      ],
    );
  }
}

// ── Financial Resilience Scorecard ─────────────────────────────────────────
class _HealthScorecard extends StatelessWidget {
  const _HealthScorecard({
    required this.health,
    required this.profile,
    required this.isDark,
  });

  final FinancialHealthResult? health;
  final FinancialProfile? profile;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final score = health?.score ?? 0;
    final color = healthColor(context, score);

    final ratingLabel = switch (health?.rating) {
      HealthRating.excellent => 'Excellent Resilience',
      HealthRating.good => 'Good Resilience',
      HealthRating.fair => 'Moderate Resilience',
      HealthRating.needsAttention || null => 'Needs Attention',
    };

    final savingsScore = health?.savingsComponent?.score ?? 0;
    final budgetScore = health?.budgetComponent?.score ?? 0;
    final emergencyScore = health?.emergencyComponent?.score ?? 0;

    return AppCard(
      onTap: () => context.push('/finance/health'),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ScoreRing(score: score, size: 74, strokeWidth: 8),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            ratingLabel,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: color,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 20,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '5-Pillar Health & Solvency Index',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: isDark
                            ? AppColors.textOnDarkSecondary
                            : AppColors.textOnLightSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Synced with live baseline & spending pace',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(
            height: 1,
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
          ),
          const SizedBox(height: 12),
          // 3 Micro-pillar indicators
          Row(
            children: [
              Expanded(
                child: _PillarMetricPill(
                  icon: Icons.savings_outlined,
                  title: 'Savings',
                  score: savingsScore,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _PillarMetricPill(
                  icon: Icons.pie_chart_outline_rounded,
                  title: 'Discipline',
                  score: budgetScore,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _PillarMetricPill(
                  icon: Icons.shield_outlined,
                  title: 'Buffer',
                  score: emergencyScore,
                  isDark: isDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PillarMetricPill extends StatelessWidget {
  const _PillarMetricPill({
    required this.icon,
    required this.title,
    required this.score,
    required this.isDark,
  });

  final IconData icon;
  final String title;
  final int score;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = healthColor(context, score);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.navyElevated.withValues(alpha: 0.6)
            : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: 10.5,
                    color: isDark
                        ? AppColors.textOnDarkTertiary
                        : AppColors.textOnLightSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '$score/100',
              style: theme.textTheme.labelMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Monthly Cash Flow Snapshot Card ────────────────────────────────────────
class _MonthlyCashFlowCard extends StatelessWidget {
  const _MonthlyCashFlowCard({
    required this.monthIncome,
    required this.monthExpenses,
    required this.netMonthlyCashFlow,
    required this.now,
    required this.isDark,
  });

  final double monthIncome;
  final double monthExpenses;
  final double netMonthlyCashFlow;
  final DateTime now;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSurplus = netMonthlyCashFlow >= 0;
    final flowColor = isSurplus
        ? (isDark ? AppColors.mint : const Color(0xFF047857))
        : (isDark ? AppColors.danger : const Color(0xFFDC2626));

    final retentionRate = monthIncome > 0
        ? ((netMonthlyCashFlow / monthIncome) * 100).clamp(-100, 100).round()
        : 0;

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: (isDark ? AppColors.teal : const Color(0xFF0D9488))
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.compare_arrows_rounded,
                  size: 18,
                  color: isDark ? AppColors.teal : const Color(0xFF0D9488),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Monthly Cash Flow',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      DateFormat('MMMM yyyy').format(now),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: isDark
                            ? AppColors.textOnDarkTertiary
                            : AppColors.textOnLightSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                decoration: BoxDecoration(
                  color: flowColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isSurplus
                      ? '+$retentionRate% Saved'
                      : '$retentionRate% Deficit',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: flowColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 10.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Hero Net Position Figure
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '${isSurplus ? '+' : '-'}${CurrencyFormat.pkr(netMonthlyCashFlow.abs())}',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: flowColor,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isSurplus ? 'Net Monthly Surplus' : 'Net Monthly Deficit',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: isDark
                        ? AppColors.textOnDarkSecondary
                        : AppColors.textOnLightSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Inflow vs Outflow Row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.navyElevated.withValues(alpha: 0.5)
                  : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? AppColors.borderDark : AppColors.borderLight,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: (isDark
                                  ? AppColors.teal
                                  : const Color(0xFF0D9488))
                              .withValues(alpha: 0.14),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.south_west_rounded,
                          size: 13,
                          color:
                              isDark ? AppColors.teal : const Color(0xFF0D9488),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Inflow',
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontSize: 10.5,
                                color: isDark
                                    ? AppColors.textOnDarkTertiary
                                    : AppColors.textOnLightSecondary,
                              ),
                            ),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                CurrencyFormat.pkr(monthIncome),
                                style: theme.textTheme.labelMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: isDark
                                      ? AppColors.teal
                                      : const Color(0xFF0D9488),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  height: 28,
                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: (isDark
                                  ? AppColors.danger
                                  : const Color(0xFFDC2626))
                              .withValues(alpha: 0.14),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.north_east_rounded,
                          size: 13,
                          color: isDark
                              ? AppColors.danger
                              : const Color(0xFFDC2626),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Outflow',
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontSize: 10.5,
                                color: isDark
                                    ? AppColors.textOnDarkTertiary
                                    : AppColors.textOnLightSecondary,
                              ),
                            ),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                CurrencyFormat.pkr(monthExpenses),
                                style: theme.textTheme.labelMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: isDark
                                      ? AppColors.danger
                                      : const Color(0xFFDC2626),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Operational Hub Module Card (Live dynamic statistics) ───────────────────
class _HubModuleCard extends StatelessWidget {
  const _HubModuleCard({
    required this.icon,
    required this.accentColor,
    required this.title,
    required this.metric,
    required this.caption,
    required this.badgeText,
    required this.onTap,
    this.progress,
    this.progressColor,
  });

  final IconData icon;
  final Color accentColor;
  final String title;
  final String metric;
  final String caption;
  final String badgeText;
  final VoidCallback onTap;
  final double? progress;
  final Color? progressColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: accentColor),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  badgeText,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: accentColor,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              metric,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: isDark ? AppColors.textOnDark : AppColors.textOnLight,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            caption,
            style: theme.textTheme.labelSmall?.copyWith(
              color: isDark
                  ? AppColors.textOnDarkTertiary
                  : AppColors.textOnLightSecondary,
              fontSize: 10.5,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (progress != null) ...[
            const SizedBox(height: 8),
            ProgressBar(
              value: progress!,
              color: progressColor ?? accentColor,
              height: 4,
            ),
          ],
        ],
      ),
    );
  }
}

// ── Recent Financial Activity Section ──────────────────────────────────────
class _RecentTransactionsSection extends StatelessWidget {
  const _RecentTransactionsSection({
    required this.transactions,
    required this.onAddTransaction,
    required this.onSelectTransaction,
    required this.onViewAll,
  });

  final List<Transaction> transactions;
  final VoidCallback onAddTransaction;
  final ValueChanged<Transaction> onSelectTransaction;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final sorted = [...transactions]..sort((a, b) => b.date.compareTo(a.date));
    final top3 = sorted.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Recent Activity',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
            ),
            TextButton(
              onPressed: onViewAll,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: const Text('View Ledger'),
            ),
            IconButton(
              onPressed: onAddTransaction,
              tooltip: 'Add Transaction',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.add_circle_outline_rounded, size: 22),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (top3.isEmpty)
          AppCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Icon(
                  Icons.receipt_long_outlined,
                  size: 32,
                  color:
                      theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                ),
                const SizedBox(height: 8),
                Text(
                  'No transactions recorded',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Log your first income or expense to see real-time cash flow.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDark
                        ? AppColors.textOnDarkTertiary
                        : AppColors.textOnLightSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                FilledButton.tonalIcon(
                  onPressed: onAddTransaction,
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('Log Transaction'),
                ),
              ],
            ),
          )
        else
          for (final tx in top3)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _RecentTransactionTile(
                transaction: tx,
                onTap: () => onSelectTransaction(tx),
                isDark: isDark,
              ),
            ),
      ],
    );
  }
}

class _RecentTransactionTile extends StatelessWidget {
  const _RecentTransactionTile({
    required this.transaction,
    required this.onTap,
    required this.isDark,
  });

  final Transaction transaction;
  final VoidCallback onTap;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final isIncome = transaction.type == TransactionType.income;
    final visual = CategoryVisuals.of(transaction.category);

    final amountColor = isIncome
        ? (isDark ? AppColors.mint : const Color(0xFF047857))
        : (isDark ? AppColors.textOnDark : AppColors.textOnLight);

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: visual.color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(visual.icon, size: 18, color: visual.color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${CategoryVisuals.nameOf(l10n, transaction.category)} · ${_dateString(context, transaction.date)}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: isDark
                        ? AppColors.textOnDarkTertiary
                        : AppColors.textOnLightSecondary,
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${isIncome ? '+' : '-'}${CurrencyFormat.pkr(transaction.amount)}',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: amountColor,
            ),
          ),
        ],
      ),
    );
  }

  String _dateString(BuildContext context, DateTime date) {
    final l10n = context.l10n;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    if (date.year == today.year &&
        date.month == today.month &&
        date.day == today.day) {
      return l10n.today;
    }
    if (date.year == yesterday.year &&
        date.month == yesterday.month &&
        date.day == yesterday.day) {
      return l10n.yesterday;
    }
    return '${date.day}/${date.month}';
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
