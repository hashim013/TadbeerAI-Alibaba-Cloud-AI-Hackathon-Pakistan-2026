import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_format.dart';
import '../../../core/utils/l10n_context.dart';
import '../../../core/widgets/app_card.dart';
import '../../../domain/entities/finance_data.dart';
import '../../../domain/entities/goal.dart';
import '../../../domain/services/finance_calculations.dart';
import '../../../providers/finance_providers.dart';
import 'finance_category_visuals.dart';
import 'widgets/finance_widgets.dart';
import 'widgets/goal_form_sheet.dart';

/// Savings goals: progress cards with full CRUD and add-funds.
class GoalsScreen extends ConsumerWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(financeControllerProvider);
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.navGoalsTitle)),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openGoalForm(context, ref),
        child: const Icon(Icons.add_rounded),
      ),
      body: asyncData.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(l10n.errorTitle)),
        data: (data) => _GoalsContent(
          data: data,
          onEdit: (goal) => _openGoalForm(context, ref, existing: goal),
        ),
      ),
    );
  }

  Future<void> _openGoalForm(BuildContext context, WidgetRef ref,
      {Goal? existing}) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: GoalFormSheet(
          existing: existing,
          onSubmit: (goal) async {
            final controller = ref.read(financeControllerProvider.notifier);
            if (existing == null) {
              await controller.addGoal(goal);
            } else {
              await controller.updateGoal(goal);
            }
          },
          onDelete: existing == null
              ? null
              : () async {
                  await ref
                      .read(financeControllerProvider.notifier)
                      .deleteGoal(existing.id);
                },
        ),
      ),
    );
  }
}

class _GoalsContent extends StatelessWidget {
  const _GoalsContent({required this.data, required this.onEdit});

  final FinanceData data;
  final void Function(Goal goal) onEdit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    if (data.goals.isEmpty) {
      return FinanceEmptyState(
        icon: Icons.flag_rounded,
        title: l10n.noGoalsTitle,
        body: l10n.noGoalsBody,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
      itemCount: data.goals.length,
      itemBuilder: (context, index) {
        final goal = data.goals[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _GoalCard(goal: goal, onTap: () => onEdit(goal)),
        );
      },
    );
  }
}

class _GoalCard extends ConsumerWidget {
  const _GoalCard({required this.goal, required this.onTap});

  final Goal goal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final status = FinanceCalculations.goalStatus(goal, DateTime.now());
    final icon = CategoryVisuals.goalIcon(goal.icon);
    final progressColor = status.isComplete ? AppColors.mint : AppColors.teal;

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: progressColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, size: 21, color: progressColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      goal.title,
                      style: theme.textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      status.isComplete
                          ? l10n.goalReached
                          : DateFormat('MMM yyyy').format(goal.targetDate),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: status.isComplete
                            ? AppColors.mint
                            : scheme.onSurfaceVariant,
                        fontWeight: status.isComplete ? FontWeight.w600 : null,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${(status.progress * 100).round()}%',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: progressColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ProgressBar(value: status.progress, color: progressColor, height: 10),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${CurrencyFormat.pkr(goal.savedAmount)} / ${CurrencyFormat.pkr(goal.targetAmount)}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              if (!status.isComplete)
                Flexible(
                  child: Text(
                    status.monthsLeft > 0
                        ? l10n.requiredMonthlyLabel(
                            CurrencyFormat.pkr(status.requiredMonthly))
                        : l10n.goalReached,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
