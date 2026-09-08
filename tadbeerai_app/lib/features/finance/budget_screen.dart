import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_format.dart';
import '../../../core/utils/l10n_context.dart';
import '../../../core/widgets/app_canvas.dart';
import '../../../core/widgets/app_card.dart';
import '../../../domain/entities/budget.dart';
import '../../../domain/entities/finance_data.dart';
import '../../../domain/entities/financial_profile.dart';
import '../../../domain/services/finance_calculations.dart';
import '../../../domain/services/financial_health_calculator.dart';
import '../../../providers/finance_providers.dart';
import '../../../providers/profile_providers.dart';
import 'finance_category_visuals.dart';
import 'widgets/budget_form_sheet.dart';
import 'widgets/finance_widgets.dart';

/// Monthly budget planner: totals, per-category progress and CRUD.
class BudgetScreen extends ConsumerWidget {
  const BudgetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(financeControllerProvider);
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.navyBg : Colors.transparent,
      appBar: AppBar(title: Text(l10n.navBudgetTitle)),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openBudgetForm(context, ref),
        child: const Icon(Icons.add_rounded),
      ),
      body: AppCanvas(
        child: asyncData.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text(l10n.errorTitle)),
          data: (data) => _BudgetContent(
            data: data,
            onEdit: (budget) => _openBudgetForm(context, ref, existing: budget),
          ),
        ),
      ),
    );
  }

  Future<void> _openBudgetForm(BuildContext context, WidgetRef ref,
      {Budget? existing}) async {
    final asyncData = ref.read(financeControllerProvider);
    final data = asyncData.value;
    if (data == null || !context.mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: BudgetFormSheet(
          existing: existing,
          takenCategories: data.budgets
              .where((b) => b.id != existing?.id)
              .map((b) => b.category)
              .toSet(),
          onSubmit: (budget) async {
            await ref
                .read(financeControllerProvider.notifier)
                .upsertBudget(budget);
          },
          onDelete: existing == null
              ? null
              : () async {
                  await ref
                      .read(financeControllerProvider.notifier)
                      .deleteBudget(existing.id);
                },
        ),
      ),
    );
  }
}

class _BudgetContent extends ConsumerWidget {
  const _BudgetContent({required this.data, required this.onEdit});

  final FinanceData data;
  final void Function(Budget budget) onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final now = DateTime.now();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final health = ref.watch(financialHealthProvider);
    final profile = ref.watch(financialProfileControllerProvider).valueOrNull;

    final budgetComp = health?.budgetComponent;

    final spentByCategory =
        FinanceCalculations.spentByCategory(data.transactions, now);

    if (data.budgets.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
        children: [
          _BudgetDisciplinePillarCard(
            budgetComp: budgetComp,
            profile: profile,
            isDark: isDark,
          ),
          const SizedBox(height: 24),
          FinanceEmptyState(
            icon: Icons.data_usage_rounded,
            title: l10n.noBudgetsTitle,
            body: l10n.noBudgetsBody,
          ),
        ],
      );
    }

    final totalLimit =
        data.budgets.fold<double>(0, (sum, b) => sum + b.monthlyLimit);
    final budgetedSpent = data.budgets.fold<double>(
      0,
      (sum, b) => sum + (spentByCategory[b.category] ?? 0),
    );
    final remaining = totalLimit - budgetedSpent;
    final utilization = totalLimit > 0 ? budgetedSpent / totalLimit : 0.0;
    final onTrack = data.budgets
        .where((b) => (spentByCategory[b.category] ?? 0) <= b.monthlyLimit)
        .length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
      children: [
        // ── Budget Discipline & Resilience Pillar ─────────────────────────
        _BudgetDisciplinePillarCard(
          budgetComp: budgetComp,
          profile: profile,
          isDark: isDark,
        ),
        const SizedBox(height: 16),

        // ── Monthly overview ─────────────────────────────────────────────
        AppCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.monthlyBudgetTitle,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  Text(
                    l10n.budgetOnTrackDesc(
                        '$onTrack', '${data.budgets.length}'),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: onTrack == data.budgets.length
                              ? AppColors.mint
                              : AppColors.warning,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                '${CurrencyFormat.pkr(budgetedSpent)} / ${CurrencyFormat.pkr(totalLimit)}',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: budgetUtilizationColor(context, utilization),
                    ),
              ),
              const SizedBox(height: 12),
              ProgressBar(
                value: utilization,
                color: budgetUtilizationColor(context, utilization),
                height: 10,
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${l10n.spentLabel}: ${CurrencyFormat.pkr(budgetedSpent)}',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  Text(
                    '${l10n.remainingLabel}: ${CurrencyFormat.pkr(remaining)}',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // ── Category budgets ────────────────────────────────────────────
        for (final budget in data.budgets)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _BudgetRow(
              budget: budget,
              spent: spentByCategory[budget.category] ?? 0,
              onTap: () => onEdit(budget),
            ),
          ),
      ],
    );
  }
}

