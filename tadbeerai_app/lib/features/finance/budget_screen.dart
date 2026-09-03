import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_format.dart';
import '../../../core/utils/l10n_context.dart';
import '../../../core/widgets/app_card.dart';
import '../../../domain/entities/budget.dart';
import '../../../domain/entities/finance_data.dart';
import '../../../domain/services/finance_calculations.dart';
import '../../../providers/finance_providers.dart';
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

    return Scaffold(
      appBar: AppBar(title: Text(l10n.navBudgetTitle)),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openBudgetForm(context, ref),
        child: const Icon(Icons.add_rounded),
      ),
      body: asyncData.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(l10n.errorTitle)),
        data: (data) => _BudgetContent(
          data: data,
          onEdit: (budget) => _openBudgetForm(context, ref, existing: budget),
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

class _BudgetContent extends StatelessWidget {
  const _BudgetContent({required this.data, required this.onEdit});

  final FinanceData data;
  final void Function(Budget budget) onEdit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final now = DateTime.now();
    final spentByCategory =
        FinanceCalculations.spentByCategory(data.transactions, now);

    if (data.budgets.isEmpty) {
      return FinanceEmptyState(
        icon: Icons.data_usage_rounded,
        title: l10n.noBudgetsTitle,
        body: l10n.noBudgetsBody,
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
                        color: status.isOver ? AppColors.danger : color,
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
