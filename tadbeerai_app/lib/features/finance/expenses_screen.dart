import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_format.dart';
import '../../../core/utils/l10n_context.dart';
import '../../../core/widgets/app_card.dart';
import '../../../domain/entities/finance_data.dart';
import '../../../domain/entities/transaction.dart';
import '../../../providers/finance_providers.dart';
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
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.navExpensesTitle)),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openTransactionForm(context),
        child: const Icon(Icons.add_rounded),
      ),
      body: asyncData.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(l10n.errorTitle)),
        data: (data) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: _SearchAndFilters(
                controller: _searchController,
                onChanged: (value) => setState(() => _query = value),
                filter: _filter,
                onFilterSelected: (filter) => setState(() => _filter = filter),
              ),
            ),
            Expanded(
              child: _buildBody(context, data),
            ),
          ],
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
                color: isIncome ? AppColors.mint : scheme.onSurface,
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
