import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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

/// The expenses experience: searchable list, filters and full CRUD.
class ExpensesScreen extends ConsumerStatefulWidget {
  const ExpensesScreen({super.key});

  @override
  ConsumerState<ExpensesScreen> createState() => _ExpensesScreenState();
}

enum _TransactionFilter { all, income, expense }

class _ExpensesScreenState extends ConsumerState<ExpensesScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  _TransactionFilter _filter = _TransactionFilter.all;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asyncData = ref.watch(financeControllerProvider);
    final profile = ref.watch(financialProfileControllerProvider).valueOrNull;
    final health = ref.watch(financialHealthProvider);
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.navyBg : Colors.transparent,
      appBar: AppBar(title: Text(l10n.navExpensesTitle)),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openTransactionForm(context),
        child: const Icon(Icons.add_rounded),
      ),
      body: AppCanvas(
        child: asyncData.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text(l10n.errorTitle)),
          data: (data) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                child: _SpendingPaceBanner(
                  data: data,
                  profile: profile,
                  health: health,
                  isDark: isDark,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
                child: _SearchAndFilters(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _query = value),
                  filter: _filter,
                  onFilterSelected: (filter) =>
                      setState(() => _filter = filter),
                ),
              ),
              Expanded(
                child: _buildBody(context, data),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, FinanceData data) {
    final l10n = context.l10n;
    if (data.transactions.isEmpty) {
      return FinanceEmptyState(
        icon: Icons.receipt_long_rounded,
        title: l10n.noTransactionsTitle,
        body: l10n.noTransactionsBody,
      );
    }

    final filtered = _applyFilters(data.transactions);
    if (filtered.isEmpty) {
      return FinanceEmptyState(
        icon: Icons.search_off_rounded,
        title: l10n.noResultsTitle,
        body: l10n.noResultsBody,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
      itemCount: filtered.length,
      itemBuilder: (context, index) => _TransactionListTile(
        transaction: filtered[index],
        onTap: () => _openTransactionForm(context, existing: filtered[index]),
      ),
    );
  }

  /// Newest first, then type + text filters. Pure presentation logic.
  List<Transaction> _applyFilters(List<Transaction> transactions) {
    final query = _query.trim().toLowerCase();
    final sorted = [...transactions]..sort((a, b) => b.date.compareTo(a.date));

    return sorted.where((t) {
      if (_filter == _TransactionFilter.income &&
          t.type != TransactionType.income) {
        return false;
      }
      if (_filter == _TransactionFilter.expense &&
          t.type != TransactionType.expense) {
        return false;
      }
      if (query.isEmpty) return true;
      return t.title.toLowerCase().contains(query);
    }).toList();
  }

  Future<void> _openTransactionForm(
    BuildContext context, {
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

class _SearchAndFilters extends StatelessWidget {
  const _SearchAndFilters({
    required this.controller,
    required this.onChanged,
    required this.filter,
    required this.onFilterSelected,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final _TransactionFilter filter;
  final ValueChanged<_TransactionFilter> onFilterSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: l10n.searchTransactions,
            prefixIcon: const Icon(Icons.search_rounded, size: 20),
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: theme.colorScheme.outline,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: theme.colorScheme.outline,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SegmentedButton<_TransactionFilter>(
          segments: [
            ButtonSegment(
              value: _TransactionFilter.all,
              label: Text(l10n.filterAll),
            ),
            ButtonSegment(
              value: _TransactionFilter.income,
              label: Text(l10n.filterIncome),
            ),
            ButtonSegment(
              value: _TransactionFilter.expense,
              label: Text(l10n.filterExpense),
            ),
          ],
          selected: {filter},
          onSelectionChanged: (selection) => onFilterSelected(selection.first),
          showSelectedIcon: false,
        ),
      ],
    );
  }
}

class _TransactionListTile extends StatelessWidget {
  const _TransactionListTile({required this.transaction, required this.onTap});

  final Transaction transaction;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final scheme = theme.colorScheme;
    final isIncome = transaction.type == TransactionType.income;
    final visual = CategoryVisuals.of(transaction.category);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: visual.color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(visual.icon, size: 20, color: visual.color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transaction.title,
                    style: theme.textTheme.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${CategoryVisuals.nameOf(l10n, transaction.category)} · '
                    '${_dateLabel(context, transaction.date)}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
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
                color: isIncome
                    ? (isDark ? AppColors.mint : const Color(0xFF047857))
                    : scheme.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _dateLabel(BuildContext context, DateTime date) {
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
    return '${date.day}/${date.month}/${date.year}';
  }
}

class _SpendingPaceBanner extends StatelessWidget {
  const _SpendingPaceBanner({
    required this.data,
    required this.profile,
    required this.health,
    required this.isDark,
  });

  final FinanceData data;
  final FinancialProfile? profile;
  final FinancialHealthResult? health;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final monthExpenses =
        FinanceCalculations.monthlyExpenses(data.transactions, now);
    final baseline = profile?.monthlyEssentialExpenses ?? 0.0;
    final spendingComp = health?.spendingComponent;

    final ratio =
        baseline > 0 ? (monthExpenses / baseline).clamp(0.0, 2.0) : 0.0;
    final isPaceHigh = ratio > 1.0;
    final paceColor = isPaceHigh
        ? (isDark ? AppColors.danger : const Color(0xFFDC2626))
        : (ratio > 0.8
            ? const Color(0xFFF59E0B)
            : (isDark ? AppColors.mint : const Color(0xFF047857)));

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: paceColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(
                  Icons.speed_rounded,
                  size: 18,
                  color: paceColor,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Spending Pace & Discipline',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: paceColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            spendingComp != null
                                ? '${spendingComp.score}/100 Pillar'
                                : '15% Weight',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: paceColor,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      baseline > 0
                          ? '${CurrencyFormat.pkr(monthExpenses)} spent of ${CurrencyFormat.pkr(baseline)} monthly baseline'
                          : '${CurrencyFormat.pkr(monthExpenses)} recorded this month',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 11.5,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
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
                        'Health',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color:
                              isDark ? AppColors.teal : const Color(0xFF0D9488),
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 16,
                        color:
                            isDark ? AppColors.teal : const Color(0xFF0D9488),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (baseline > 0) ...[
            const SizedBox(height: 8),
            ProgressBar(
                value: ratio.clamp(0.0, 1.0), color: paceColor, height: 6),
          ],
        ],
      ),
    );
  }
}
