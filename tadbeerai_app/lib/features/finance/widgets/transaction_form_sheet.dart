import 'package:flutter/material.dart';

import '../../../core/utils/l10n_context.dart';
import '../../../core/widgets/app_button.dart';
import '../../../domain/entities/finance_category.dart';
import '../../../domain/entities/transaction.dart';
import '../finance_category_visuals.dart';

/// Bottom sheet form to add or edit a transaction (and delete existing).
class TransactionFormSheet extends StatefulWidget {
  const TransactionFormSheet({
    super.key,
    required this.onSubmit,
    this.existing,
    this.onDelete,
  });

  final Transaction? existing;
  final Future<void> Function(Transaction transaction) onSubmit;
  final Future<void> Function()? onDelete;

  @override
  State<TransactionFormSheet> createState() => _TransactionFormSheetState();
}

class _TransactionFormSheetState extends State<TransactionFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;
  late TransactionType _type;
  late String _category;
  late DateTime _date;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _titleController = TextEditingController(text: existing?.title ?? '');
    _amountController = TextEditingController(
        text: existing == null ? '' : _stripTrailingZero(existing.amount));
    _noteController = TextEditingController(text: existing?.note ?? '');
    _type = existing?.type ?? TransactionType.expense;
    _category = existing?.category ?? FinanceCategories.expense.first.id;
    _date = existing?.date ?? DateTime.now();
  }

  static String _stripTrailingZero(double value) {
    final text = value.toString();
    return text.endsWith('.0') ? text.substring(0, text.length - 2) : text;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  List<FinanceCategory> get _categories => _type == TransactionType.income
      ? FinanceCategories.income
      : FinanceCategories.expense;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Grab handle.
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color:
                      theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.existing == null
                  ? l10n.addTransactionTitle
                  : l10n.editTransactionTitle,
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),

            // Income / expense toggle.
            SegmentedButton<TransactionType>(
              segments: [
                ButtonSegment(
                  value: TransactionType.expense,
                  label: Text(l10n.filterExpense),
                  icon: const Icon(Icons.north_east_rounded, size: 16),
                ),
                ButtonSegment(
                  value: TransactionType.income,
                  label: Text(l10n.filterIncome),
                  icon: const Icon(Icons.south_west_rounded, size: 16),
                ),
              ],
              selected: {_type},
              onSelectionChanged: (selection) => setState(() {
                _type = selection.first;
                if (!_categories.any((c) => c.id == _category)) {
                  _category = _categories.first.id;
                }
              }),
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _titleController,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: l10n.fieldTitle),
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? l10n.validationTitleRequired
                  : null,
            ),
            const SizedBox(height: 14),

            TextFormField(
              controller: _amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: l10n.fieldAmount,
                prefixText: 'Rs ',
              ),
              validator: _validateAmount,
            ),
            const SizedBox(height: 14),

            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: InputDecoration(
                labelText: l10n.fieldCategory,
                prefixIcon: Icon(CategoryVisuals.of(_category).icon, size: 20),
              ),
              items: [
                for (final category in _categories)
                  DropdownMenuItem(
                    value: category.id,
                    child: Text(CategoryVisuals.nameOf(l10n, category.id)),
                  ),
              ],
              onChanged: (value) =>
                  setState(() => _category = value ?? _category),
            ),
            const SizedBox(height: 14),

            // Date picker row.
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(14),
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: l10n.fieldDate,
                  prefixIcon:
                      const Icon(Icons.calendar_today_rounded, size: 20),
                ),
                child: Text(_formatDate(_date)),
              ),
            ),
            const SizedBox(height: 14),

            TextFormField(
              controller: _noteController,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: l10n.fieldNote),
            ),
            const SizedBox(height: 22),

            AppButton(
              label: widget.existing == null ? l10n.actionAdd : l10n.actionSave,
              loading: _saving,
              onPressed: _submit,
            ),
            if (widget.onDelete != null) ...[
              const SizedBox(height: 10),
              TextButton(
                onPressed: _confirmDelete,
                child: Text(
                  l10n.actionDelete,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String? _validateAmount(String? value) {
    final l10n = context.l10n;
    final amount = double.tryParse((value ?? '').replaceAll(',', '.'));
    if (amount == null || amount <= 0) return l10n.validationAmountInvalid;
    return null;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  String _formatDate(DateTime date) => '${date.day}/${date.month}/${date.year}';

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final amount = double.parse(_amountController.text.replaceAll(',', '.'));
    final existing = widget.existing;
    final transaction = (existing ??
            Transaction(
              id: 'tx-${DateTime.now().millisecondsSinceEpoch}',
              title: '',
              amount: 0,
              type: TransactionType.expense,
              category: _category,
              date: _date,
            ))
        .copyWith(
      title: _titleController.text.trim(),
      amount: amount,
      type: _type,
      category: _category,
      date: _date,
      note: _noteController.text.trim().isEmpty
          ? null
          : _noteController.text.trim(),
    );

    await widget.onSubmit(transaction);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _confirmDelete() async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.deleteTransactionTitle),
        content: Text(l10n.deleteTransactionBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.actionDelete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _saving = true);
    await widget.onDelete?.call();
    if (mounted) Navigator.of(context).pop();
  }
}
