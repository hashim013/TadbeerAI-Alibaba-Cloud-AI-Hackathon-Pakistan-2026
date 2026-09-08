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
import '../../../domain/entities/goal.dart';
import '../../../domain/services/finance_calculations.dart';
import '../../../domain/services/financial_health_calculator.dart';
import '../../../providers/finance_providers.dart';
import '../../../providers/profile_providers.dart';
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.navyBg : Colors.transparent,
      appBar: AppBar(title: Text(l10n.navGoalsTitle)),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openGoalForm(context, ref),
        child: const Icon(Icons.add_rounded),
      ),
      body: AppCanvas(
        child: asyncData.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text(l10n.errorTitle)),
          data: (data) => _GoalsContent(
            data: data,
            onEdit: (goal) => _openGoalForm(context, ref, existing: goal),
          ),
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

class _GoalsContent extends ConsumerWidget {
  const _GoalsContent({required this.data, required this.onEdit});

  final FinanceData data;
  final void Function(Goal goal) onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final health = ref.watch(financialHealthProvider);
    final profile = ref.watch(financialProfileControllerProvider).valueOrNull;

    final goalsComp = health?.goalsComponent;

    if (data.goals.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
        children: [
          _GoalProgressPillarCard(
            goalsComp: goalsComp,
            profile: profile,
            isDark: isDark,
          ),
          const SizedBox(height: 24),
          FinanceEmptyState(
            icon: Icons.flag_rounded,
            title: l10n.noGoalsTitle,
            body: l10n.noGoalsBody,
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
      children: [
        _GoalProgressPillarCard(
          goalsComp: goalsComp,
          profile: profile,
          isDark: isDark,
        ),
        const SizedBox(height: 16),
        for (final goal in data.goals)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _GoalCard(
              goal: goal,
              onTap: () => onEdit(goal),
              primaryGoal: profile?.primaryGoal,
            ),
          ),
      ],
    );
  }
}

class _GoalCard extends ConsumerWidget {
  const _GoalCard({
    required this.goal,
    required this.onTap,
    this.primaryGoal,
  });

  final Goal goal;
  final VoidCallback onTap;
  final PrimaryGoal? primaryGoal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final scheme = theme.colorScheme;
    final status = FinanceCalculations.goalStatus(goal, DateTime.now());
    final icon = CategoryVisuals.goalIcon(goal.icon);
    final progressColor = status.isComplete
        ? (isDark ? AppColors.mint : const Color(0xFF047857))
        : (isDark ? AppColors.teal : const Color(0xFF0D9488));
    final isPersonaGoal = _matchesPrimaryGoal(goal, primaryGoal);

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
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            goal.title,
                            style: theme.textTheme.titleSmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isPersonaGoal) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF8B5CF6)
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '⭐ Persona Goal',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: const Color(0xFF8B5CF6),
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      status.isComplete
                          ? l10n.goalReached
                          : DateFormat('MMM yyyy').format(goal.targetDate),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: status.isComplete
                            ? (isDark
                                ? AppColors.mint
                                : const Color(0xFF047857))
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

class _GoalProgressPillarCard extends StatelessWidget {
  const _GoalProgressPillarCard({
    required this.goalsComp,
    required this.profile,
    required this.isDark,
  });

  final HealthComponent? goalsComp;
  final FinancialProfile? profile;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final score = goalsComp?.score ?? 0;
    final percent = goalsComp?.detailParams['percent'] ?? '0%';
    final primaryGoal = profile?.primaryGoal;
    final primaryGoalTitle = switch (primaryGoal) {
      PrimaryGoal.emergencyFund => 'Emergency Fund',
      PrimaryGoal.saveMore => 'Savings Target',
      PrimaryGoal.education => 'Education Fund',
      PrimaryGoal.newDevice => 'Device Purchase',
      PrimaryGoal.businessGrowth => 'Business Expansion',
      PrimaryGoal.reduceSpending => 'Expense Reduction',
      PrimaryGoal.other => 'Personal Goal',
      null => null,
    };

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
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.flag_rounded,
                  size: 20,
                  color: Color(0xFF8B5CF6),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Goal Progress Pillar',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$percent average milestone completion',
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
                      color: const Color(0xFF8B5CF6),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 1.5),
                    decoration: BoxDecoration(
                      color:
                          const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      '15% Weight',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: const Color(0xFF8B5CF6),
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (primaryGoalTitle != null) ...[
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
                  const Icon(
                    Icons.star_rounded,
                    size: 15,
                    color: Color(0xFF8B5CF6),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Persona Primary Focus: $primaryGoalTitle',
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
                child: const Text('Edit Persona Goal',
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

bool _matchesPrimaryGoal(Goal goal, PrimaryGoal? primaryGoal) {
  if (primaryGoal == null) return false;
  final title = goal.title.toLowerCase();
  return switch (primaryGoal) {
    PrimaryGoal.emergencyFund =>
      title.contains('emergency') || title.contains('fund'),
    PrimaryGoal.saveMore => title.contains('save') ||
        title.contains('saving') ||
        title.contains('target'),
    PrimaryGoal.education => title.contains('education') ||
        title.contains('school') ||
        title.contains('college') ||
        title.contains('course'),
    PrimaryGoal.newDevice => title.contains('device') ||
        title.contains('laptop') ||
        title.contains('phone'),
    PrimaryGoal.businessGrowth => title.contains('business') ||
        title.contains('expansion') ||
        title.contains('shop') ||
        title.contains('inventory'),
    PrimaryGoal.reduceSpending => title.contains('reduce') ||
        title.contains('debt') ||
        title.contains('spend'),
    PrimaryGoal.other => false,
  };
}