class _BudgetRow extends StatelessWidget {
  const _BudgetRow({
    required this.budget,
    required this.spent,
    required this.onTap,
  });

  final Budget budget;
  final double spent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final scheme = theme.colorScheme;
    final status = FinanceCalculations.budgetStatus(budget, spent);
    final color = budgetUtilizationColor(context, status.utilization);
    final visual = CategoryVisuals.of(budget.category);

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: visual.color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(visual.icon, size: 19, color: visual.color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      CategoryVisuals.nameOf(l10n, budget.category),
                      style: theme.textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      status.isOver
                          ? l10n.overByLabel(
                              CurrencyFormat.pkr(-status.remaining))
                          : '${l10n.remainingLabel}: ${CurrencyFormat.pkr(status.remaining)}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: status.isOver
                            ? (isDark
                                ? AppColors.danger
                                : const Color(0xFFDC2626))
                            : color,
                        fontWeight: status.isOver ? FontWeight.w600 : null,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    CurrencyFormat.pkr(spent),
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    l10n.spentLabel,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          ProgressBar(value: status.utilization, color: color),
          const SizedBox(height: 8),
          Text(
            l10n.budgetUsedOf(
              CurrencyFormat.pkr(spent),
              CurrencyFormat.pkr(budget.monthlyLimit),
            ),
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _BudgetDisciplinePillarCard extends StatelessWidget {
  const _BudgetDisciplinePillarCard({
    required this.budgetComp,
    required this.profile,
    required this.isDark,
  });

  final HealthComponent? budgetComp;
  final FinancialProfile? profile;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final score = budgetComp?.score ?? 0;
    final onTrack = budgetComp?.detailParams['onTrack'] ?? '0';
    final total = budgetComp?.detailParams['total'] ?? '0';
    final baseline = profile?.monthlyEssentialExpenses;

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFF0EA5E9).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.shield_rounded,
                  size: 20,
                  color: Color(0xFF0EA5E9),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Budget Discipline Pillar',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$onTrack of $total categories within target limits',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$score/100',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: const Color(0xFF0EA5E9),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0EA5E9).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      '25% Weight',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: const Color(0xFF0EA5E9),
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (baseline != null && baseline > 0) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.navyElevated.withValues(alpha: 0.5)
                    : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                  width: 0.8,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 14,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Profile Essential Expenses Baseline: ${CurrencyFormat.pkr(baseline)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 11,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              TextButton(
                onPressed: () => context.push('/profile/financial'),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                ),
                child: const Text('Update Profile Baseline',
                    style: TextStyle(fontSize: 12)),
              ),
              InkWell(
                onTap: () => context.push('/finance/health'),
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'View Health Impact',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color:
                              isDark ? AppColors.teal : const Color(0xFF0D9488),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 14,
                        color:
                            isDark ? AppColors.teal : const Color(0xFF0D9488),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
