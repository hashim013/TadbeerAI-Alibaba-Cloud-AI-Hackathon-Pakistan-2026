import 'package:flutter/material.dart';

import '../../../core/utils/l10n_context.dart';
import '../../../core/widgets/app_button.dart';
import '../../../domain/entities/budget.dart';
import '../../../domain/entities/finance_category.dart';
import '../finance_category_visuals.dart';

/// Bottom sheet form to add or edit a category budget (and delete existing).
class BudgetFormSheet extends StatefulWidget {
  const BudgetFormSheet({
    super.key,
    required this.onSubmit,
    required this.takenCategories,
    this.existing,
    this.onDelete,
  });

  final Budget? existing;

  /// Categories that already have a budget (excluding [existing]) — not
  /// offered in the picker, since a category has one budget.
  final Set<String> takenCategories;
  final Future<void> Function(Budget budget) onSubmit;
  final Future<void> Function()? onDelete;

  @override
  State<BudgetFormSheet> createState() => _BudgetFormSheetState();
}

class _BudgetFormSheetState extends State<BudgetFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _limitController;
  late String _category;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _limitController = TextEditingController(
        text:
            existing == null ? '' : _stripTrailingZero(existing.monthlyLimit));
    _category = existing?.category ?? _availableCategories.first.id;
  }

  static String _stripTrailingZero(double value) {
    final text = value.toString();
    return text.endsWith('.0') ? text.substring(0, text.length - 2) : text;
  }

  List<FinanceCategory> get _availableCategories => FinanceCategories.expense
      .where((c) =>
          !widget.takenCategories.contains(c.id) ||
          c.id == widget.existing?.category)
      .toList();

  @override
  void dispose() {
    _limitController.dispose();
    super.dispose();
  }

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
                  ? l10n.addBudgetTitle
                  : l10n.editBudgetTitle,
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: InputDecoration(
                labelText: l10n.fieldCategory,
                prefixIcon: Icon(CategoryVisuals.of(_category).icon, size: 20),
              ),
              items: [
                for (final category in _availableCategories)
                  DropdownMenuItem(
                    value: category.id,
                    child: Text(CategoryVisuals.nameOf(l10n, category.id)),
                  ),
              ],
              onChanged: (value) =>
                  setState(() => _category = value ?? _category),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _limitController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: l10n.fieldMonthlyLimit,
                prefixText: 'Rs ',
              ),
              validator: _validateLimit,
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

  String? _validateLimit(String? value) {
    final l10n = context.l10n;
    final limit = double.tryParse((value ?? '').replaceAll(',', '.'));
    if (limit == null || limit <= 0) return l10n.validationLimitInvalid;
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final limit = double.parse(_limitController.text.replaceAll(',', '.'));
    final budget = Budget(
      id: widget.existing?.id ?? 'budget-$_category',
      category: _category,
      monthlyLimit: limit,
    );

    await widget.onSubmit(budget);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _confirmDelete() async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.deleteBudgetTitle),
        content: Text(l10n.deleteBudgetBody),
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
